#!/usr/bin/env bash
set -euo pipefail

# deploy.sh — Deploy claude-code-setup into a project directory
#
# Sets up project-specific files: CLAUDE.md, settings.json, .worktreeinclude,
# memory bank templates, GEMINI.md symlink, and .gitignore entries.
#
# Shared tooling (agents, commands, skills, rules) lives at ~/.claude/
# and is set up by install.sh, not this script.
#
# Usage:
#   ./deploy.sh <project-dir>          # Deploy to existing project
#   ./deploy.sh <project-dir> --init   # Create project dir if needed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BEGIN_MARKER="# BEGIN claude-code-setup (managed by deploy.sh)"
END_MARKER="# END claude-code-setup"

usage() {
    echo "Usage: $(basename "$0") <project-dir> [options]"
    echo
    echo "Deploy Claude Code project templates into a project."
    echo "Shared tooling is installed separately via install.sh."
    echo
    echo "Options:"
    echo "  --init         Create the project directory if it doesn't exist"
    echo "  --cloudflare   Include Cloudflare context files"
    echo "  --convex       Include Convex context files"
    exit 1
}

# --- Parse arguments ---
[[ $# -lt 1 ]] && usage

TARGET_DIR="$1"
shift
INIT=false
INCLUDE_CLOUDFLARE=false
INCLUDE_CONVEX=false
for arg in "$@"; do
    case "$arg" in
        --init) INIT=true ;;
        --cloudflare) INCLUDE_CLOUDFLARE=true ;;
        --convex) INCLUDE_CONVEX=true ;;
        *) echo "Unknown option: $arg"; usage ;;
    esac
done

# --- Resolve target directory ---
if [[ ! -d "$TARGET_DIR" ]]; then
    if $INIT; then
        mkdir -p "$TARGET_DIR"
        echo "Created project directory: $TARGET_DIR"
    else
        echo "Error: $TARGET_DIR does not exist. Use --init to create it."
        exit 1
    fi
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# --- Determine setup repo base path ---
if [[ "${DEVCONTAINER:-}" == "true" ]]; then
    SETUP_BASE="$HOME/.claude-setup"
    echo "Detected devcontainer environment"
else
    SETUP_BASE="$SCRIPT_DIR"
    echo "Detected host environment"
fi

echo "Setup repo: $SETUP_BASE"
echo "Target:     $TARGET_DIR"
echo

# --- Migrate old-style symlinks ---
migrated=0
echo "Checking for old-style symlinks..."
for dir in agents commands skills mcp; do
    link="$TARGET_DIR/.claude/$dir"
    if [[ -L "$link" ]]; then
        rm "$link"
        echo "  Removed old symlink: .claude/$dir"
        migrated=$((migrated + 1))
    fi
done
# Remove AGENTS.md symlink (no longer created)
if [[ -L "$TARGET_DIR/AGENTS.md" ]]; then
    rm "$TARGET_DIR/AGENTS.md"
    echo "  Removed old symlink: AGENTS.md"
    migrated=$((migrated + 1))
fi
if [[ $migrated -gt 0 ]]; then
    echo "  Migrated $migrated old-style symlink(s)"
else
    echo "  None found"
fi
echo

# --- Create .claude directory ---
mkdir -p "$TARGET_DIR/.claude"

# --- Copy template files (only if they don't exist) ---
echo "Copying template files..."

if [[ ! -f "$TARGET_DIR/.claude/settings.json" ]]; then
    cp "$SETUP_BASE/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
    echo "  Copied: .claude/settings.json (template)"
else
    echo "  Skipped: .claude/settings.json (already exists)"
fi

if [[ ! -f "$TARGET_DIR/CLAUDE.md" ]]; then
    cp "$SETUP_BASE/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    echo "  Copied: CLAUDE.md (template)"
else
    echo "  Skipped: CLAUDE.md (already exists)"
fi

if [[ ! -f "$TARGET_DIR/.worktreeinclude" ]]; then
    cp "$SETUP_BASE/.worktreeinclude" "$TARGET_DIR/.worktreeinclude"
    echo "  Copied: .worktreeinclude (template)"
else
    echo "  Skipped: .worktreeinclude (already exists)"
fi
echo

# --- Copy optional context files (only when flags are set) ---
copy_context_file() {
    local file="$1"
    local base
    base="$(basename "$file")"
    if [[ ! -f "$TARGET_DIR/$base" ]]; then
        cp "$file" "$TARGET_DIR/$base"
        echo "  Copied: $base"
    else
        echo "  Skipped: $base (already exists)"
    fi
}

if $INCLUDE_CLOUDFLARE || $INCLUDE_CONVEX; then
    echo "Copying optional context files..."
    if $INCLUDE_CLOUDFLARE; then
        for f in "$SETUP_BASE"/CLAUDE-cloudflare*.md; do
            [[ -f "$f" ]] && copy_context_file "$f"
        done
    fi
    if $INCLUDE_CONVEX; then
        for f in "$SETUP_BASE"/CLAUDE-convex*.md; do
            [[ -f "$f" ]] && copy_context_file "$f"
        done
    fi
    echo
fi

# --- Create GEMINI.md symlink ---
echo "Creating multi-agent symlinks..."
if [[ -L "$TARGET_DIR/GEMINI.md" ]]; then
    echo "  OK: GEMINI.md (already linked)"
elif [[ -e "$TARGET_DIR/GEMINI.md" ]]; then
    echo "  Warning: GEMINI.md exists and is not a symlink — skipping"
else
    ln -s "CLAUDE.md" "$TARGET_DIR/GEMINI.md"
    echo "  Linked: GEMINI.md → CLAUDE.md"
fi
echo

# --- Update .gitignore with section markers ---
echo "Updating .gitignore..."

gitignore="$TARGET_DIR/.gitignore"

# Desired managed entries
MANAGED_ENTRIES="GEMINI.md
CLAUDE-*.md"

# Build the managed block
MANAGED_BLOCK="$BEGIN_MARKER
$MANAGED_ENTRIES
$END_MARKER"

if [[ -f "$gitignore" ]]; then
    # Check if section markers already exist
    if grep -qF "$BEGIN_MARKER" "$gitignore"; then
        # Replace existing managed section
        # Use awk to replace content between markers
        awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v block="$MANAGED_BLOCK" '
            $0 == begin { print block; skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$gitignore" > "$gitignore.tmp"
        mv "$gitignore.tmp" "$gitignore"
        echo "  Updated managed section"
    else
        # Remove any old raw entries that are now managed
        # (entries without section markers from old deploy.sh)
        temp="$gitignore.tmp"
        cp "$gitignore" "$temp"
        for pattern in '.claude/agents' '.claude/commands' '.claude/skills' '.claude/mcp' 'AGENTS.md'; do
            grep -vxF "$pattern" "$temp" > "$temp.2" && mv "$temp.2" "$temp" || true
        done
        mv "$temp" "$gitignore"

        # Append managed section
        echo "" >> "$gitignore"
        echo "$MANAGED_BLOCK" >> "$gitignore"
        echo "  Added managed section"
    fi
else
    echo "$MANAGED_BLOCK" > "$gitignore"
    echo "  Created .gitignore with managed section"
fi
echo

# --- Check if install.sh has been run ---
if [[ ! -d "$HOME/.claude/rules" ]] || [[ -z "$(ls -A "$HOME/.claude/rules" 2>/dev/null)" ]]; then
    echo "⚠ Warning: ~/.claude/rules/ is empty or missing."
    echo "  Run install.sh to set up shared tooling (agents, commands, skills, rules):"
    echo "  $SETUP_BASE/install.sh"
    echo
fi

# --- Summary ---
echo "=== Deploy complete ==="
echo
echo "Templates (project-specific):"
for f in .claude/settings.json CLAUDE.md .worktreeinclude; do
    [[ -f "$TARGET_DIR/$f" ]] && echo "  $f"
done
echo
echo "Symlinks:"
[[ -L "$TARGET_DIR/GEMINI.md" ]] && echo "  GEMINI.md → $(readlink "$TARGET_DIR/GEMINI.md")"
echo
echo "Shared tooling is at ~/.claude/ (managed by install.sh)"

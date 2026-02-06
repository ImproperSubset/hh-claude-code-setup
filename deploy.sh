#!/usr/bin/env bash
set -euo pipefail

# deploy.sh — Deploy claude-code-setup into a project directory
#
# Usage:
#   ./deploy.sh <project-dir>          # Deploy to existing project
#   ./deploy.sh <project-dir> --init   # Create project dir if needed
#
# Environment-aware: detects host vs devcontainer and adjusts symlink
# targets accordingly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $(basename "$0") <project-dir> [--init]"
    echo
    echo "Deploy Claude Code setup (agents, commands, skills, mcp) into a project."
    echo
    echo "Options:"
    echo "  --init    Create the project directory if it doesn't exist"
    exit 1
}

# --- Parse arguments ---
[[ $# -lt 1 ]] && usage

TARGET_DIR="$1"
INIT=false
[[ "${2:-}" == "--init" ]] && INIT=true

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
# In devcontainer: the setup repo is bind-mounted at /home/node/.claude-setup
# On host: use the actual path to this script's repo
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

# --- Helper: create symlink (removes existing if needed) ---
make_link() {
    local target="$1"  # what the symlink points to
    local link="$2"    # the symlink path

    # For relative targets, check existence relative to the link's directory
    local check_path="$target"
    if [[ "$target" != /* ]]; then
        check_path="$(dirname "$link")/$target"
    fi
    if [[ ! -e "$check_path" ]]; then
        echo "  Warning: symlink target $target does not exist, skipping"
        return
    fi
    if [[ -L "$link" ]]; then
        rm "$link"
    elif [[ -e "$link" ]]; then
        echo "  Warning: $link exists and is not a symlink, skipping"
        return
    fi
    ln -s "$target" "$link"
    echo "  Linked: $(basename "$link") → $target"
}

# --- Create .claude directory ---
mkdir -p "$TARGET_DIR/.claude"

# --- Symlink shared directories ---
echo "Symlinking shared directories..."
for dir in agents commands skills mcp; do
    make_link "$SETUP_BASE/.claude/$dir" "$TARGET_DIR/.claude/$dir"
done

# --- Copy template files (only if they don't exist) ---
echo
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

# --- Copy optional platform context files ---
echo
echo "Copying optional memory bank templates..."
for ctx_file in "$SETUP_BASE"/CLAUDE-*.md; do
    [[ -f "$ctx_file" ]] || continue
    base="$(basename "$ctx_file")"
    if [[ ! -f "$TARGET_DIR/$base" ]]; then
        cp "$ctx_file" "$TARGET_DIR/$base"
        echo "  Copied: $base"
    else
        echo "  Skipped: $base (already exists)"
    fi
done

# --- Create intra-project symlinks for multi-agent support ---
echo
echo "Creating multi-agent symlinks..."
make_link "CLAUDE.md" "$TARGET_DIR/GEMINI.md"
make_link "CLAUDE.md" "$TARGET_DIR/AGENTS.md"

# --- Ensure CLAUDE-*.md files are gitignored ---
echo
if [[ -f "$TARGET_DIR/.gitignore" ]]; then
    if ! grep -q "^CLAUDE-\*.md$" "$TARGET_DIR/.gitignore" 2>/dev/null; then
        echo "" >> "$TARGET_DIR/.gitignore"
        echo "# Claude Code memory bank (project-specific, not committed)" >> "$TARGET_DIR/.gitignore"
        echo "CLAUDE-*.md" >> "$TARGET_DIR/.gitignore"
        echo "Added CLAUDE-*.md to .gitignore"
    else
        echo "CLAUDE-*.md already in .gitignore"
    fi
else
    cat > "$TARGET_DIR/.gitignore" <<'GITIGNORE'
# Claude Code memory bank (project-specific, not committed)
CLAUDE-*.md
GITIGNORE
    echo "Created .gitignore with CLAUDE-*.md exclusion"
fi

# --- Summary ---
echo
echo "=== Deploy complete ==="
echo
echo "Symlinked (shared):"
for dir in agents commands skills mcp; do
    if [[ -L "$TARGET_DIR/.claude/$dir" ]]; then
        echo "  .claude/$dir → $(readlink "$TARGET_DIR/.claude/$dir")"
    fi
done
echo
echo "Templates (project-specific):"
for f in .claude/settings.json CLAUDE.md .worktreeinclude; do
    [[ -f "$TARGET_DIR/$f" ]] && echo "  $f"
done
echo
echo "Multi-agent symlinks:"
[[ -L "$TARGET_DIR/GEMINI.md" ]] && echo "  GEMINI.md → $(readlink "$TARGET_DIR/GEMINI.md")"
[[ -L "$TARGET_DIR/AGENTS.md" ]] && echo "  AGENTS.md → $(readlink "$TARGET_DIR/AGENTS.md")"

#!/usr/bin/env bash
set -euo pipefail

# install.sh — One-time setup of shared tooling into ~/.claude/
#
# Symlinks rules, agents, skills, and commands from this setup repo
# into the user-level ~/.claude/ directory, where Claude Code merges
# them with project-level content.
#
# Usage:
#   ./install.sh              # Install symlinks
#   ./install.sh --uninstall  # Remove symlinks created by this script
#
# Safe to re-run (idempotent). Coexists with brain plugin content
# already in ~/.claude/.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Determine setup repo base path ---
if [[ "${DEVCONTAINER:-}" == "true" ]]; then
    SETUP_BASE="$HOME/.claude-setup"
    echo "Detected devcontainer environment"
else
    SETUP_BASE="$SCRIPT_DIR"
    echo "Detected host environment"
fi

CLAUDE_DIR="$HOME/.claude"

# --- Uninstall mode ---
if [[ "${1:-}" == "--uninstall" ]]; then
    echo "Uninstalling setup repo symlinks from $CLAUDE_DIR..."
    echo

    removed=0

    # Remove rule symlinks pointing to our repo
    if [[ -d "$CLAUDE_DIR/rules" ]]; then
        for f in "$CLAUDE_DIR/rules"/*.md; do
            [[ -L "$f" ]] || continue
            target="$(readlink "$f")"
            if [[ "$target" == "$SETUP_BASE/rules/"* ]]; then
                rm "$f"
                echo "  Removed: rules/$(basename "$f")"
                removed=$((removed + 1))
            fi
        done
        # Remove rules/ dir if empty
        rmdir "$CLAUDE_DIR/rules" 2>/dev/null && echo "  Removed: empty rules/ directory" || true
    fi

    # Remove agent symlinks pointing to our repo
    if [[ -d "$CLAUDE_DIR/agents" ]]; then
        for f in "$CLAUDE_DIR/agents"/*.md; do
            [[ -L "$f" ]] || continue
            target="$(readlink "$f")"
            if [[ "$target" == "$SETUP_BASE/.claude/agents/"* ]]; then
                rm "$f"
                echo "  Removed: agents/$(basename "$f")"
                removed=$((removed + 1))
            fi
        done
        rmdir "$CLAUDE_DIR/agents" 2>/dev/null && echo "  Removed: empty agents/ directory" || true
    fi

    # Remove skill symlinks pointing to our repo
    if [[ -d "$CLAUDE_DIR/skills" ]]; then
        for dir in "$CLAUDE_DIR/skills"/*/; do
            [[ -d "$dir" ]] || continue
            skill_file="$dir/SKILL.md"
            [[ -L "$skill_file" ]] || continue
            target="$(readlink "$skill_file")"
            if [[ "$target" == "$SETUP_BASE/.claude/skills/"* ]]; then
                rm "$skill_file"
                rmdir "$dir" 2>/dev/null || true
                echo "  Removed: skills/$(basename "$dir")/SKILL.md"
                removed=$((removed + 1))
            fi
        done
    fi

    # Remove command symlinks pointing to our repo
    if [[ -d "$CLAUDE_DIR/commands" ]]; then
        for entry in "$CLAUDE_DIR/commands"/*/; do
            [[ -L "${entry%/}" ]] || continue
            target="$(readlink "${entry%/}")"
            if [[ "$target" == "$SETUP_BASE/.claude/commands/"* ]]; then
                rm "${entry%/}"
                echo "  Removed: commands/$(basename "$entry")"
                removed=$((removed + 1))
            fi
        done
        # Also check for file symlinks (not just directories)
        for entry in "$CLAUDE_DIR/commands"/*; do
            [[ -L "$entry" ]] || continue
            [[ -d "$entry" ]] && continue  # skip directory symlinks already handled
            target="$(readlink "$entry")"
            if [[ "$target" == "$SETUP_BASE/.claude/commands/"* ]]; then
                rm "$entry"
                echo "  Removed: commands/$(basename "$entry")"
                removed=$((removed + 1))
            fi
        done
    fi

    echo
    echo "Removed $removed symlink(s)."
    exit 0
fi

# --- Install mode ---
echo "Installing shared tooling into $CLAUDE_DIR..."
echo "Source: $SETUP_BASE"
echo

installed=0
skipped=0

# Helper: create symlink, replacing existing symlinks but not real files
make_link() {
    local target="$1"
    local link="$2"

    if [[ ! -e "$target" ]]; then
        echo "  Warning: source does not exist: $target — skipping"
        return
    fi
    if [[ -L "$link" ]]; then
        local existing
        existing="$(readlink "$link")"
        if [[ "$existing" == "$target" ]]; then
            echo "  OK: $(basename "$link") (already linked)"
            skipped=$((skipped + 1))
            return
        fi
        rm "$link"
    elif [[ -e "$link" ]]; then
        echo "  Warning: $(basename "$link") exists and is not a symlink — skipping"
        skipped=$((skipped + 1))
        return
    fi
    ln -s "$target" "$link"
    echo "  Linked: $(basename "$link") → $target"
    installed=$((installed + 1))
}

# --- Rules ---
echo "Rules:"
mkdir -p "$CLAUDE_DIR/rules"
for rule in "$SETUP_BASE/rules"/*.md; do
    [[ -f "$rule" ]] || continue
    make_link "$rule" "$CLAUDE_DIR/rules/$(basename "$rule")"
done
echo

# --- Agents ---
echo "Agents:"
mkdir -p "$CLAUDE_DIR/agents"
for agent in "$SETUP_BASE/.claude/agents"/*.md; do
    [[ -f "$agent" ]] || continue
    make_link "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
done
echo

# --- Skills ---
echo "Skills:"
for skill_dir in "$SETUP_BASE/.claude/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    mkdir -p "$CLAUDE_DIR/skills/$skill_name"
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        make_link "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
    fi
done
echo

# --- Commands ---
echo "Commands:"
mkdir -p "$CLAUDE_DIR/commands"
for cmd_dir in "$SETUP_BASE/.claude/commands"/*/; do
    [[ -d "$cmd_dir" ]] || continue
    cmd_name="$(basename "$cmd_dir")"
    # Symlink the entire subdirectory (each command is its own dir)
    make_link "${cmd_dir%/}" "$CLAUDE_DIR/commands/$cmd_name"
done
# Also symlink top-level command .md files (e.g., code-review.md → /code-review)
for cmd_file in "$SETUP_BASE/.claude/commands"/*.md; do
    [[ -f "$cmd_file" ]] || continue
    make_link "$cmd_file" "$CLAUDE_DIR/commands/$(basename "$cmd_file")"
done
echo

# --- Summary ---
echo "=== Install complete ==="
echo "  $installed new symlink(s) created"
echo "  $skipped already present or skipped"
echo
echo "Contents of $CLAUDE_DIR/:"
echo "  rules/    — $(ls "$CLAUDE_DIR/rules"/*.md 2>/dev/null | wc -l) rule files"
echo "  agents/   — $(ls "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l) agent files"
echo "  skills/   — $(ls -d "$CLAUDE_DIR/skills"/*/ 2>/dev/null | wc -l) skill directories"
echo "  commands/ — $(ls -d "$CLAUDE_DIR/commands"/*/ 2>/dev/null | wc -l) command directories + $(ls "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l) command files"

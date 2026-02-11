# Project Memory Bank

Each project uses `CLAUDE-*.md` files for project-specific knowledge. This is where all implementation details, architecture decisions, and current state live.

## Core Context Files

* **CLAUDE-activeContext.md** - Current state: what's being worked on, current branch, immediate next steps
* **CLAUDE-patterns.md** - Established code patterns and conventions for this project
* **CLAUDE-decisions.md** - Architecture decisions and rationale specific to this project
* **CLAUDE-troubleshooting.md** - Known issues and proven solutions for this codebase
* **CLAUDE-config-variables.md** - Configuration variables reference (if exists)
* **CLAUDE-temp.md** - Temporary scratch pad (only read when referenced)

## When to read memory bank files

- **Starting any work** - Read `CLAUDE-activeContext.md` first to understand current state and maintain session continuity
- **Before implementing features** - Check `CLAUDE-patterns.md` and `CLAUDE-decisions.md` to follow established conventions and understand prior architectural choices
- **When hitting errors** - Check `CLAUDE-troubleshooting.md` for known issues before debugging from scratch
- **Before claiming work is done** - Verify against `CLAUDE-activeContext.md` that the work aligns with stated goals

## Auto Memory (`MEMORY.md`)

The auto memory file at `~/.claude/projects/.../memory/MEMORY.md` auto-loads into the system prompt every session. Use it as a quick-reference cheat sheet for:

- Things Claude gets wrong repeatedly or forgets between sessions
- Key gotchas (e.g., "client must be built before running tests")
- Critical facts that save time when remembered (e.g., "Cognito WebAuthn requires Essentials tier")

Keep it concise - it counts against the system prompt. Link to detailed files rather than duplicating content.

## Relationship to Brain

The brain (`~/.brain/`) holds cross-project knowledge. The project memory bank holds project-specific knowledge. Do not duplicate between them. If something is only relevant to this project, it belongs here. If it's useful across projects, it belongs in the brain.

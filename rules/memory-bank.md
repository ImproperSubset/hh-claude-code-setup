# Project Knowledge Organization

Knowledge lives in three layers, from general to specific. Don't duplicate between layers.

## Layer 1: General Technology Knowledge (cross-project)

**Brain (`~/.brain/`)** — Reference material. DynamoDB patterns, Playwright lessons, AWS gotchas. Useful across any project using those technologies. Search when a problem feels familiar or when setting up tooling.

**Skills** — Actionable guidance triggered by context. "You're writing DynamoDB transactions — here's how." General technology patterns, not project-specific implementation details.

**Rules (`~/.claude-setup/rules/`)** — How Claude should behave in every project. Always loaded.

## Layer 2: Project Entry Point

**`CLAUDE.md`** — The routing table. What this project is, the tech stack, how to deploy, lint rules, and a table pointing Claude to the right design doc for each subsystem. Keep it lean — it's a signpost, not an encyclopedia. Don't put implementation details here that belong in a design doc.

**`MEMORY.md`** (auto-loaded) — Session cheat sheet. Things Claude forgets between sessions, deployed stack info, key gotchas. Under 200 lines. Link to detailed files rather than duplicating content.

## Layer 3: Project Documentation

**Design docs** (`docs/design/`) — Canonical reference for how each subsystem works today. Current state, invariants, constraints, implementation details. 100-300 lines each. Read the relevant one before implementing features in that subsystem. Examples: `data-model.md`, `authentication.md`.

**Rationale docs** (`docs/rationale/`) — The WHY. Motivation, constraints, rejected alternatives. Historical context for why the system was designed this way. Once a design doc absorbs the implementation details, the rationale doc keeps the reasoning but should not contradict the design doc. If the implementation diverged from the original rationale, update the rationale doc to reflect reality.

## Key Principles

- **CLAUDE.md routes, design docs implement.** CLAUDE.md tells Claude where to look. Design docs tell Claude what to do.
- **Skills cover general, design docs cover specific.** "How DynamoDB transactions work" is a skill. "What sort keys this project's Members table uses" is a design doc.
- **Separate why from how.** Design docs = how it works today. Rationale docs = why we chose this approach.
- **Stop aspiring to things you're not doing.** If the implementation diverged from a design doc, update the doc. Aspirational documentation that contradicts shipped code is worse than no documentation.
- **Read entire files before modifying them.** With 1M context, there's no reason to work from grep snippets. Read the whole file, understand the structure, then edit.
- **Read the relevant design doc before implementing features.** This is in CLAUDE.md's routing table.

## Roadmap Practice

Three files in `docs/plans/`, each with one job:

| File | Purpose | When to read |
|---|---|---|
| `project-current.md` | What we're working on right now | Start of every session |
| `project-roadmap.md` | What's next, in priority order | When deciding what to do next |
| `project-completed.md` | What we've shipped (feature, PR, date) | When checking if something was already done |

**Workflow:**
1. Pick from the top of **roadmap** → move to **current**
2. Work on it
3. When done → move to **completed** (with PR number and date)
4. "What's next?" → look at **roadmap**

The roadmap is a priority-ordered accumulation of things to do on the way to production. New items get inserted at roughly the right priority. The user says "put it on the roadmap" to queue future work.

**Plans and auto-memory:** When working on a multi-session effort, keep a memory file (in the auto-memory directory) that points to the current plan and tracks progress. This tells future sessions which plan corresponds to the current work and where it left off.

## What NOT to maintain

- **Monolithic decision files** (e.g., `CLAUDE-decisions.md`) — Decisions belong in design docs (the how) and rationale docs (the why). A separate decisions monolith becomes stale and contradicts the canonical sources. Phase it out as design docs are written.
- **Separate archives** (e.g., `CLAUDE-LONG-TERM-MEMORY.md`) — If design docs are canonical current state and rationale docs are history, there's no role for a separate archive.
- **Duplicated content across layers** — If a fact is in a design doc, don't also put it in CLAUDE.md and MEMORY.md. One canonical location, pointers from everywhere else.

## What may still be useful

- **Code patterns file** (e.g., `CLAUDE-patterns.md`) — Cross-cutting code conventions that don't fit in any single subsystem design doc (handler structure, error response format, component patterns). Review periodically — if content belongs in a design doc, move it there.
- **Troubleshooting file** (e.g., `CLAUDE-troubleshooting.md`) — Ephemeral workarounds and known bugs. Some entries may belong in design docs; others are genuinely temporary.

## Relationship Between Layers

```
Rules (always loaded)        → How to behave, how to organize knowledge
    ↓
CLAUDE.md (always loaded)    → What is this project? Where do I look?
MEMORY.md (always loaded)    → What do I keep forgetting?
    ↓
Design docs (read on demand) → How does this subsystem work?
Rationale docs (read on demand) → Why was it designed this way?
    ↓
Brain + Skills (searched/triggered) → General technology guidance
```

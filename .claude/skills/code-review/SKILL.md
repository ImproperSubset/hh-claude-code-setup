---
name: code-review
description: "Multi-AI code review with triage pipeline. Launches Codex and Code-Searcher reviewers in parallel, then triages findings against actual code."
---

# Multi-AI Code Review Pipeline

This skill orchestrates a multi-AI code review pipeline where three independent reviewers analyze code and a triage agent verifies findings against the actual codebase.

## Architecture

```
/code-review (this skill orchestrates)
  ├── codex-reviewer agent       → writes docs/review/codex-{timestamp}.md
  ├── code-searcher-reviewer     → writes docs/review/code-searcher-{timestamp}.md
  │        (both run in parallel)
  └── review-triage agent        → reads review files, verifies against code + Context7 docs
                                 → writes docs/review/TRIAGE-{timestamp}.md
```

## Anti-Sycophancy Defenses

**You (the governing Claude) are a relay, not a filter.** These rules are non-negotiable:

1. Review agents write findings to files — you never see raw findings in conversation context
2. The triage agent (not you) synthesizes and verifies findings
3. You relay the triage report path and stats VERBATIM
4. **You do NOT editorialize, soften, dismiss, add reassuring commentary, or interpret the findings**
5. You do NOT say things like "the code looks generally good", "most of these are minor", "nothing to worry about", or "the reviewers were quite thorough"
6. If the user wants to see findings, tell them to read the triage file directly

## Orchestration Steps

### Step 1: Determine Review Scope

Assess what needs reviewing based on current context:

- Check `git status` and `git diff --stat HEAD` for uncommitted changes
- Check if on a feature branch with `git log --oneline main..HEAD` (or master..HEAD)
- Consider conversation context — if the user just made changes, those are likely what to review

Set REVIEW_SCOPE to one of:
- `uncommitted` — uncommitted changes exist
- `branch:BRANCH_NAME` — on a feature branch with commits ahead of base
- `commit:SHA` — specific commit to review

If both uncommitted changes and branch commits exist, prefer `uncommitted` (includes everything).

Also capture:
- The diff content (`git diff HEAD` or equivalent)
- The list of changed files (`git diff --name-only HEAD` or equivalent)
- Any relevant invoker context from the conversation (mark as UNVERIFIED)

### Step 2: Prepare Output Directory

```bash
mkdir -p docs/review
```

### Step 3: Launch Both Reviewers in Parallel

Launch both agents simultaneously using the Task tool. **Both in a single message with two tool calls.**

**codex-reviewer agent:**
- subagent_type: `general-purpose` (will use the codex-reviewer agent definition)
- Provide: REVIEW_SCOPE, INVOKER_CONTEXT
- The agent handles Codex CLI execution, JSONL parsing, and file writing

**code-searcher-reviewer agent:**
- subagent_type: `code-searcher` (uses code-searcher capabilities directly)
- Provide: REVIEW_SCOPE, CHANGED_FILES, DIFF_CONTENT, INVOKER_CONTEXT
- The agent reads files directly and performs its own analysis

Wait for both to complete. Collect the review file paths from their responses.

### Step 4: Launch Triage

After all reviewers complete, launch the review-triage agent:
- subagent_type: `general-purpose` (will use the review-triage agent definition)
- Provide: the list of review file paths from Step 3

Wait for triage to complete. Collect the triage file path and summary stats.

### Step 5: Present Results

**VERBATIM relay only.** Output exactly this format:

```
## Code Review Complete

**Triage report:** `{TRIAGE_FILE_PATH}`

**Summary:** {stats line from triage agent}

**Source reviews:**
- `{codex_file}`
- `{code-searcher_file}`

To view the full triage report: `cat {TRIAGE_FILE_PATH}`
To view individual reviews: `cat docs/review/{reviewer}-*.md`
```

**STOP.** Do not add any additional commentary, interpretation, reassurance, or softening. The triage report speaks for itself. If the user asks you about the findings, tell them to read the triage file.

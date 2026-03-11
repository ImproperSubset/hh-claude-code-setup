Iteratively simplify changed code until convergence — no more meaningful improvements found.

This command runs multiple rounds of code simplification, building on each iteration's results. Each round focuses only on what the previous round changed, carrying forward dismissed findings so they aren't re-suggested.

## Process

### Setup

1. Determine the scope of changed files:
   - If `$ARGUMENTS` is provided, use it as the scope (file paths, "last 3 commits", etc.)
   - Otherwise, check `git diff --name-only HEAD` for uncommitted changes
   - If on a feature branch, also consider `git diff --name-only main...HEAD`
   - Record the initial file list as `SCOPE_FILES`

2. Create a tracking structure:
   - `ITERATION` = 1
   - `DISMISSED` = [] (findings the user declined or that were rejected — never re-suggest these)
   - `ALL_CHANGES` = [] (cumulative log of what was changed across all iterations)
   - Record `BASE_REF` = current HEAD or stash ref so the user can revert everything if needed

### Iteration Loop

For each iteration:

3. **Snapshot before changes** — record `PRE_REF=$(git rev-parse HEAD)` and capture `git diff --stat` of any unstaged changes.

4. **Run the simplify skill** — invoke the `simplify` skill. If this is iteration 2+, include this context in your prompt to the skill:

   > Focus on these files: {SCOPE_FILES from previous iteration's changes}
   >
   > The following findings were already reviewed and dismissed in previous iterations — do NOT re-suggest them:
   > {DISMISSED list, each with file path, line range, and one-line description}

5. **Capture results** — after simplify completes, determine what happened:
   - `git diff --name-only` to find which files were modified
   - Review the changes made and catalog each one with a short description
   - Add all changes to `ALL_CHANGES`

6. **Check for convergence:**
   - If **no files were modified** → converged. Go to step 8.
   - If the only suggestions were items already in `DISMISSED` → converged. Go to step 8.
   - If **iteration >= 5** → safety cap reached. Go to step 8.
   - Otherwise → update `SCOPE_FILES` to only the files changed this iteration, increment `ITERATION`, continue loop.

7. **Between iterations** — present a brief status:

   ```
   ## Iteration {N} complete

   **Changed:** {count} file(s)
   {bullet list of changes with file:line and one-line description}

   Running iteration {N+1} on the changed files...
   ```

   If any changes from this iteration seem questionable or the user might want to weigh in, pause and ask before continuing. Otherwise proceed automatically.

### Wrap Up

8. **Run build and tests** to verify nothing broke:

   ```bash
   npm run build && npm test
   ```

   If tests fail, investigate. If a simplification caused the failure, revert that specific change and add it to `DISMISSED` with the reason. Re-run tests until green.

9. **Present final summary:**

   ```
   ## Simplify Loop Complete — Converged in {N} iteration(s)

   ### All Changes Applied
   | Iteration | File | Change |
   |-----------|------|--------|
   | 1 | `src/lib/foo.ts:42` | Replaced nested ternary with if/else |
   | 1 | `src/lib/bar.ts:15` | Removed redundant null check |
   | 2 | `src/lib/foo.ts:50` | Consolidated duplicate fetch calls |

   ### Dismissed Findings
   {list of items that were suggested but not applied, with reasons}

   ### Test Results
   {pass/fail summary}

   **To revert everything:** `git checkout {BASE_REF} -- .`
   ```

## Guidelines

- Each iteration should produce fewer changes than the last. If iteration 3 changes more files than iteration 2, something is oscillating — stop and flag it.
- Never re-suggest a dismissed finding. The dismissed list is sacred.
- If two iterations undo each other's work (A→B then B→A), that's oscillation — stop immediately and revert to the pre-oscillation state.
- Keep the user informed but don't ask for confirmation on every change. Only pause when something is surprising or risky.
- The goal is convergence, not perfection. Five iterations is generous — most code converges in 2-3.

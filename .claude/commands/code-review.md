Perform a multi-AI code review of the current codebase changes.

## What To Do

1. **Assess the current state** — determine what code needs review:
   - If `$ARGUMENTS` is provided, use it as a custom scope (e.g., a file path, "last 3 commits", "server/lambda/auth/signup.ts")
   - Otherwise, check `git status` and `git diff --stat HEAD` for uncommitted changes
   - Check if on a feature branch with commits ahead of main/master
   - Use conversation context to understand what the user has been working on
   - Compose a **REVIEW_TARGET** — a human-readable description of what to review (e.g., "changes on branch feat/foo vs main", "uncommitted changes in 5 files", "changes in server/lambda/auth/signup.ts")

2. **Prepare** — `mkdir -p docs/review`

3. **Launch three reviewer agents in parallel** (all in a single message):
   - **adversarial-reviewer**: Agent tool with `subagent_type: "adversarial-reviewer"` — provide REVIEW_TARGET, changed file list, diff content, and any invoker context (marked UNVERIFIED). Tries to break the code: attack surface, failure modes, race conditions, resource exhaustion.
   - **security-reviewer**: Agent tool with `subagent_type: "security-reviewer"` — provide REVIEW_TARGET, changed file list, diff content, and any invoker context (marked UNVERIFIED). Deep security audit: auth, crypto, IAM, input validation, data exposure.
   - **code-searcher-reviewer**: Agent tool with `subagent_type: "code-searcher-reviewer"` — provide REVIEW_TARGET, changed file list, diff content, and any invoker context (marked UNVERIFIED). Constructive review: correctness, test coverage, architecture fit, maintainability.
   - Each agent writes its findings to `docs/review/{agent}-{timestamp}.md`

4. **Wait for all three to complete**, collect file paths from their responses

5. **Launch review-triage agent** with the list of review file paths — it reads all review files, verifies each finding against actual code and Context7 documentation, and writes `docs/review/TRIAGE-{timestamp}.md`

6. **Read the triage report yourself** — `cat {TRIAGE_FILE_PATH}` — and understand each finding.

7. **Present initial findings** — show the triage summary so the user sees what was found before fixes begin:

```
## Code Review — Iteration 1

**Triage report:** `{TRIAGE_FILE_PATH}`

**Summary:** {stats from triage agent}

### Verified Findings

{For each verified finding, one bullet with severity and description:}
- **[SEVERITY]** {one-line description} — `{file}:{line}`

{If any findings were dismissed:}
### Dismissed: {count} finding(s) verified-false

{If any findings were auto-dismissed:}
### Auto-dismissed: {count} finding(s) from known patterns

**Source reviews:**
- `{adversarial_file}`
- `{security_file}`
- `{code-searcher_file}`
```

If there are **0 verified findings**, skip to step 12 (final summary) — nothing to fix.

8. **Fix verified findings** — record `git rev-parse HEAD` as `PRE_FIX_REF` before making any changes. For each verified finding in the triage report:
   - **CRITICAL/HIGH/MEDIUM:** Fix it. Read the file, understand context, apply the fix. Use the triage report's **Action** field as guidance but verify it makes sense before applying.
   - **LOW:** Fix if straightforward. Defer only with a **strong, specific argument** (e.g., "recommended fix adds complexity that outweighs the risk", "this pattern will be replaced when feature X ships", "the test gap exists but the code path is already covered by integration tests"). Vague deferrals like "low priority" are not acceptable.
   - **Test coverage gaps requiring heavy AWS mocking:** Defer when the finding is a coverage gap that would require complex, fragile mocks of AWS infrastructure (DynamoDB transactions, Cognito flows, S3 lifecycle, etc.). These are better addressed with integration tests or dedicated test infrastructure, not bolted-on unit test mocks that break on every refactor.
   - **UNVERIFIABLE:** Defer with explanation.
   - After fixing a batch of findings, **run the project test suite** to catch regressions early. Fix any test failures before proceeding.

9. **Record deferred findings** — if any findings were deferred, write them to `docs/review/DEFERRED-{timestamp}.md`:

```markdown
# Deferred Findings
<!-- Generated: {timestamp} | Iteration: {N} -->

### DF-001: {Title} [SEVERITY]
- **File:** `path/to/file.ext:LINE`
- **Flagged by:** {reviewers}
- **Triage report:** `{TRIAGE_FILE}`
- **Reason for deferral:** {specific justification}
```

10. **Re-review loop** — determine changed files from fixes (`git diff --name-only {PRE_FIX_REF}`) and re-review:
    - Run full review pipeline (steps 3-6) **scoped to changed files only** — pass the changed file list as the review scope.
    - Evaluate triage results:
      - **0 new verified findings → converged.** Go to step 11.
      - **Only findings matching already-deferred items → converged.** Go to step 11.
      - **New verified findings → fix and loop.** Present the new findings (step 7 format), fix them (step 8), record deferrals (step 9), and re-review again.
    - **Safety cap: 3 fix iterations.** If not converged after 3, present remaining findings in the final summary and stop.
    - Track iteration stats: `{iteration_number, verified_count, fixed_count, deferred_count, new_in_rereview}`.

11. **Run final test suite** — after convergence, run the project test suite one final time. If tests fail, fix failures (counts as another iteration, still under the 3-iteration cap).

12. **Present final summary:**

```
## Code Review Complete — Converged in {N} iteration(s)

### Iteration History
| # | Verified | Fixed | Deferred | New in re-review |
|---|----------|-------|----------|------------------|
| 1 | 7        | 5     | 2        | 1                |
| 2 | 1        | 1     | 0        | 0                |

### Fixes Applied
- **[SEVERITY]** {title} — `{file}:{line}` — {one-line fix description}

### Deferred Findings
- **[LOW]** {title} — `{file}:{line}`
  **Reason:** {specific justification}

### Test Results
{pass/fail summary}

**Review artifacts:**
- Triage reports: {list from each iteration}
- Deferred: `docs/review/DEFERRED-{timestamp}.md` (if any)
- Source reviews: {list from each iteration}
```

If there were 0 verified findings from the start, the summary simplifies to:

```
## Code Review Complete — Clean

No verified findings. {dismissed_count} finding(s) dismissed, {auto_dismissed_count} auto-dismissed.

**Review artifacts:**
- Triage report: `{TRIAGE_FILE_PATH}`
- Source reviews: {list}
```

13. **Do not soften or reassure.** Do not say "the code looks good overall", "most issues are minor", or "nothing critical to worry about". Present your analysis honestly — if something looks bad, say so. If you think a finding is wrong, argue your case with evidence.

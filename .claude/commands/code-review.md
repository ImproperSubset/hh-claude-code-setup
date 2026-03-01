Perform a multi-AI code review of the current codebase changes.

## What To Do

1. **Assess the current state** — determine what code needs review:
   - If `$ARGUMENTS` is provided, use it as a custom scope (e.g., a file path, "last 3 commits", "server/lambda/auth/signup.ts")
   - Otherwise, check `git status` and `git diff --stat HEAD` for uncommitted changes
   - Check if on a feature branch with commits ahead of main/master
   - Use conversation context to understand what the user has been working on
   - Compose a **REVIEW_TARGET** — a human-readable description of what to review (e.g., "changes on branch feat/foo vs main", "uncommitted changes in 5 files", "changes in server/lambda/auth/signup.ts")

2. **Prepare** — `mkdir -p docs/review`

3. **Launch two reviewer agents in parallel** (both in a single message):
   - **gemini-reviewer**: Task tool with `name: "gemini-reviewer"` — provide REVIEW_TARGET and any invoker context (marked UNVERIFIED). Gemini runs in agentic mode with full codebase access (reads files, runs git commands).
   - **code-searcher-reviewer**: Task tool with `name: "code-searcher-reviewer"` — provide REVIEW_TARGET, changed file list, diff content, and any invoker context (marked UNVERIFIED)
   - Each agent writes its findings to `docs/review/{agent}-{timestamp}.md`

4. **Wait for both to complete**, collect file paths from their responses

5. **Launch review-triage agent** with the list of review file paths — it reads all review files, verifies each finding against actual code and Context7 documentation, and writes `docs/review/TRIAGE-{timestamp}.md`

6. **Read the triage report yourself** — `cat {TRIAGE_FILE_PATH}` — and understand each finding.

7. **Present the results and your analysis:**

```
## Code Review Complete

**Triage report:** `{TRIAGE_FILE_PATH}`

**Summary:** {stats from triage agent}

### Verified Findings

{For each verified finding, one bullet with severity and description:}
- **[SEVERITY]** {one-line description} — `{file}:{line}`

{If any findings were dismissed:}
### Dismissed: {count} finding(s) verified-false

{If any findings were auto-dismissed:}
### Auto-dismissed: {count} finding(s) from known patterns

### Analysis

{For each verified finding, provide a 2-3 sentence assessment:}
- What is the real-world impact?
- How urgent is it given the current state of the project?
- If you believe a finding is less important than its severity suggests,
  you MUST explain why with specific evidence (e.g., "no users yet",
  "guarded by X upstream", "S3 lifecycle covers this"). Vague dismissals
  like "minor issue" or "low risk in practice" are not acceptable.

{If you see patterns across findings (e.g., "3 of 5 findings stem from
the legacy migration gap"), call that out.}

**Source reviews:**
- `{gemini_file}`
- `{code-searcher_file}`

Full triage report: `cat {TRIAGE_FILE_PATH}`
```

8. **Do not soften or reassure.** Do not say "the code looks good overall", "most issues are minor", or "nothing critical to worry about". Present your analysis honestly — if something looks bad, say so. If you think a finding is wrong, argue your case with evidence.

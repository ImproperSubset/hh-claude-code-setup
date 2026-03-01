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

6. **Present the triage report path, summary stats, and key findings VERBATIM:**

```
## Code Review Complete

**Triage report:** `{TRIAGE_FILE_PATH}`

**Summary:** {stats from triage agent}

### Verified Findings

{For each verified CRITICAL or HIGH finding, one bullet:}
- **[CRITICAL/HIGH]** {one-line description} — `{file}:{line}`

{For each verified MEDIUM finding, one bullet:}
- **[MEDIUM]** {one-line description} — `{file}:{line}`

{For each verified LOW finding, one bullet:}
- **[LOW]** {one-line description} — `{file}:{line}`

{If any findings were dismissed:}
### Dismissed: {count} finding(s) verified-false

{If any findings were auto-dismissed:}
### Auto-dismissed: {count} finding(s) from known patterns

**Source reviews:**
- `{gemini_file}`
- `{code-searcher_file}`

Full triage report: `cat {TRIAGE_FILE_PATH}`
```

7. **STOP. Do not editorialize, soften, dismiss, or add reassuring commentary about the findings.** Do not say "the code looks good overall", "most issues are minor", "nothing critical to worry about", or similar. The triage report is the deliverable. Relay it and stop.

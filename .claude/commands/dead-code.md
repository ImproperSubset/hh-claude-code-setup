Run a dead code audit using knip and clean up confirmed dead code.

## Scope

If `$ARGUMENTS` is provided, use it as the target directory (e.g., `client`, `server`, `server/lambda/shared`).
Otherwise, detect JS/TS packages by looking for `package.json` files in the working directory and immediate subdirectories. Run knip on each package.

## Step 1: Run knip

For each package directory:

```bash
cd <package-dir> && npx knip 2>&1
```

If the package uses Svelte and doesn't have a `knip.ts` config, create one with the Svelte compiler override:

```typescript
import type { KnipConfig } from 'knip';
import { compile } from 'svelte/compiler';

export default {
  compilers: {
    svelte: (source: string) => compile(source, {}).js.code,
  },
} satisfies KnipConfig;
```

Capture the full output for each package.

## Step 2: Triage every finding

For each finding, classify it as **REAL** or **FALSE POSITIVE**. Be thorough — read the actual code before deciding.

**Common false positives:**
- `esbuild` as unused dep — CDK NodejsFunction uses it for Lambda bundling
- Playwright setup files (`auth.setup.ts`) — project dependencies, not regular imports
- E2E helper functions — used in spec files that knip may not trace
- SvelteKit route files (`+page.svelte`, `+layout.ts`, `+server.ts`) — framework entry points
- CDK stack files and `bin/` entry points — referenced in `cdk.json`, not imported
- Types/interfaces used only in JSDoc comments or generic constraints
- Exports consumed by other packages in a monorepo

**Common real dead code:**
- Functions/types that were replaced during refactoring but never removed
- One-time migration scripts left in the repo
- Helper utilities that were inlined or superseded
- API request/response types defined in the client that are only needed server-side (or vice versa)
- Exports that lost their last consumer when a feature was rewritten

**When uncertain:** Check git blame to understand why the code exists. If it was part of a feature that's still active, it's probably a false positive. If the last meaningful change was a refactor that replaced its usage, it's probably dead.

## Step 3: Present findings

Show a summary table before making changes:

```
## Dead Code Audit — <package>

### Confirmed Dead Code (will remove)
| Category | Item | File | Evidence |
|----------|------|------|----------|
| Unused export | `functionName` | `path/to/file.ts:42` | No imports found, replaced by X in commit abc123 |

### False Positives (will ignore)
| Category | Item | File | Reason |
|----------|------|------|--------|
| Unused dep | `esbuild` | `package.json` | CDK Lambda bundling |

### Uncertain (needs human review)
| Category | Item | File | Notes |
|----------|------|------|-------|
```

Wait for user confirmation before proceeding to cleanup. If uncertain items exist, ask about them.

## Step 4: Clean up

For confirmed dead code:
- **Unused files:** Delete them
- **Unused exports:** Remove the `export` keyword if the function/type is still used locally, or delete entirely if the whole thing is dead
- **Unused dependencies:** Remove from `package.json` and run `npm install` to update the lockfile
- **Unlisted dependencies:** Add to `package.json` under the appropriate section (dependencies vs devDependencies)
- **Unused types:** Delete them. If removing a type leaves an empty file, delete the file.

Do NOT remove code you classified as uncertain or false positive.

## Step 5: Verify

```bash
cd <package-dir> && npm run build && npm test
```

If tests or build fail, investigate — you may have removed something that was actually used through a path knip couldn't trace. Restore it and reclassify as false positive.

## Step 6: Configure knip ignores

For confirmed false positives that will recur on every run, add ignore rules to the package's knip config so future runs are clean. Check knip docs for the correct ignore syntax (`ignoreDependencies`, `ignore`, `entry`, etc.).

## Step 7: Re-run and confirm clean

Run `npx knip` again. The output should show only known false positives that can't be configured away. If new findings appear from the cleanup (removing one thing can surface another), triage and handle them.

## Step 8: Commit

Two separate commits:
1. **knip config** — any new or updated `knip.ts`/`knip.json` files
2. **dead code cleanup** — removed files, exports, dependencies

## Guidelines

- Read code before deleting it. Don't blindly trust knip — it's static analysis with known blind spots.
- Check CLAUDE.md for project-specific patterns that affect triage (e.g., Dexie repository functions, CDK grant patterns).
- Preserve the license header when editing files.
- If the cleanup is large (>20 deletions), break it into logical groups and verify after each group.

Perform a full codebase review in two passes. Do NOT modify any code.

## Setup

mkdir -p docs/review

## Pass 1: Server

Review all source files under server/lib/ and server/lambda/ (exclude node_modules, dist, cdk.out, __tests__). This
is AWS CDK + Lambda TypeScript code handling auth, encryption, DynamoDB, S3 presigned URLs, and federation.

Launch two reviewer agents IN PARALLEL:
- codex-reviewer: REVIEW_SCOPE is "full-tree:server", provide the file list
- code-searcher-reviewer: REVIEW_SCOPE is "full-tree:server", provide the file list and source content

Each writes to docs/review/{agent}-server-{timestamp}.md

After both complete, launch review-triage with the two server review files. It writes
docs/review/TRIAGE-server-{timestamp}.md.

## Pass 2: Client

Review all source files under client/src/ (exclude node_modules, .svelte-kit, build). This is SvelteKit 5 TypeScript
with E2EE crypto, stores, and PWA service worker.

Same two reviewers in parallel, same triage afterward. Files named with -client- instead of -server-.

## Presentation

For each pass, present the triage report path and stats VERBATIM. Do not editorialize, soften, dismiss, or add
reassuring commentary about the findings.

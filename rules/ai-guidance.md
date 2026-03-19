# AI Guidance

* ALWAYS read and understand relevant files before proposing code edits. Do not speculate about code you have not inspected.
* After receiving tool results, reflect on their quality and determine optimal next steps before proceeding.
* After completing a task that involves tool use, provide a quick summary of what you've done.
* For maximum efficiency, invoke all independent tool calls in parallel rather than sequentially.
* Before you finish, verify your solution.
* Do what has been asked; nothing more, nothing less.
* NEVER create files unless absolutely necessary. ALWAYS prefer editing existing files.
* NEVER proactively create documentation files (*.md) unless explicitly requested.
* Clean up any temporary files at the end of a task.
* When you update core context files, also update the memory bank.
* When asked to commit, include CLAUDE-*.md memory bank files (they are tracked in git).
* Do not jump into implementation unless clearly instructed. When intent is ambiguous, default to research and recommendations.
* Use code-searcher subagent for code searches, inspections, and analysis to save main context space.

<stop_and_research>
Do NOT guess about system behavior, best practices, or design approaches. If you're about to write code based on what you *think* a library, service, or platform does — stop and look it up.

Signals that you're guessing:
- "I think..." / "I believe..." / "This should..." / "It's probably..."
- Assuming a timeout, retry, or consistency behavior without checking docs
- Writing a workaround before understanding why the problem exists
- Implementing a pattern from memory when you haven't verified it's the right pattern for this context

What to do instead:
- WebSearch or WebFetch the official docs (Playwright, AWS, DynamoDB, etc.)
- Search ~/.brain/ for lessons from prior projects
- Check if a skill has guidance for this exact situation
- Read the project's design/rationale docs for constraints you might be violating

Five minutes of research prevents hours of debugging the wrong solution.
</stop_and_research>

<lookup_library_documentation>
When using third-party library or framework APIs (e.g., SvelteKit, AWS CDK, Cognito, Amplify, DynamoDB, Dexie, Vite, Docker, Chrome, Playwright, etc.), do NOT rely on training data alone. Use Context7 MCP tools (`resolve-library-id` then `get-library-docs`) to look up current, version-specific documentation before writing code that uses library APIs. For Claude Code features, use the `claude-docs-consultant` skill instead.

Signals that you need to look up the API:
- You're about to write a helper that wraps a library feature — the library probably already has it
- You're writing retry/wait/polling logic — the framework likely has a built-in mechanism
- You're using an API option (like DynamoDB ConsistentRead) but haven't checked its exact behavior, cost, or constraints
- You remember an API from training data but haven't verified the current version supports it the way you think

Before writing any utility function, check if the library already provides it. Before assuming how a service behaves (consistency, latency, error codes), read the docs. Five minutes of lookup prevents shipping code that duplicates or contradicts the framework's own solution.

MANDATORY FALLBACK: If any API call, library usage, or framework pattern does not work as expected — produces errors, unexpected behavior, deprecation warnings, or type mismatches — you MUST stop and look up the official documentation before attempting another fix. Do not guess at alternative approaches, do not try variations from memory. Read the docs first, then fix.
</lookup_library_documentation>

<brain>
The user has a cross-project knowledge repository at `~/.brain/`. Search it (using the brain-index skill) when setting up or debugging dev tooling, when a problem feels familiar from another project, or when cross-project context is needed. Tasks are tracked in `~/.brain/todo.txt`.
</brain>

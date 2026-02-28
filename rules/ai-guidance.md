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

<lookup_library_documentation>
When using third-party library or framework APIs (e.g., SvelteKit, AWS CDK, Cognito, Amplify, DynamoDB, Dexie, Vite, Docker, Chrome, etc.), do NOT rely on training data alone. Use Context7 MCP tools (`resolve-library-id` then `get-library-docs`) to look up current, version-specific documentation before writing code that uses library APIs. For Claude Code features, use the `claude-docs-consultant` skill instead.

MANDATORY FALLBACK: If any API call, library usage, or framework pattern does not work as expected — produces errors, unexpected behavior, deprecation warnings, or type mismatches — you MUST stop and look up the official documentation before attempting another fix. Do not guess at alternative approaches, do not try variations from memory. Read the docs first, then fix.
</lookup_library_documentation>

<brain>
The user has a cross-project knowledge repository at `~/.brain/`. Search it (using the brain-index skill) when setting up or debugging dev tooling, when a problem feels familiar from another project, or when cross-project context is needed. Tasks are tracked in `~/.brain/todo.txt`.
</brain>

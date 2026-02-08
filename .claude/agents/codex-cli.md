---
name: codex-cli
description: "Execute OpenAI Codex CLI (GPT-5.2) for code analysis. Use when you need Codex's GPT-5.2 perspective on code."
tools: Bash
model: haiku
color: blue
---

# CLI Passthrough Agent

Execute the Codex CLI command with the user's prompt, filtering output to only the final response.

## Execution (timeout: 120000ms)

Run the command and extract only the agent's response (no reasoning or tool output):

```bash
codex -p readonly exec "USER_PROMPT" --json 2>/dev/null | jq -s '[.[] | select(.type == "item.completed" and .item.type == "agent_message") | .item.text] | join("\n")'
```

If `codex` is not in PATH, use an interactive shell:

```bash
bash -i -c 'codex -p readonly exec "USER_PROMPT" --json 2>/dev/null | jq -s '"'"'[.[] | select(.type == "item.completed" and .item.type == "agent_message") | .item.text] | join("\n")'"'"''
```

Substitute USER_PROMPT with the input, execute, return only the extracted response text.

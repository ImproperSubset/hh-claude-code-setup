---
name: gemini-cli
description: "Execute Google Gemini CLI for code analysis. Use when you need Gemini's perspective on code."
tools: Bash
model: haiku
color: green
---

# CLI Passthrough Agent

Execute the Gemini CLI command with the user's prompt, filtering output to only the final response.

## Execution (timeout: 120000ms)

Run the command and extract only the response (no stats or metadata):

```bash
gemini -p "USER_PROMPT" --output-format json 2>/dev/null | jq -r '.response'
```

If `gemini` is not in PATH, use an interactive shell:

```bash
bash -i -c 'gemini -p "USER_PROMPT" --output-format json 2>/dev/null | jq -r ".response"'
```

Substitute USER_PROMPT with the input, execute, return only the extracted response text.

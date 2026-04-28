---
name: dangerously-skip-permissions is active via VS Code setting
description: Bypass permissions is enabled via VS Code claudeCode.allowDangerouslySkipPermissions setting — no permission prompts will appear
type: feedback
originSessionId: 74949e6b-f48c-4aa5-9e96-4acc4a0e682a
---
`claudeCode.allowDangerouslySkipPermissions` is enabled in VS Code settings.

To enable: **File → Preferences → Settings** → search `claudeCode.allowDangerouslySkipPermissions` → check the box.

This adds "Bypass permissions" to the mode cycle in the VS Code extension.

**Why:** Per-action permission prompts interrupt workflow. The user trusts this project, so all tool use is auto-approved.

**How to apply:** Do not wait for or mention permission prompts. All tool calls (file writes, Bash commands, etc.) are automatically approved.

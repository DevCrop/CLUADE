---
name: RTK prefix compliance
description: Claude must consistently apply rtk prefix to multi-line Bash commands; failing to do so wastes tokens and breaks the optimization contract
type: feedback
originSessionId: e27dfc38-3a8c-4680-a987-e55308ba0db7
---
Always use `rtk` prefix for any Bash command whose output spans more than a few lines.

Specific commands that must use rtk prefix:
- `rtk ls <path>` — not plain `ls`
- `rtk grep <pattern> <path>` — not plain `grep`
- `rtk read <file>` — or better, use the Read tool (not Bash cat)
- `rtk git status/log/diff` — never plain git for these

**Why:** User flagged that in a full session (2026-04-28), RTK ran only 1 time with near-zero savings because Claude used plain `ls` and `cat` instead of rtk-prefixed equivalents. This defeats the token optimization architecture entirely.

**How to apply:** Before every Bash call, ask: "will this output more than a few lines?" If yes → rtk prefix. For file reads, prefer the Read tool over Bash cat. RTK does not apply to PowerShell ps1 invocations — those are exempt.

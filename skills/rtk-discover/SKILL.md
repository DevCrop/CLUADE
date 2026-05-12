---
name: rtk-discover
description: Run rtk discover with the Windows-native CWD workaround. Use when the user asks for RTK session counts, savings stats, or wants to verify RTK is logging this project. Required because plain `rtk discover` returns 0 on Windows native (rtk-ai/rtk#1743, still open in v0.39.0).
---

# rtk-discover (Windows-native CWD workaround)

## Why this skill exists

RTK stores per-project session metadata keyed by Claude Code's mangled path
(`:`, `\`, `/` -> `-`). RTK's auto-detected CWD does not apply that mangling
before substring match, so `rtk discover` (no args) returns 0 sessions on
Windows native even when sessions exist.

- Issue: https://github.com/rtk-ai/rtk/issues/1743 (state: open)
- v0.38.0 fix covered `.`, `_`, ` `, non-ASCII — NOT `:` or `\`
- Confirmed reproducing on v0.39.0 (latest stable as of 2026-05-09)

## How to invoke

```bash
# bash / Git Bash
leaf=$(basename "$(pwd)") && rtk discover -p "$leaf"
```

```powershell
# PowerShell (alias defined in $PROFILE)
rtk-discover-here
```

```powershell
# PowerShell explicit
$leaf = Split-Path -Leaf (Get-Location)
rtk discover -p $leaf
```

## Caveats

- Leaf-name collisions across projects combine results. Use unique leaf names
  (e.g. numeric IDs, kebab-case slugs).
- After RTK binary upgrade, run `rtk trust` interactively once to re-trust
  any project-level `.rtk/filters.toml`.

## When to remove this skill

Re-test plain `rtk discover` after each RTK release. If it returns the
correct count from a project CWD on Windows native, this skill is obsolete:

1. Verify Issue #1743 is closed: `curl -s https://api.github.com/repos/rtk-ai/rtk/issues/1743 | grep '"state"'`
2. From `d:\project\<name>` in PowerShell: plain `rtk discover` returns >0
3. Remove this skill, the `rtk-discover-here` function in `$PROFILE`,
   and the Windows-native caveat in `RTK.md`.

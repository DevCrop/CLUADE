# Global AI Rules (Windows Native, Claude-Only)

This machine runs **Claude Code on Windows native** as the sole AI assistant. All rules below are calibrated to that environment — do not generalize across WSL, Linux, or other AI tools.

For the full architecture (drive layout, hooks, retention, compaction, AI tool exclusivity), read `%USERPROFILE%\.claude\ARCHITECTURE.md`.

## DO

- DO answer the user in **Korean** (chat replies). Use English for AI-consumed artifacts: docs, hooks, plans, MEMORY topic files, AUTO marks, comments, log messages. Code identifiers, paths, commands, error messages stay English verbatim.
- DO state results and decisions **directly**. Do not enumerate the reasoning process or narrate intermediate thoughts.
- DO type Bash commands normally; the global PreToolUse hook (`hooks/rtk-prerewrite.js`) auto-prefixes every call with `rtk`. Bypass per-command via `RTK_DISABLED=1 <cmd>` when raw output is required. See @RTK.md.
- DO **verify the work matches the user's original order** before declaring "완료" / "done". Use the order-match procedure below.
- DO route every Claude artifact under `%USERPROFILE%\.claude\` (the default location). All paths in scripts derive from `$env:USERPROFILE` or `$env:CLAUDE_CONFIG_DIR` fallback.

## DON'T

- DON'T re-run `rtk init -g --auto-patch` or set up WSL — auto-rewrite is already wired via the PreToolUse hook on this Windows-native machine.
- DON'T add hooks, scripts, agents, or rules without a documented recurring need. **FOMO guard**: a feature looking interesting is not justification — point to a past incident or measurable benefit, or skip it.
- DON'T deviate from default Claude Code behavior unless an incident or measurable cost forced the customization. **Vanilla compliance**: the closer to stock, the easier upgrades and debugging become.
- DON'T relocate the `.claude` config root to D: (e.g. `D:\.claude\`, `D:\.claude-data\`). Global Claude infra lives under `%USERPROFILE%\.claude\` on whichever drive holds the user profile. Project work on D: is fine and expected — the prohibition targets splitting the `.claude` infra across drives, not D-drive paths in project content.
- DON'T commit or read `.credentials*` files. Don't run destructive git operations (force push, hard reset) unless the user explicitly orders it.
- DON'T use destructive shortcuts (`rm -rf`, `--no-verify`, `git push --force`) to bypass an obstacle — fix the root cause.

## Order Match Verification (mandatory before declaring task done)

Before saying the task is complete:

1. **Restate the order** — paste the user's original request as a one-liner.
2. **List acceptance criteria** — what observable state would prove completion?
3. **Map criteria → evidence** — for each, cite `file:line`, command output, or test result.
4. **Detect scope creep** — anything done outside the order? Justify it or revert.
5. **Honor constraints** — language, paths, tools the user specified. Verify each.

If any criterion lacks evidence: do **not** declare done. Either complete it or explicitly report the gap.

Template: `%USERPROFILE%\.claude\templates\order-match-checklist.md`.

## Auto Memory

The auto-memory system runs on `%USERPROFILE%\.claude\projects\<project>\memory\MEMORY.md` index plus per-topic `.md` files. Index capped at 200 lines / 25 KB; split into topic files when it grows. Four memory types: user profile, feedback, project context, external-system reference.

## New Project Setup

See `%USERPROFILE%\.claude\templates\project-init.md`. Standard layout (per project): `CLAUDE.md` / `AGENTS.md` / `.claude/rules/` / `.claude/agents/` / `.claude/settings.json`. There is no global `AGENTS.md` — that file is per-project only.

## Frequently Used Skills

`/loop` (recurring interval) - `/schedule` (cron) - `/review` (PR review) - `/security-review` - `/init`. Project-scoped: `/new-route` (260427 only).

## Active Global Hooks

Configured in `%USERPROFILE%\.claude\settings.json`. **8 hook events** (PreToolUse, SessionStart, SessionEnd, PostToolUse, UserPromptSubmit, PreCompact, PostCompact, Stop) — 9 command entries (SessionEnd registers 2) — plus a `statusLine` renderer and one `env` setting. See AUTOMATION.md for the architecture diagram and current registration table.

- **PreToolUse** (`Bash`): RTK auto-rewrite via `hooks/rtk-prerewrite.js`. Bypass per-command with `RTK_DISABLED=1 <cmd>`.
- **SessionStart**: regenerate AUTOMATION.md AUTO marks, auto-pin project, memory-lint, weekly memory-backup, 24h doc-update gate, 60-day plan archive, D-drive remnant detection.
- **SessionEnd**: rotate retention dirs (plans/shell-snapshots/file-history/projects/session-env/backups + 6 extended caches), MEMORY.md link integrity, kill stale workers >24h. Drift-detect-worker drains `.drift-queue` to `review-needed.md`.
- **PostToolUse** (`Edit|Write|Bash`): drift-enqueue files / dep-install audits.
- **UserPromptSubmit**: skip-when-clean git status / log injection (prefix-cache safe).
- **PreCompact** / **PostCompact**: snapshot memory + active plans via hard-link; verify @import chain integrity post-compact.
- **Stop**: append rtk session stats to `reports\token-usage.md`.
- **statusLine**: cwd-leaf | model | effort | session count | compact warning.
- **env**: `ENABLE_PROMPT_CACHING_1H=1` only (vanilla baseline). `prefix-version.txt` is bumped on rule changes to invalidate stale cache.

## RTK on This Machine

Auto-rewrite via PreToolUse hook (`hooks/rtk-prerewrite.js`) — every Bash call is prefixed automatically. Built-ins (`echo`, `pwd`), already-prefixed commands, and `RTK_DISABLED=1 <cmd>` bypass calls pass through unchanged. Manual prefixing is also safe.

@RTK.md

## Permission-Mode Caveat

`permissions.defaultMode = "bypassPermissions"` + `skipDangerousModePermissionPrompt = true` are active. **Safe only inside Docker / isolated environments.** When working directly on the host, the safety net relies on `permissions.deny` (`rm -rf`, force push, hard reset, `.credentials`); keep `settings.json` in sync when adding new deny entries.

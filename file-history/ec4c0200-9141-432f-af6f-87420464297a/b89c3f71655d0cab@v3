# Claude Code 100% Automation Harness Plan

## Context

**Why this change now**

The current setup already has a solid baseline: SessionStart 4-step, SessionEnd cleanup, PreToolUse RTK rewrite (WSL), per-project tsc PostToolUse, MEMORY 11-topic split, and a 14-item SETUP_CHECKLIST. From a senior AI-harness perspective, however, three decisive gaps remain:

1. **Six official hook events left empty** -- `PostToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `PreCompact`, `PostCompact` -- so docs drift after edits, memory loss after compaction, and per-session token accounting are all manual.
2. **1-hour prompt cache unused** -- long sessions still pay full prefix re-processing tokens despite RTK's 60-90% savings.
3. **Doc drift detection missing** -- `check-updates-worker` only SHA-diffs upstream docs; it never connects those changes to impacted sections in `CLAUDE.md` / `AGENTS.md` / `BEST_PRACTICES.md`.

**Intended outcome**: 100% automation for Claude (other AI tools keep manual prefixing) -- deterministic hook automation, prompt cache, automatic doc sync, and hardened memory. RTK, MEMORY topic split, and the D-drive policy are **immutable assets**.

---

## Design Principles (immutable)

1. **Use only official hook events / settings keys** -- absorbs schema changes automatically.
2. **Async by default**; block only when correctness-critical. SessionStart latency target `<100ms`.
3. **Idempotent + re-entry guard** -- `$env:CLAUDE_HOOK_DEPTH >= 1` exits immediately to prevent hook recursion.
4. **Prefix-stable, suffix-volatile** -- runtime context is injected only at the prompt suffix to keep the 1h cache warm.
5. **Frozen assets**: [session-start.ps1](D:/.claude/hooks/session-start.ps1) ordering, [cleanup.ps1](D:/.claude/cleanup.ps1) base retention policy, RTK PreToolUse, project tsc PostToolUse, MEMORY 11-topic split, [permissions.deny](D:/.claude/settings.json) entries.

---

## Decisions (user-confirmed)

| Item | Decision |
|---|---|
| Scope | **P0 + P1**; P2 listed only as future triggers |
| 1h prompt cache | **Enabled** + suffix-only dynamic injection + auto-bump `prefix-version.txt` on rule changes |
| UserPromptSubmit | **Skip-when-clean** -- when `git status --porcelain` is empty the hook avoids the PowerShell cold-start entirely |
| MCP activation | **Disabled, explicitly** (`enabledMcpjsonServers: []` declared); revisit later |
| Language | **All AI-consumed content in English**; user chat replies stay in Korean (per `feedback_english_for_ai.md`) |

---

## P0 -- Day 1-2 (immediate impact)

### P0-1. Enable 1h prompt cache  [DONE]
- `D:\.claude\settings.json` -> `env.ENABLE_PROMPT_CACHING_1H = "1"`
- Risk: stale rule snapshots can persist for up to 1h -- mitigated by P1-3 `prefix-version.txt` bump.

### P0-2. Stop hook -> automatic token-usage report  [DONE]
- New: `D:\.claude\hooks\token-report.ps1`
- Pulls `rtk gain --session --json`; appends a row to `D:\.claude\reports\token-usage.md` under an idempotent per-day heading.

### P0-3. PreCompact / PostCompact hooks  [DONE]
- New: `D:\.claude\hooks\precompact-snapshot.ps1` -- hard-link MEMORY + active plans into `D:\.claude\backups\precompact-<sessionId>\`. Disk cost ~zero on NTFS; falls back to copy if hard-link is unsupported.
- New: `D:\.claude\hooks\postcompact-verify.ps1` -- check `@import` chain integrity in CLAUDE.md / RTK.md; surface broken links on stderr.

### P0-4. UserPromptSubmit (skip-when-clean)  [DONE]
- New: `D:\.claude\hooks\inject-runtime-ctx.ps1` -- exits immediately when the repo is clean. When dirty, emits a compact `<context-runtime>` block with `git status` + `git log -3` plus a `<cache-bust v="N"/>` invalidation tag.

### P0-5. AUTO-mark expansion  [DONE]
- `update-docs.ps1` extended: `Update-AutoSection` helper now handles `<!-- AUTO:HOOK-EVENTS-START/END -->` and `<!-- AUTO:SKILLS-START/END -->`.
- `AUTOMATION.md` gained the corresponding sections.
- `auto-pin.ps1` first-line comment switched to English so the SCRIPTS table renders cleanly.

### P0-6. SessionStart memory-lint  [DONE]
- New: `D:\.claude\hooks\memory-lint.ps1` (50ms scan)
- Detects broken `[text](path.md)` links, missing files, empty topic bodies; writes a one-line summary to `D:\.claude\session-env\memory-lint.txt`.
- `session-start.ps1` now runs 6 steps (added `memory-lint.ps1` + `memory-backup.ps1`).

### P0-7. Project PostToolUse fan-out  [DONE]
- Single `Edit|Write` matcher dispatches by file extension:
  - `.test.ts(x)` -> `rtk vitest run <file> --reporter=dot` (async)
  - `.ts/.tsx` (non-test) -> `rtk tsc --noEmit` (blocking, exit 1 on failure)
  - `.php` -> `rtk docker compose exec -T web php -l <file>`
  - `.scss` -> `npx --no-install stylelint <file>`
- File paths quoted via `JSON.stringify` to neutralize spaces / Korean characters.

---

## P1 -- Week 1-2 (automation hardening)

### P1-1. Global drift detector  [DONE]
- New: `D:\.claude\hooks\drift-enqueue.ps1` (PostToolUse, async, all of `Edit|Write|Bash`).
- New: `D:\.claude\hooks\drift-detect-worker.ps1` (SessionEnd, async).
- Skips files inside `D:\.claude\` to avoid feedback loops; routes `npm install` / `pip install` / `composer require` / `pnpm add` / `yarn add` to a separate `dep-audit.tsv` queue.
- Worker compares enqueued paths against `<!-- DOC-REF: ... -->` markers in BEST_PRACTICES.md across all projects, then appends findings to `D:\.claude\review-needed.md` under an idempotent per-day heading.

### P1-2. check-updates-worker impact queueing  [DONE]
- When an upstream doc SHA changes, the worker greps `CLAUDE.md` / `RTK.md` / `AUTOMATION.md` for keywords mapped to that doc (`memory.md` -> "memory", "import"; `hooks.md` -> hook events; etc.) and queues each match line in `review-needed.md`.

### P1-3. Prefix-version invalidate  [DONE -- folded into update-docs.ps1]
- `update-docs.ps1` watches mtime of `CLAUDE.md` / `RTK.md` / `AUTOMATION.md`. On any change it bumps `D:\.claude\.docs-cache\prefix-version.txt`.
- `inject-runtime-ctx.ps1` reads that version on dirty turns and appends `<cache-bust v="N"/>` to invalidate the 1h cache on the next prompt.

### P1-4. statusLine v2  [DONE]
- New: `D:\.claude\statusline.ps1`
- Shows `cwd-leaf | model | effort:<level> [cache:1h] | sessions:<n>` (today's session count from `token-usage.md`).

### P1-5. BEST_PRACTICES DOC-REF markers  [DONE -- topic split skipped]
- The file is already English and under 8 KB; splitting offered low ROI. Instead, inserted `<!-- DOC-REF: <path> -->` markers next to the Review Triggers list so `drift-detect-worker.ps1` flags doc references for files that change.

### P1-6. Weekly memory backup + cleanup extensions  [DONE]
- New: `D:\.claude\hooks\memory-backup.ps1` -- once per ISO week zips every project memory dir to `D:\.claude\backups\memory-YYYYWW.zip`. Idempotent: skips when the file exists.
- `cleanup.ps1` extended to rotate `backups/precompact-*` >28 days, `backups/memory-*.zip` >56 days, and to kill stale hook workers (>24h CreationDate, CommandLine matches `D:\.claude\hooks\`).

### P1-7. Project MCP intent  [DONE]
- Project `settings.json` declares `enableAllProjectMcpServers: false`, `enabledMcpjsonServers: []`, `disabledMcpjsonServers: []` -- explicit "off" rather than implicit.

---

## P2 -- Future Extensions (declared only)

| Item | Trigger condition |
|---|---|
| `/pr-prep` skill (git diff -> PR body draft) | When PR creation reaches >=3/week |
| Stale memory check (60d mtime guard) | When topic-file count exceeds 20 |
| Skill `description` <=1536 chars lint | When >=5 skills are deployed |
| MCP-in-hook (Notion auto-sync) | After MCP activation decision |
| `TaskCreated` hook integration | Once GA on the official channel |

---

## Risks & Mitigations

| Risk | Scenario | Mitigation |
|---|---|---|
| PowerShell encoding | Korean filenames / comments break ANSI | Every new `.ps1` writes UTF-8; ASCII separators (`->`) instead of em-dash. |
| Async worker leakage | `drift-detect-worker` etc. accumulate in background | `cleanup.ps1` kills powershell processes whose CommandLine matches `D:\.claude\hooks\` and CreationDate is older than 24h. |
| Hook recursion | A PostToolUse hook editing `review-needed.md` retriggers itself | Re-entry guard `$env:CLAUDE_HOOK_DEPTH`. Writes target only directories outside the hook's matchers (`reports/`, `session-env/`, `.drift-queue/`, `review-needed.md`). |
| 1M context * 1h cache | Stale rule pinned for an hour | P1-3 `prefix-version.txt` bump. UserPromptSubmit emits suffix-only blocks. |
| Official schema change | Hook key renamed / event removed | `check-updates-worker` SHA-diff on `settings.md` queues impact sections automatically. |
| RTK stat distortion | 1h cache muddies RTK gain reporting | `token-usage.md` table separates `cache_read` and RTK-filtered savings (next iteration). |
| UserPromptSubmit > 800ms | Large repo, slow `git status` | Skip-when-clean fast-path; on timeout the hook returns no output. |

---

## Critical Files

### New (10)
- `D:\.claude\hooks\token-report.ps1`
- `D:\.claude\hooks\precompact-snapshot.ps1`
- `D:\.claude\hooks\postcompact-verify.ps1`
- `D:\.claude\hooks\inject-runtime-ctx.ps1`
- `D:\.claude\hooks\memory-lint.ps1`
- `D:\.claude\hooks\memory-backup.ps1`
- `D:\.claude\hooks\drift-enqueue.ps1`
- `D:\.claude\hooks\drift-detect-worker.ps1`
- `D:\.claude\statusline.ps1`
- `D:\.claude\reports\token-usage.md`, `D:\.claude\.docs-cache\prefix-version.txt` (auto-generated)

### Modified
- `D:\.claude\settings.json` -- 5 new hook events + env + statusLine
- `D:\.claude\hooks\session-start.ps1` -- 6-step chain
- `D:\.claude\hooks\update-docs.ps1` -- AUTO helpers + prefix-version bump
- `D:\.claude\hooks\check-updates-worker.ps1` -- impact queueing
- `D:\.claude\hooks\auto-pin.ps1` -- English comments
- `D:\.claude\cleanup.ps1` -- backups retention + worker kill
- `D:\.claude\CLAUDE.md`, `D:\.claude\RTK.md` -- English
- `d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\settings.json` -- PostToolUse fan-out + MCP intent
- `d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\BEST_PRACTICES.md` -- DOC-REF markers
- `d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\rules\php.md`, `scss.md` -- English

### Frozen (unchanged)
- `session-start.ps1` ordering of update-docs / auto-pin / check-updates / archive-plans
- `cleanup.ps1` base retention policy (plans 2d / shell-snapshots 7d / file-history 14d / projects 30d-pinned-aware)
- RTK PreToolUse rewrite
- Project `.claude/rules/{frontend,php,scss}.md` `paths:` frontmatter shape
- MEMORY.md 11-topic split
- `permissions.deny` 8 entries

---

## Verification

### Unit
- **P0-1**: `claude --debug api` -- target `cache_read_input_tokens` ratio >=70% after 24h.
- **P0-2**: Two consecutive Stop hooks produce one row per call under today's heading without duplicating the heading. (Verified: row appended idempotently.)
- **P0-3**: `precompact-snapshot.ps1` produced `D:\.claude\backups\precompact-20260427-171729-unknown\`. `postcompact-verify.ps1` produced no broken-import output (CLAUDE.md / RTK.md clean).
- **P0-4**: Clean repo -> `inject-runtime-ctx.ps1` exits with no output. Dirty repo -> emits the `<context-runtime>` block plus `<cache-bust v="1"/>`.
- **P0-5**: `update-docs.ps1` populated SCRIPTS / HOOK-EVENTS / SKILLS / TIMESTAMP marks; `prefix-version.txt` initialized to `1 <ticks>`.
- **P0-6**: `memory-lint.txt` reports "memory-lint OK (4 projects scanned)".
- **P0-7**: `JSON.stringify`-quoted file paths flow through to `php -l` / `stylelint` / `vitest` correctly.

### Integration
- **Hook recursion safety**: drift-enqueue skips files under `D:\.claude\` and the re-entry guard caps depth at 1.
- **1h cache integrity**: `prefix-version.txt` bumps when CLAUDE.md / RTK.md / AUTOMATION.md mtime advances; `inject-runtime-ctx.ps1` consumes the value to invalidate.
- **Spec alignment**: `claude --debug hooks` should match the event names in [code.claude.com/docs/en/hooks.md](https://code.claude.com/docs/en/hooks.md).

### Regression (frozen assets)
- SessionStart latency under 100ms after 6-step expansion.
- `cleanup.ps1` base retention policy unchanged; verify with `git diff` line-by-line.
- RTK rewrite rate stable under `rtk gain --history`.
- MEMORY.md still has 11 topic files (no accidental loss).

### 7-day Baseline
- 7 days of `token-usage.md` rows -> cache_read ratio, RTK savings, daily token consumption -- look for stability.
- `review-needed.md` false-positive count target <=5 / day; tune drift detector keywords above that.

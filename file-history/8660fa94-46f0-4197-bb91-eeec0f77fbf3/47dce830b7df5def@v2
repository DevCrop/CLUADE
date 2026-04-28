# Global Claude Architecture — Coherence Pass

## Context

The global Claude Code config at `C:\Users\nineonelabs003\.claude\` and the project rules at `d:\최신프로젝트\나인원랩스\퍼블\260427\` work, but contain several **internal contradictions, duplicated content that has drifted, and stale environment references** that an AI agent reading these documents at session start would interpret two different ways. The audit (Phase 1) confirmed:

- RTK rules are duplicated in `CLAUDE.md` (lines 73-205) AND `RTK.md` — same machine loads both, ~135 lines of churn per session.
- The drive policy is described three ways across `CLAUDE.md`, `ARCHITECTURE.md`, and project `AGENTS.md`. Read literally, ARCHITECTURE.md L20/L94 forbid the very D-drive paths the project lives on.
- Hook count: ARCHITECTURE.md says "Eight hook events" (L100) and "9 hooks registered" (L196); `CLAUDE.md` lists 7 events + `statusLine`; `settings.json` registers 7 events with 8 command entries (SessionEnd has 2). All three disagree.
- Memory topic files (`feedback_rtk.md`, `project_architecture.md`) violate the documented English-only rule for AI-consumed artifacts and still mention WSL/CHOP, both explicitly removed from this machine.
- Dangling references: `CLAUDE.md` L44 and `ARCHITECTURE.md` L248 mention a global `AGENTS.md` that doesn't exist; ARCHITECTURE.md L8 references `templates/order-match-checklist.md` (existence unverified — confirm before keeping).

**Scope (per user)**: documentation coherence only. No structural changes to hooks, no new skills, no FOMO-guard re-audit of the hook registry. Just make the rules say one thing, in English, accurately.

**Outcome**: an AI agent loading global + project context at session start gets a single, internally consistent instruction set with no environment-stale baggage.

---

## Critical files to edit

| # | File | Change |
|---|---|---|
| 1 | `C:\Users\nineonelabs003\.claude\CLAUDE.md` | Remove inline RTK block; tighten drive-policy wording; correct hook count |
| 2 | `C:\Users\nineonelabs003\.claude\ARCHITECTURE.md` | Scope "C drive only" to global infra; correct L94 forbidden phrasing; reconcile hook count L100/L196; verify or remove templates ref L8; remove dangling global-AGENTS.md mention L248 |
| 3 | `C:\Users\nineonelabs003\.claude\settings.json` | Broaden `Read(.credentials*)` to `Read(**/.credentials*)` |
| 4 | `C:\Users\nineonelabs003\.claude\projects\d------------------260427\memory\feedback_rtk.md` | Translate to English; delete WSL line; delete CHOP trivia |
| 5 | `C:\Users\nineonelabs003\.claude\projects\d------------------260427\memory\project_architecture.md` | Translate Korean rows / explanatory lines to English |

`RTK.md`, project `AGENTS.md`, project `CLAUDE.md`, project `.claude/settings.json` — **leave untouched**. They are already coherent (Phase 1 second-agent audit confirmed: 121 lines combined, English, RTK refs synchronized, drive boundary enforced via deny list).

---

## Detailed changes

### 1. `CLAUDE.md` (global)

- **Lines 73-205**: delete the entire `<!-- rtk-instructions v2 -->` block. Reason: identical to `RTK.md`, already imported via `@RTK.md` at L67. The block was injected by `rtk init --global` and creates a drift surface.
- **Line 20** — current: `"DON'T reference D:\.claude paths anywhere. All Claude data lives on C drive under the standard user profile location."`
  - Replace with: `"DON'T relocate the .claude config root to D: (e.g. D:\.claude\, D:\.claude-data\). Global Claude infra lives under %USERPROFILE%\.claude\ on whichever drive holds the user profile. Project work on D: is fine and expected — the prohibition is specifically against splitting the .claude infra across drives."`
  - Reason: distinguishes *Claude infra location* from *project work location*. Current phrasing reads as "no D-drive references in any artifact," which contradicts the project itself being on D:.
- **Lines 50-61**: in the "Active Global Hooks" section, replace the bulleted preamble that implies 7 events + `statusLine` + `env` with an explicit count: **"7 hook events (SessionStart, SessionEnd, PostToolUse, UserPromptSubmit, PreCompact, PostCompact, Stop) plus a `statusLine` renderer and one `env` setting."** Keep the bullets.

### 2. `ARCHITECTURE.md` (global)

- **Line 20** — current: `"Drive layout | C drive only for all Claude artifacts (no D / E split)"`
  - Replace with: `"Drive layout | C drive (under %USERPROFILE%) for the .claude config root. Project work lives on D:; only the Claude infra itself is single-drive."`
- **Line 94** — current: `"Forbidden: D:\.claude\, D:/.claude-data/, or any literal D-drive reference."`
  - Replace with: `"Forbidden: relocating the .claude config root to a non-profile drive (D:\.claude\, D:\.claude-data\). D-drive paths in project content are fine — the rule targets the infra root, not the project."`
- **Line 100** — current: `"Eight hook events are registered in settings.json."`
  - Replace with: `"Seven hook events are registered in settings.json (plus a statusLine renderer)."` — match the table directly below.
- **Line 196** — current row: `"9 hooks registered in settings.json"`
  - Replace count with: `"7 hook events (8 command entries — SessionEnd registers 2)"`. Keeps the trigger-justification column intact.
- **Line 8** — verify `templates/order-match-checklist.md` exists. If yes: keep. If no: delete the bullet. (Read-only check via `Glob`.)
- **Line 248** — the migration row references "AGENTS.md declared 'D: drive only for project work'" — clarify this means **project** AGENTS.md (`d:\최신프로젝트\나인원랩스\퍼블\260427\AGENTS.md`), not a global one. Add `(project AGENTS.md)` parenthetical so future readers don't hunt for a missing global file.
- **Line 44** of `CLAUDE.md` (cross-link) similarly references `AGENTS.md` in the "Standard layout" sentence — clarify it's the per-project file, not global.

### 3. `settings.json` (global)

- **Line 28** — current: `"Read(.credentials*)"` matches root-level only. Replace with `"Read(**/.credentials*)"` to cover nested credential files. Existing `Read(**/.env*)` and `Read(**/credentials.json)` already use the recursive form — this brings `.credentials*` in line.

### 4. `feedback_rtk.md` (project memory topic)

Full rewrite in English. New body:

```
RTK token-optimization policy: full reference at ~/.claude/RTK.md. Project-side filters: .rtk/filters.toml.

Why: noisy commands (git / tsc / docker / test runners / find / log files) compress 60–90% via rtk, freeing context budget.

How to apply:
- Native Windows: explicit `rtk <cmd>` prefix is mandatory (no auto-rewrite hook on this platform).
- File reads: always use the Read tool — never `cat / head / tail / rtk read` for source files.
- Verify adoption: `rtk gain` (counter at 0 means the prefix was missed).
```

Drop the "WSL Remote: PreToolUse hook이 자동 prefix" line (CLAUDE.md L17 explicitly bans WSL workflows on this machine — keeping a WSL fork in memory invites confusion).
Drop the "CHOP은 2026-04-25 완전 제거됨" history line — CHOP no longer exists anywhere, so the trivia has no future load-bearing role.

### 5. `project_architecture.md` (project memory topic)

Translate the Korean cells / sections to English so the file complies with the language convention (ARCHITECTURE.md L228, CLAUDE.md L9). Specifically:

- **Table at L20-26** (`| 파일 | 역할 |` and the five rows) — translate column header to `| File | Role |` and English-ify each role description (e.g. `resize debounce + visualViewport sync`).
- **L28-30 "bfcache 지원 패턴"** → `bfcache support pattern (settled 2026-04-24):` and English bullets.
- **L33-35 "Author/editor 모드 패턴"** → `Author/editor mode pattern:`.
- **L37-39 "SEO 인프라"** → `SEO infrastructure:`.

Preserve identifiers, file paths, and Korean quoted user phrases verbatim per the language rule.

---

## Verification

Read-only checks the user (or a follow-up session) can run after the edits land:

1. **Line-count sanity**: `rtk read C:\Users\nineonelabs003\.claude\CLAUDE.md` should be ~70 lines, not 205. Confirms the inline RTK block was removed and `@RTK.md` import is the sole source.
2. **Drive-policy literal check**: `rtk grep "any literal D-drive" C:\Users\nineonelabs003\.claude\` returns no hits. `rtk grep "C drive only" C:\Users\nineonelabs003\.claude\` returns the corrected, scope-limited phrasing.
3. **Hook-count audit**: open `ARCHITECTURE.md` and confirm L100 ("Seven") matches the row count of the table immediately below, and L196 row says "7 hook events (8 command entries)".
4. **Memory language sweep**: `rtk grep "[가-힣]" C:\Users\nineonelabs003\.claude\projects\d------------------260427\memory\feedback_rtk.md C:\Users\nineonelabs003\.claude\projects\d------------------260427\memory\project_architecture.md` should return only quoted user phrases (e.g., the `완료` token preserved per ARCHITECTURE.md L230) — no narrative Korean.
5. **WSL / CHOP residue**: `rtk grep -i "wsl\|chop" C:\Users\nineonelabs003\.claude\projects\d------------------260427\memory\` returns no matches.
6. **Permission glob**: `rtk grep "Read(.credentials" C:\Users\nineonelabs003\.claude\settings.json` shows the `**/` recursive form.
7. **Dangling templates ref**: confirm `C:\Users\nineonelabs003\.claude\templates\order-match-checklist.md` exists; if not, the ARCHITECTURE.md L8 bullet is gone.

Open one fresh Claude Code session after the edits and watch the SessionStart hook output for any `compact-warning.txt` or `memory-lint.txt` complaints — those would surface broken links or unreadable files introduced by the edits.

---

## Out of scope (intentionally)

- FOMO-guard re-audit of the 7 registered hooks (deferred; user chose documentation-only scope).
- `/audit-harness` SKILL.md creation (referenced in project AGENTS.md L57/L74 but not implemented). Deferred.
- Migration-history compression in ARCHITECTURE.md (all 9 rows dated 2026-04-28) — cosmetic, not a contradiction.
- Renaming the legacy `projects\d------------------260427\` folder. Looks D-drive-ish but harmless; renaming risks breaking `active-projects.json` pin and historical session links.
- `agents/` folder population — already conditional ("if any") in ARCHITECTURE.md L49.

# Documentation Restructure + WSL Setup Guide Plan

## Context

**Why this change**

The previous plan (`ai-imperative-pelican.md`) finished hardening the automation harness (hooks, RTK, MEMORY, English-only policy). What remains is the **documentation surface itself**:

1. **Stray Claude workspace**: `d:\최신프로젝트\.claude\` was created when Claude Code was once launched from the parent directory of the actual project. It accumulates `file-history/`, `paste-cache/`, plus a near-empty `CLAUDE.md`. The global `cleanup.ps1` does not rotate it because it lives outside `D:\.claude\projects\`.
2. **Doc role separation gap**: today's `D:\.claude\CLAUDE.md` mixes (a) auto-loaded policy that Claude reads every session and (b) reference-grade environment setup (RTK modes, hook list, permission caveats). The auto-loaded payload should be short; reference content should be readable both by humans (GitHub-style) and Claude on demand.
3. **WSL migration intent**: the user plans to move to WSL Remote so RTK auto-rewrite is enabled. A dedicated, durable guide is needed (separate from auto-loaded CLAUDE.md) before the actual migration.
4. **Project README missing**: the project root has `AGENTS.md` and `CLAUDE.md` (both for AI tools) but no `README.md` for human readers / GitHub.

**Intended outcome**: documentation cleanly split between (a) Claude auto-load (small, policy-heavy) and (b) human-facing reference (rich, optional-load). Stray `.claude/` removed. WSL setup captured as a runbook the user can execute when ready.

---

## Official Reference (Anthropic Best Practices)

| File | Auto-load by Claude? | Owner | Size guidance | git |
|---|---|---|---|---|
| `~/.claude/CLAUDE.md` (global) | Yes | User | <=200 lines / 25 KB | gitignored |
| `<project>/CLAUDE.md` | Yes | Team | <=200 lines / 25 KB | committed |
| `.claude.local.md` | Yes (overrides project) | Individual | small | gitignored |
| `.claude/rules/*.md` | Conditional via `paths:` frontmatter | Team | size-flexible | committed |
| `README.md` | **No** -- explicit request only | Anyone | size-flexible | committed |
| `AGENTS.md` | No (community convention) | Cross-AI team rules | size-flexible | committed; loaded via `@AGENTS.md` import |

Rule of thumb: **auto-loaded files (CLAUDE.md / .claude.local.md / matched rules) should be short policy indexes; deep reference goes into README.md / dedicated guides** so Claude reads only what's relevant per turn.

Sources:
- [code.claude.com/docs/en/configuration.md](https://code.claude.com/docs/en/configuration.md)
- [code.claude.com/docs/en/skills.md](https://code.claude.com/docs/en/skills.md)
- [code.claude.com/docs/en/subagents.md](https://code.claude.com/docs/en/subagents.md)

---

## Decisions (user-confirmed)

| Item | Decision |
|---|---|
| `d:\최신프로젝트\.claude\` | Recursively delete now (no backup) |
| WSL migration | Document-only this session; actual install/setup is user-driven |
| README scope | Both global (`D:\.claude\README.md`) and project (`<project>\README.md`) |
| Auto-load CLAUDE.md size | Trim to <100 lines; deep content moves to README / WSL-SETUP / RTK / AUTOMATION |
| Language | English (per `feedback_english_for_ai.md`) |

---

## Target Documentation Layout

```
D:\.claude\
|-- CLAUDE.md         # AUTO-LOADED. Short policy index. Points to README / WSL-SETUP / RTK / AUTOMATION.
|-- README.md         # NEW. Human-facing global guide (env overview, when-to-use, dir layout, troubleshooting).
|-- WSL-SETUP.md      # NEW. Step-by-step WSL Remote runbook (install -> VSCode -> Claude Code -> RTK init).
|-- RTK.md            # Existing. Token-optimized command reference (already English).
|-- AUTOMATION.md     # Existing. Hooks/automation architecture; AUTO marks auto-regenerated.
|-- hooks/            # PowerShell scripts (English)
|-- skills/, agents/, projects/, plans/, ...

d:\최신프로젝트\나인원랩스\퍼블\260427\
|-- README.md         # NEW. Human/GitHub-facing project intro (stack, dev start, dir layout, contribution).
|-- CLAUDE.md         # Existing. `@AGENTS.md` import + Claude-only deltas.
|-- AGENTS.md         # Existing. Cross-AI repo rules.
|-- .claude/
|   |-- BEST_PRACTICES.md, SETUP_CHECKLIST.md
|   |-- rules/{frontend,php,scss}.md
|   `-- skills/, agents/, settings.json
`-- (project source ...)
```

Boundary rule:
- **Auto-loaded files** (CLAUDE.md, AGENTS.md via @import, rules/* matched by paths) -- short, normative, "what to do".
- **Reference files** (README.md, WSL-SETUP.md, BEST_PRACTICES.md, AUTOMATION.md) -- rich, descriptive, "how / why / setup", read on demand.

---

## Implementation Steps

### Step 1. Remove the stray `.claude` directory

- Action: `Remove-Item -Recurse -Force "d:\최신프로젝트\.claude"`
- Note: contains historical paste-cache and file-history backups that the global cleanup hook does not rotate. User confirmed delete-without-backup.
- Optional defensive change: extend `cleanup.ps1` to log a warning when a `.claude/` is found at any drive-root subdirectory other than `D:\.claude\` (skip in this plan unless time permits).

### Step 2. New global README ([D:\.claude\README.md](D:/.claude/README.md))

Sections:
1. **What this directory is** -- "Claude Code global config root on Windows D: drive"
2. **Two operating modes**: Native Windows vs WSL Remote (table). Explicit recommendation: WSL Remote for RTK auto-rewrite.
3. **Quick links** -- pointers to `WSL-SETUP.md`, `RTK.md`, `AUTOMATION.md`, `CLAUDE.md`.
4. **Directory map** of `D:\.claude\` -- one-line description per top-level item.
5. **Active automation** -- summary of which hooks fire on which event (sourced from current AUTOMATION.md, restated for human readers).
6. **Known caveats** -- bypassPermissions mode, `permissions.deny` safety net, native-Windows hook limitation.
7. **Troubleshooting index** -- session-start latency, RTK not auto-rewriting, MEMORY drift, AUTOMATION marks not updating.
8. **License / contact** placeholder.

Target size: 150-250 lines. Human-readable; not auto-loaded.

### Step 3. New WSL setup runbook ([D:\.claude\WSL-SETUP.md](D:/.claude/WSL-SETUP.md))

Source: the 1300-word guide already produced by the claude-code-guide agent.

Sections:
1. WSL installation (`wsl --install`, distro choice, WSL 2 verification)
2. VS Code Remote-WSL (extension install, `Connect to WSL`, path strategy `/mnt/d/...` vs `~/projects/...`)
3. Node.js + Claude Code install (nvm, `npm install -g @anthropic-ai/claude-code`, OAuth)
4. RTK install + `rtk init -g --auto-patch`, verification (`rtk init --show`, `claude --debug hooks`)
5. D-drive access from WSL, performance tradeoffs, Korean filename handling (locale check)
6. Hybrid workflow recommendation (edit in VSCode-WSL, Claude session in WSL terminal, Docker via WSL backend)
7. Pitfalls + sync notes (Windows `D:\.claude\settings.json` vs WSL `~/.claude/settings.json` are independent)
8. Troubleshooting matrix

Target size: 250-400 lines.

### Step 4. Trim global CLAUDE.md ([D:\.claude\CLAUDE.md](D:/.claude/CLAUDE.md))

Current state: covers RTK summary, response style, auto-memory pattern, frequent skills, full active hooks list, RTK modes, permission caveats. ~50 lines but heavy in dense content.

After:
- Keep: response-style policy (Korean replies / English AI-content), auto-memory location pointer, RTK mandatory rule, `@RTK.md` import.
- Move out: full hook table -> README.md / AUTOMATION.md; RTK mode table -> RTK.md (already there); permission caveat -> README.md.
- Add: pointer block to README.md / WSL-SETUP.md / RTK.md / AUTOMATION.md.

Target size: <80 lines. Stays auto-load-friendly under prompt cache.

### Step 5. New project README ([d:\최신프로젝트\나인원랩스\퍼블\260427\README.md](d:/최신프로젝트/나인원랩스/퍼블/260427/README.md))

Sections:
1. **Project name / one-line description** -- NINEONELABS Renewal (2026-04-27 baseline)
2. **Stack** -- TypeScript, SCSS, Three.js, Vite, PHP 7.4 custom MVC, MySQL, Apache (Docker)
3. **Quick start** -- Docker compose up, dev server `http://localhost:8888`, dev workflow
4. **Directory layout** (top-level only): `resource/`, `routes/`, `views/`, `inc/`, `admin/`, `scripts/`, `.claude/`
5. **AI-tool integration pointer** -- "see `AGENTS.md` for cross-AI rules; `CLAUDE.md` and `.claude/` for Claude-specific config"
6. **Tests & verification** -- `npm run test`, `tsc --noEmit`, `php -l`
7. **Contribution / commit conventions** (short)
8. **Forbidden commands callout** -- `npm run build`, `npm run watch`, `npm install` (Vite handles auto-rebuild)

Target size: 100-180 lines.

### Step 6. Strengthen automatic doc indexing

[D:\.claude\hooks\update-docs.ps1](D:/.claude/hooks/update-docs.ps1) extension:
- Add new AUTO mark `DOCS` -- enumerates every `*.md` at `D:\.claude\` root with first-line description, modified date.
- Add `README.md` and `WSL-SETUP.md` to the `prefix-version.txt` watched list (already watches CLAUDE / RTK / AUTOMATION; add the two new files).

[D:\.claude\AUTOMATION.md](D:/.claude/AUTOMATION.md):
- Insert `<!-- AUTO:DOCS-START -->...<!-- AUTO:DOCS-END -->` section after Hook events.

This makes the documentation set self-cataloging: any new top-level doc auto-appears in `AUTOMATION.md`.

### Step 7. Verify token efficiency

- After trim, `D:\.claude\CLAUDE.md` byte size dropped (target: 30-50% reduction).
- Auto-load chain stays at: `CLAUDE.md` (~80 lines) + `RTK.md` (existing) = under prompt-cache prefix budget.
- README / WSL-SETUP / AUTOMATION read only on explicit request -> zero passive token cost.

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Stray `.claude` deletion loses unrecoverable work | User confirmed no backup; `file-history` is itself a redundancy layer that has rotated naturally for >30 days. |
| Trimming CLAUDE.md drops a critical inline rule | Move-not-delete: every removed sentence relocates to README/WSL-SETUP/RTK/AUTOMATION verbatim before the trim. |
| Project README duplicates AGENTS.md content | Project README addresses humans (stack, quick start, directory map). AGENTS.md addresses AI tools (rules, verification commands). Tone and audience differ -- duplication kept minimal. |
| `update-docs.ps1` regex extension breaks | Helper `Update-AutoSection` already handles new marks idempotently. New `DOCS` mark follows the same shape. Verify by running the script directly. |
| WSL guide diverges from upstream changes | `check-updates-worker.ps1` already monitors `setup.md`/`hooks.md`; if Anthropic changes WSL guidance, `review-needed.md` will queue the impacted lines. |

---

## Critical Files

### New (4)
- [D:\.claude\README.md](D:/.claude/README.md)
- [D:\.claude\WSL-SETUP.md](D:/.claude/WSL-SETUP.md)
- [d:\최신프로젝트\나인원랩스\퍼블\260427\README.md](d:/최신프로젝트/나인원랩스/퍼블/260427/README.md)
- (this plan file)

### Modified (3)
- [D:\.claude\CLAUDE.md](D:/.claude/CLAUDE.md) -- trimmed to <80 lines, points to README/WSL-SETUP/RTK/AUTOMATION
- [D:\.claude\hooks\update-docs.ps1](D:/.claude/hooks/update-docs.ps1) -- DOCS AUTO mark + extended watched list
- [D:\.claude\AUTOMATION.md](D:/.claude/AUTOMATION.md) -- DOCS section markers

### Deleted (1)
- `d:\최신프로젝트\.claude\` (entire directory tree)

### Frozen
- All hook scripts (already English, working)
- Project `CLAUDE.md`, `AGENTS.md`, `.claude/rules/*.md`, `BEST_PRACTICES.md` (already English; project README will reference them)

---

## Verification

### Per-file
- **Stray cleanup**: `Test-Path "d:\최신프로젝트\.claude"` -> False
- **README/WSL-SETUP rendered**: open in VSCode preview, confirm headings and link targets resolve
- **Trimmed CLAUDE.md**: line count < 100; every removed sentence is findable in README/WSL-SETUP/RTK/AUTOMATION via grep
- **Project README**: `Get-Item ...\README.md` exists and references `AGENTS.md` / `CLAUDE.md` correctly

### Automation
- **DOCS mark renders**: run `update-docs.ps1` -> AUTOMATION.md `<!-- AUTO:DOCS-START -->` block populated with README, WSL-SETUP, RTK, AUTOMATION, CLAUDE rows
- **prefix-version bumps**: touch `README.md` -> `prefix-version.txt` increments on next `update-docs.ps1` run
- **AGENTS / hook chain unaffected**: SessionStart still completes <100ms; cleanup still rotates as before

### Regression (frozen assets)
- 14-script SCRIPTS table unchanged in count
- 7 hook events still enumerated
- MEMORY 11 topic files intact, `memory-lint OK`
- `permissions.deny` 8 entries unchanged
- RTK PreToolUse rewrite (when in WSL) and project tsc PostToolUse fan-out unchanged

### Token efficiency check
- Compare `D:\.claude\CLAUDE.md` byte size before/after; target -30% to -50%
- Verify human-facing README is NOT auto-loaded by checking `claude --debug context` output (README.md should not appear in the context list unless explicitly read)

---

## Out of Scope (declared)

- Actual WSL installation, Ubuntu provisioning, RTK init -- user-driven post-plan.
- Migrating `~/.claude/` (WSL home) settings to mirror `D:\.claude\`. Will be handled in a follow-up plan after the user runs `rtk init -g --auto-patch` in WSL.
- Translating remaining MEMORY topic files (`project_*.md`, `feedback_*.md`) -- low ROI, user reads them, can be done lazily on next touch.
- AGENTS.md / project CLAUDE.md edits -- both already English and well-shaped.
- A "stray .claude" auto-detector in cleanup.ps1 (deferred; one-shot delete is sufficient for now).

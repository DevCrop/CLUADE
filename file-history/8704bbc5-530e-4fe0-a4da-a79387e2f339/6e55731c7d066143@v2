# Settings Portability & Security Hardening

## Context

Current Claude Code config (global + project) has three structural defects revealed by an Anthropic-docs-aligned review:

1. **Ineffective deny rules**: Global `~/.claude/settings.json` uses `Bash(rm -rf %USERPROFILE%/.claude:*)`. The `%USERPROFILE%` token is a `cmd.exe` variable — Bash/Git Bash treats it as a literal string, so the rule only matches if a user types the literal `%USERPROFILE%` text. Real-world destructive inputs (`rm -rf ~/.claude`, `rm -rf /c/Users/<user>/.claude`, `rm -rf C:/Users/<user>/.claude`) all bypass it.
2. **Username hardcoding (portability)**: `Bash(rm -rf C:/Users/nineonelabs003/.claude:*)` and old `edn_y` references break on any machine with a different Windows account. The same `~/.claude` install needs to function unchanged on any host.
3. **Drive policy unenforced**: `AGENTS.md` declares "D: drive only for project work" but `.claude/settings.json` has no deny rules to enforce it. Claude can still freely write to `C:\` from project context.
4. **PHP lint hook broken**: PostToolUse `.php` hook passes the Windows host path (e.g. `d:/최신프로젝트/.../routes/web.php`) to `docker compose exec -T web php -l`. The container has no such path — its mount is `./:/var/www/html`, so the call silently fails on every PHP edit.

Goal: a settings layout that (a) is portable across PCs without edits, (b) actually denies destructive inputs in every shell form Bash receives them, (c) enforces the documented drive boundary, (d) gives working PHP linting.

---

## Critical files

| File | Role | Change |
|---|---|---|
| `~/.claude/settings.json` (= `%USERPROFILE%\.claude\settings.json`) | Global permissions + hooks | Rewrite `permissions.deny` |
| `<project>/.claude/settings.json` | Project allowlist + PostToolUse hook | Add `permissions.deny` block; fix `.php` branch in PostToolUse hook |
| `<project>/docker-compose.yml`:7 | Mount source of truth (`./:/var/www/html`) | Read-only — cited by hook fix |

No new files. Plan modifies two JSON configs.

---

## Design — A. Global `~/.claude/settings.json` deny redesign

Replace the current 8-entry deny block with comprehensive pattern coverage. Rationale per Anthropic docs (`code.claude.com/docs/en/permissions`):

- Glob match is **string pattern** against the literal command Claude is about to run, not path-aware.
- Space-form `Bash(cmd *)` enforces word boundary; inline `Bash(cmd*)` does not.
- Colon-form `:*` works but is non-standard; align to space/inline form for consistency.

**Replacement deny array**:

```jsonc
"deny": [
  // Filesystem destruction — cover every shell form Bash on Windows can receive
  "Bash(rm -rf /*)",                     // POSIX root
  "Bash(rm -rf ~*)",                     // tilde home
  "Bash(rm -rf $HOME*)",                 // env home
  "Bash(rm -rf /c/*)",                   // Git Bash POSIX C-drive
  "Bash(rm -rf //c/*)",                  // Git Bash UNC-style
  "Bash(rm -rf C:/*)",                   // Windows forward-slash
  "Bash(rm -rf C:\\*)",                  // Windows backslash
  "Bash(rm -rf %USERPROFILE%*)",         // cmd-style literal (still possible if user types it)

  // Destructive git
  "Bash(git push --force *)",            // space-form: denies --force, allows --force-with-lease
  "Bash(git push --force)",              // bare form
  "Bash(git push -f *)",
  "Bash(git push -f)",
  "Bash(git reset --hard *)",
  "Bash(git reset --hard)",
  "Bash(git clean -f *)",
  "Bash(git clean -fd *)",
  "Bash(git clean -fdx *)",
  "Bash(git checkout -- *)",
  "Bash(git checkout .)",
  "Bash(git restore .)",
  "Bash(git restore --staged .)",

  // Credentials
  "Read(.credentials*)",
  "Read(**/.env*)",
  "Read(**/credentials.json)"
]
```

**Why not single-pattern shortcuts** like `Bash(rm -rf *)`: too broad — would block legitimate `rm -rf node_modules` on temporary build outputs. The seven path-prefix patterns above target only system/home/global-config destruction.

**Why `git push --force *` (space)**: denies `git push --force origin main` but keeps `git push --force-with-lease` available — the safer alternative shouldn't be collateral damage.

**Why no username**: every pattern uses wildcards or environment-agnostic prefixes. Drop-in portable to any Windows user account.

---

## Design — B. Project `.claude/settings.json` — add deny + fix PHP hook

### B-1. New `permissions.deny` block (Drive policy enforcement)

```jsonc
"deny": [
  "Bash(rm -rf C:/*)",
  "Bash(rm -rf C:\\*)",
  "Bash(rm -rf /c/*)",
  "Bash(rm -rf //c/*)",
  "Write(C:/**)",
  "Write(C:\\**)",
  "Write(/c/**)",
  "Write(//c/**)",
  "Edit(C:/**)",
  "Edit(C:\\**)",
  "Edit(/c/**)",
  "Edit(//c/**)"
]
```

Project-level deny **overrides** anything in user-level (per Anthropic precedence: Project shared > User). This is the layer that actually enforces "no C: writes from project context." Global Claude infra edits go through `update-config` skill or an explicit user-initiated session, never accidentally via project hooks.

Trade-off: blocks `Edit/Write` on `~/.claude/*` from inside project session. Intended — global edits should be conscious, not drive-by side effects.

### B-2. Fix PHP lint hook — host path → container path

Current hook passes `f` (e.g. `d:/.../routes/web.php`) directly. Container expects `/var/www/html/routes/web.php`. Fix:

```js
// inside the .php branch:
const root = process.cwd().replace(/\\/g, '/');
const rel = f.replace(/\\/g, '/').replace(root + '/', '');
const containerPath = '/var/www/html/' + rel;
execSync('rtk docker compose exec -T web php -l ' + q(containerPath), opts);
```

`/var/www/html` is the canonical mount from `docker-compose.yml`:7 (`- ./:/var/www/html`). Since `docker-compose.yml` is committed, this conversion is portable — different developers cloning to different host paths still resolve correctly because `process.cwd()` always equals the project root the container mounts.

The existing `try/catch` keeps the hook silent when the container is down — no behavior regression.

---

## Execution mechanism

| Change | Mechanism | Reason |
|---|---|---|
| A (global deny) | `update-config` skill | Global `settings.json` edits trigger Claude's self-modification block. The `update-config` skill is the documented official path. |
| B-1 (project deny) | Direct `Edit` tool | Project file, no self-modification block. |
| B-2 (PHP hook) | Direct `Edit` tool | Same. |

Order: B first (no permission gates), then A (requires skill).

---

## Verification

### After A (global deny)
1. Start a fresh Claude session (settings reload).
2. Issue: `rtk git push --force origin main` — must be **denied**.
3. Issue: `rtk git push --force-with-lease origin main` — must be **allowed** (if approved separately).
4. Issue: `rtk rm -rf ~/test` — must be **denied**.
5. Read `~/.credentials.json` — must be **denied**.

### After B-1 (project deny)
1. Ask Claude: "edit `~/.claude/settings.json`" — must be **denied** (project context).
2. Ask Claude: "edit `routes/web.php`" — must be **allowed** (D:, project root).

### After B-2 (PHP hook)
1. Confirm container running: `rtk docker compose ps`.
2. Edit any `.php` file via Claude (small whitespace change).
3. Hook should run and either succeed silently or print a parse error from inside the container.
4. Manual cross-check: `rtk docker compose exec -T web php -l /var/www/html/routes/web.php` should match the hook's output.
5. Stop the container; edit `.php` again — hook should fail silently (current `try/catch` behavior, no regression).

---

## Out of scope (deferred)

- Refactoring the inline `node -e` PostToolUse command into a separate file. Vanilla-compliance preference; revisit only if the inline string grows further or breaks debuggability.
- Adding a `settings.local.json`-level allowlist for the rare case a developer needs to edit `~/.claude/` from within the project session — handle case-by-case via `/permissions` runtime grant instead of persistent allow.
- Aligning the AGENTS.md/CLAUDE.md textual references to the new deny shapes — already portable after the prior `%USERPROFILE%` migration; deny rule shapes are a JSON-only concern.

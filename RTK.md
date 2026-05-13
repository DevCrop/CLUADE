# RTK — Rust Token Killer (Operations Guide)

**Purpose**: Token-optimized CLI proxy. 60–90 % output reduction on noisy dev commands. Always-loaded — this file holds the behavioral rules and troubleshooting; the full command catalog lives in the `/rtk-reference` skill (loaded on demand).

---

## 1. Golden Rule

**Prefix every noisy Bash call with `rtk`.** Cheap reads (`pwd`, `whoami`, single-line `echo`) are exempt; everything that prints multiline output goes through `rtk`.

The Claude Code PreToolUse hook (`rtk hook claude`) auto-rewrites Bash calls on Windows native, so manual prefixing is **idempotent and safe** — never harmful. When in doubt, prefix.

```bash
# Right
rtk git status
rtk git add . && rtk git commit -m "msg" && rtk git push
rtk docker compose logs -f web

# Wrong — auto-rewrite still helps, but prefixing is the documented contract
git status && git push
```

---

## 2. Health Check (run after install or RTK upgrade)

```bash
rtk --version          # rtk 0.X.Y — must NOT be "command not found"
rtk gain               # must render the savings panel (proves binary works)
which rtk              # confirm the correct binary on PATH
rtk init --show        # confirm hooks/config are registered as expected
```

⚠️ **Name collision**: another crate `reachingforthejack/rtk` (Rust Type Kit) shares the binary name. If `rtk gain` errors with anything other than empty stats, you have the wrong RTK installed. Uninstall and reinstall from <https://github.com/rtk-ai/rtk>.

---

## 3. Operating Modes

| Mode | When it fires | How to invoke |
|---|---|---|
| **Auto-rewrite** | PreToolUse hook intercepts Claude's Bash call | nothing — Claude calls `git status`, the hook rewrites to `rtk git status` |
| **Manual prefix** | You type the command yourself | `rtk <cmd>` — idempotent with auto-rewrite |
| **Raw passthrough** | You need un-filtered output (debugging RTK itself, capturing exact bytes) | `rtk proxy <cmd>` |
| **Preview** | Curiosity — see how RTK *would* rewrite a command without running it | `rtk rewrite <cmd>` |

Auto-rewrite only triggers from Claude Code's Bash tool, not from PowerShell sessions. In PowerShell you must prefix manually.

---

## 4. Meta Commands (always invoked directly — never hook-rewritten)

```bash
rtk gain                 # cumulative token-savings dashboard
rtk gain --history       # recent commands with per-call savings
rtk gain --daily         # day-by-day breakdown
rtk discover             # missed-savings opportunities (Windows: use /rtk-discover)
rtk session              # adoption stats across past sessions
rtk proxy <cmd>          # raw command — bypass all filtering
rtk rewrite <cmd>        # preview the rewrite without executing
rtk init --show          # print current hook/config status
rtk trust                # re-trust project-level .rtk/filters.toml
rtk --help               # full CLI surface
```

---

## 5. Hot-Path Cheat Sheet (memorize these — 80 % of daily savings)

| Operation | Form | Typical savings |
|---|---|---|
| Git status / log / diff | `rtk git status` / `log` / `diff` | 75–80 % |
| Git add / commit / push | `rtk git add .` / `commit -m` / `push` | 90 %+ |
| Type-check | `rtk tsc --noEmit` | 83 % |
| Test run (failures only) | `rtk vitest run` / `rtk cargo test` | 90–99 % |
| Build | `rtk next build` / `rtk cargo build` | 85 % |
| Lint | `rtk lint` / `rtk cargo clippy` | 80 % |
| Docker logs | `rtk docker compose logs <svc>` | 85 % |
| File / search | `rtk ls`, `rtk grep <pat>`, `rtk find` | 65–80 % |

Full per-tool table and category breakdown → `/rtk-reference`.

---

## 6. Project Filters (`.rtk/filters.toml`)

Projects can add extra filters under `.rtk/filters.toml`. They apply **only when commands are invoked via `rtk`** — raw commands skip them.

```bash
# First time using a project, or after editing the filters file:
rtk trust                # shows filters + sha256 — confirms no high-risk patterns
```

After `rtk trust`, the warning `[rtk] WARNING: untrusted project filters (.rtk/filters.toml)` disappears. The sha256 hash is locked; changing the filter contents will require re-trusting.

A typical project filter looks like:

```toml
[filters.docker-compose-logs]
description = "Keep only web/db lines and error keywords"
match_command = "^docker compose logs\\b"
strip_ansi = true
keep_lines_matching = ["^(web|db)\\s+\\|", "error|warn|fatal|notice"]
max_lines = 120
```

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `rtk: command not found` | Not installed or PATH missing `~/.cargo/bin` | `cargo install rtk` then check `$env:PATH -split ';' | findstr cargo` |
| `rtk gain` errors with type-kit help text | Wrong RTK on PATH (Rust Type Kit collision) | Uninstall the other; reinstall `rtk-ai/rtk` |
| `[rtk] WARNING: untrusted project filters` every call | `.rtk/filters.toml` not trusted yet | `rtk trust` (interactive, one-time per filter sha256) |
| `[rtk] /!\ No hook installed — run 'rtk init -g'` | Global git hook absent | Functionally a no-op when Claude Code's PreToolUse hook is registered. Run `rtk init -g` if you also want the global git hook (idempotent with the Claude hook). |
| `rtk discover` returns 0 sessions on Windows | Issue [rtk-ai/rtk#1743](https://github.com/rtk-ai/rtk/issues/1743) — CWD mangling | Use `/rtk-discover` skill (passes `-p <leaf>` workaround) |
| Output looks corrupt / wrong filter applied | Filter regex misfire | `rtk proxy <cmd>` to compare raw vs filtered; report or adjust `.rtk/filters.toml` |
| Korean text shows `???` | Console codepage is CP949 | `chcp 65001` in current shell; for permanent fix see `README.md` §2-1 |

---

## 8. When to Skip RTK

There are exactly three cases where you should NOT use `rtk`:

1. **Trivial single-line output** (`pwd`, `whoami`, `echo foo`, `node --version`). The hook skips these automatically.
2. **Capturing exact bytes** (e.g. piping to a hash, redirecting into a binary). Use `rtk proxy <cmd>` so RTK records the call without filtering.
3. **The command IS rtk** — `rtk gain`, `rtk discover`, `rtk trust`, `rtk proxy`, etc. (the hook detects these and doesn't recurse.)

Everything else: prefix.

---

## 9. Verification Loop

```bash
rtk gain               # weekly — is savings ratio >50 % on heavy days?
rtk gain --history     # which commands missed the prefix? self-correct
rtk discover           # (Windows: /rtk-discover) — find untouched savings
```

The `Stop` hook (`hooks/token-report.ps1`) appends per-session stats to `reports/token-usage.md` automatically; review monthly.

---

## 10. References

- `/rtk-reference` skill — full command catalog, per-tool savings table, category-grouped list
- `/rtk-discover` skill — Windows-native `rtk discover` CWD workaround
- `ARCHITECTURE.md` §7 — how RTK is wired into the global Claude Code setup
- Upstream: <https://github.com/rtk-ai/rtk>

# RTK — Token-Optimized Commands (Windows Native)

## Tool Selection Matrix

| Need | Domain | Tool |
|---|---|---|
| Read source / config file | Context Domain | Read tool |
| Read large log / build output | Token Domain | `rtk read <file>` or `rtk log` |
| All shell commands | Token Domain | `rtk <cmd>` (auto-applied by hook) |

Token-optimized CLI proxy: **60–90% savings** on noisy dev operations. RTK passes unknown commands through unchanged — prefixing is always safe.

## Golden Rule

The PreToolUse hook (`~/.claude/hooks/rtk-prerewrite.js`) auto-prefixes every Bash call with `rtk` — type commands normally and the hook handles noisy-output protection. Manual prefixing remains safe (already-prefixed input is detected).

```bash
git add . && git commit -m "msg" && git push   # auto-rewritten to rtk-prefixed segments
RTK_DISABLED=1 docker logs api                  # per-command bypass when raw output is needed
```

## Auto-Prefixed Commands (hook handles these)

The PreToolUse hook auto-rewrites these commands. Listed for reference — manual prefixing is unnecessary but harmless:

| Command | Prefix form |
|---|---|
| `ls`, `ls -la`, `ls -1` | `rtk ls <path>` |
| `find` | `rtk find "*.ext" <path>` |
| `grep` / `rg` | `rtk grep <pattern> <path>` |
| `git status` | `rtk git status` |
| `git log` | `rtk git log` |
| `git diff` | `rtk git diff` |
| `git add` / `commit` / `push` | `rtk git add / commit / push` |
| `npm run` / `pnpm` | `rtk npm run <script>` |
| `tsc` | `rtk tsc` |
| `docker ps` / `docker logs` | `rtk docker ps / logs` |
| `curl` (any) | `rtk curl <url>` |

**Never use plain `cat` in Bash** — use the Read tool for source files.
**Never use plain `ls` in Bash** — always `rtk ls`.

## DO

- DO prefix `git`, `docker`, `tsc`, test runners, `find`, log files, `gh pr`, package managers.
- DO chain `rtk` across `&&` / `;` boundaries — each command is filtered independently.
- DO use `rtk gain` periodically to confirm savings adoption.

## DON'T

- DON'T re-run `rtk init -g --auto-patch` or set up WSL — auto-rewrite is already wired via the PreToolUse hook on this Windows-native machine.
- DON'T prefix one-line commands (`echo`, `pwd`, single-file `cat`) — RTK adds no value there.
- DON'T expect RTK to reformat `Get-*` PowerShell — RTK targets standard CLIs, not pwsh cmdlets.

## Token Savings (30-min Claude Code Session)

| Operation | Frequency | Standard | rtk | Savings |
|---|---|---|---|---|
| `ls / tree` | 10x | 2,000 | 400 | -80% |
| `cat / read` | 20x | 40,000 | 12,000 | -70% |
| `grep / rg` | 8x | 16,000 | 3,200 | -80% |
| `git status` | 10x | 3,000 | 600 | -80% |
| `git diff` | 5x | 10,000 | 2,500 | -75% |
| `git log` | 5x | 2,500 | 500 | -80% |
| `git add/commit/push` | 8x | 1,600 | 120 | -92% |
| `cargo test / npm test` | 5x | 25,000 | 2,500 | -90% |
| `ruff check` | 3x | 3,000 | 600 | -80% |
| `pytest` | 4x | 8,000 | 800 | -90% |
| `go test` | 3x | 6,000 | 600 | -90% |
| `docker ps` | 3x | 900 | 180 | -80% |

## Commands by Category

```bash
# Git
rtk git status / log / diff / show / add / commit / push / pull / branch / fetch / stash

# GitHub CLI
rtk gh pr list / view / create / checks
rtk gh issue list / view
rtk gh run list

# Build & Type Check
rtk tsc                  # TypeScript errors only, grouped by file
rtk lint                 # ESLint grouped by rule/file
rtk next build           # Next.js build compact
rtk cargo build / check / clippy

# Tests
rtk test <cmd>           # generic — failures only
rtk vitest / jest / pytest / cargo test / go test / rspec / rubocop

# Files & Search
rtk ls <path>            # token-optimized tree
rtk read <file>          # smart file read
rtk grep <pattern> <path>
rtk find "*.ext" <path>

# Infrastructure
rtk docker ps / images / logs / compose ps / compose logs
rtk kubectl pods / logs / services

# Data & Errors
rtk json <file>          # structure without values
rtk err <cmd>            # filter errors only from any command
rtk log <file>           # deduplicated log
rtk env -f <prefix>
rtk curl <url>           # truncate + save full output

# Package Managers
rtk npm run <script>
rtk pnpm list / outdated / install
rtk pip install
```

## Meta (always invoked directly, never rewritten)

```bash
rtk gain                 # token savings stats
rtk gain --history       # recent commands
rtk gain --daily         # day-by-day breakdown
rtk discover             # find missed savings opportunities
rtk session              # RTK adoption across sessions
rtk proxy <cmd>          # raw command without filtering (debugging)
rtk rewrite <cmd>        # preview how a command would be rewritten
rtk init --show          # verify configuration status
```

## Hook Status (this machine)

```
[ok] PreToolUse: ACTIVE — hooks/rtk-prerewrite.js auto-rewrites every Bash call
[ok] Bypass: RTK_DISABLED=1 <cmd> per-command escape hatch
[ok] Project filters: .rtk/filters.toml (Token Domain output shaping)
```

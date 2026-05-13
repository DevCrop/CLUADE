---
name: rtk-reference
description: Detailed RTK command catalog, token-savings table, and category-grouped command list. Use when the user asks about specific RTK commands, savings estimates, or which RTK form to use for a particular CLI tool. Not loaded by default — invoke explicitly via /rtk-reference.
---

# RTK Reference

Reference material extracted from `~/.claude/RTK.md` per Claude Code Best Practices
(BP "각 줄 제거 테스트" — only behavior-affecting rules belong in always-loaded
context; catalogs and statistics load on demand).

The behavioral rules (Golden Rule, DO/DON'T, Health Check, Hook Status)
remain in `RTK.md` and load every session.

---

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

---

## Auto-Prefixed Commands (hook handles these)

The PreToolUse hook auto-rewrites these commands. Listed for reference —
manual prefixing is unnecessary but harmless.

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

---

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

---

## Meta Commands (invoked directly, never rewritten)

```bash
rtk gain                 # token savings stats
rtk gain --history       # recent commands
rtk gain --daily         # day-by-day breakdown
rtk discover             # missed-savings opportunities (Windows: see rtk-discover skill)
rtk session              # adoption across sessions
rtk proxy <cmd>          # raw command without filtering (debugging)
rtk rewrite <cmd>        # preview rewriting
rtk init --show          # verify configuration status
rtk trust                # re-trust project-level filters.toml after binary upgrade
```

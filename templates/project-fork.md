# Project Fork Guide (A → B)

Use when creating a new project by adapting an existing codebase.
For scratch setup, see `project-init.md`.

---

## 1. When to Use This Guide

Use fork workflow when **>50% of the source codebase** is being reused.
If reuse is <20% (shared structure only, no shared logic): prefer scratch setup (`project-init.md`).

---

## 2. Pre-Fork: Identity Token Inventory

Before copying, record these values from the **source** project:

| Token type | Where to find it | Example |
|---|---|---|
| Project slug | docker-compose.yml container names | `myproject` |
| DB name | docker-compose.yml, config/setup.php or equivalent | `myproject` |
| Docker service names | docker-compose.yml (all `container_name:`) | `myproject`, `myproject-db` |
| Port numbers | docker-compose.yml (`ports:`) | `8888:80`, `8282:80` |
| Domain(s) | views/sitemap.php, admin SEO config | `myproject.com` |
| Contact email | admin/application config | `admin@myproject.com` |
| Composer namespace | composer.json `"name"` | `vendor/myproject` |
| Env var prefix | .env.example | `PROJECT_*` |

Save this table in the session — you'll use it for find-and-replace in §4.

---

## 3. Fork Execution

```powershell
# 1. Copy source to new path
Copy-Item -Recurse -Path "d:\project\<source>" -Destination "d:\project\<target>"

# 2. Reset git — choose one:

#    Option A: fresh repo (no shared history)
Remove-Item -Recurse -Force "d:\project\<target>\.git"
git -C "d:\project\<target>" init
git -C "d:\project\<target>" add .
git -C "d:\project\<target>" commit -m "init: fork from <source>"

#    Option B: new branch on same remote (keeps shared history)
git -C "d:\project\<target>" checkout -b <new-branch>

# 3. Set remote
git -C "d:\project\<target>" remote set-url origin <new-remote-url>
# or if no remote yet: git -C ... remote add origin <new-remote-url>
```

---

## 4. Identity Token Replacement

For each token pair (old → new), run a targeted find-and-replace.
Work **file-by-file** — do NOT use a blanket regex across the whole repo (false positives in `vendor/`, `node_modules/`).

**Canonical files to update (generic pattern):**

| File category | File pattern | What to replace |
|---|---|---|
| Container orchestration | `docker-compose.yml`, `dockerfile` | container names, DB name, passwords, ports |
| Runtime config | `config/project.php` or equivalent | project name, domain, email, site key |
| DB config | `config/setup.php`, `.env` | DB name fallback, connection strings |
| Package manifest | `composer.json`, `package.json` | vendor namespace, project name |
| Template / SEO | `views/sitemap.php`, admin SEO config | hardcoded domain in structured data |
| Admin config | admin contact / application settings | hardcoded email, JSON-LD domain |
| Env file | `.env`, `.env.example` | all project-specific values |

After replacement, verify no old slug remains:

```powershell
Select-String -Pattern "<old-slug>" -Path "d:\project\<target>" -Recurse `
  -Exclude "*.lock","vendor\*","node_modules\*",".git\*"
# Expected: zero matches
```

---

## 5. AI Harness Reset (CRITICAL)

**Rule: author fresh, never carry over blindly.**

| Harness file | Action | Reason |
|---|---|---|
| `CLAUDE.md` | **Author fresh** from `project-init.md §2` | Carries source project's path, scope notes, skill refs — all stale |
| `AGENTS.md` | **Author fresh** from `project-init.md` | Same — stale identity, wrong paths |
| `.claude/settings.json` | **Copy + review** | Hooks (tsc, lint, RTK) are usually portable; verify matchers still match |
| `.claude/rules/*.md` | **Copy + verify each** | Stack-specific rules transfer; project-path refs inside them do not |
| `.claude/agents/*.md` | **Copy + update** | Update domain-expert descriptions to match new codebase modules |
| `.claude/skills/` | **Copy + review** | Skills referencing source-project route names need updating |
| `memory/` | **Create fresh — do NOT copy** | Memory carries source project's decisions; stale decisions corrupt new project |

Memory initialization: see `project-init.md §7`.

Verify harness is clean:

```powershell
Select-String -Pattern "<old-slug>|<old-path>" `
  -Path "d:\project\<target>\CLAUDE.md",
        "d:\project\<target>\AGENTS.md",
        "d:\project\<target>\.claude\rules\*",
        "d:\project\<target>\.claude\agents\*"
# Expected: zero matches
```

---

## 6. Global Wiring

### Register in active-projects.json

Append new slug to `pinned` in `~/.claude/active-projects.json`.
To find the new project's Claude slug: `ls ~/.claude/projects/` after the first session opens.

### Codex CLI trust

```bash
codex trust "d:\project\<target>"
```

Verify: `~/.codex/config.toml` gains `[projects.'d:\project\<target>'] trust_level = "trusted"`.

---

## 7. Verification Checklist

Adapts `HARNESS_ARCHITECTURE.md §7` (the canonical per-project bootstrap checklist):

- [ ] `CLAUDE.md` + `AGENTS.md` combined ≤ 200 lines?
- [ ] No old-project slug / old-project path in any harness file? (§5 verify command)
- [ ] No old-project slug in docker-compose.yml, config/, views/? (§4 verify command)
- [ ] `.claude/rules/` files have `paths:` frontmatter?
- [ ] `.claude/agents/` descriptions match **new** codebase modules?
- [ ] `.claude/settings.json` PostToolUse hooks wired (tsc / lint)?
- [ ] `active-projects.json` registers the new project?
- [ ] `memory/MEMORY.md` initialized fresh (not forked)?
- [ ] Docker builds cleanly under new service names?
- [ ] DB migrates cleanly under new DB name?
- [ ] `rtk tsc --noEmit` passes?

# New Project AI Harness Setup Guide

Based on Claude Code official docs. Read this when starting a new project and follow the steps to wire it up.

---

## 1. Folder structure

```
<project>/
├── AGENTS.md                    # cross-AI rules (brand / stack / RTK / verification / forbidden cmds)
├── CLAUDE.md                    # @AGENTS.md + Claude-only delta
└── .claude/
    ├── BEST_PRACTICES.md        # domain-invariant architecture rules
    ├── SETUP_CHECKLIST.md       # harness-setup verification checklist
    ├── settings.json            # project hooks (tsc, etc.)
    ├── rules/                   # Interface Segregation (paths: frontmatter)
    │   ├── frontend.md          # paths: **/*.ts, **/*.tsx
    │   ├── backend.md           # paths: **/*.py / **/*.go / **/*.php
    │   └── style.md             # paths: **/*.scss / **/*.css
    └── agents/                  # official agent definition files
        ├── <domain>-explorer.md # per-domain read-only Explore agent
        └── ...
```

---

## 2. Minimum CLAUDE.md (project root)

```markdown
@AGENTS.md

## Claude-Only Notes

<!-- Claude-specific deltas only. All shared rules live in AGENTS.md above. -->
```

Official guidance: keep CLAUDE.md under 200 lines. Beyond that, split into `.claude/rules/`.

---

## 3. Agent file format (`.claude/agents/`)

Agent files use YAML frontmatter + system-prompt Markdown body. Manageable via the `/agents` command.

```markdown
---
name: scene-explorer
description: >
  Use when exploring Three.js scene structure, objects, shaders,
  theatre bindings, or runtime relationships. Use for tasks involving
  Engine, Scene, AppManager, WorksSceneManager, Theatre bindings.
  Do NOT use for PHP, SCSS, or unrelated backend code.
tools: Read, Grep, Glob
model: haiku
disallowedTools: Write, Edit, Bash
---

You are a read-only Three.js architecture explorer.
Focus on: scene graph ownership, lifecycle methods, disposal patterns,
Theatre bindings, and runtime coordination.
Always report file paths and line numbers for every finding.
```

```markdown
---
name: php-explorer
description: >
  Use when exploring PHP routing, views, admin structure, or database schema.
  Use for tasks involving routes/web.php, Controller, Model, render() chain,
  nb_ tables, or admin pages. Do NOT use for TypeScript or SCSS.
tools: Read, Grep, Glob
model: haiku
disallowedTools: Write, Edit, Bash
---

You are a read-only PHP MVC architecture explorer.
Focus on: routing chains, render() entry points, controller/model patterns,
DB schema (nb_ prefix), and admin page structure.
Always report file paths and line numbers.
```

### Global agents (`~/.claude/agents/`)

Project-agnostic agents go here — auto-available across every project.

```markdown
---
name: code-reviewer
description: >
  Use proactively after significant code changes. Reviews for quality,
  security, and best practices. Does not modify files.
tools: Read, Grep, Glob
model: sonnet
disallowedTools: Write, Edit, Bash
---

You are a senior code reviewer. Analyze code for:
1. Security vulnerabilities (OWASP Top 10)
2. Performance anti-patterns
3. Code quality and maintainability
4. Missing error handling at system boundaries
Report findings with file paths and line numbers.
```

---

## 4. rules/ file format

```markdown
---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# Frontend Rules

- Bundler: Vite / Language: TypeScript (ES6+)
- Do NOT run npm run build / watch / install
  (Vite dev server auto-rebuilds on save)
```

---

## 5. settings.json (project `.claude/`)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "rtk tsc --noEmit 2>&1 | node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>process.stdout.write(JSON.stringify({systemMessage:d.trim()})+'\n'))\""
          }
        ]
      }
    ]
  }
}
```

---

## 6. Global wiring (do once per new project)

### Register in active-projects.json

Append to the `pinned` array in `~/.claude/active-projects.json`:

```json
{
  "pinned": [
    "c--Users-edn-y-renew-nineonelabs",
    "c--Users-edn-y-<new-project-name>"
  ]
}
```

To find the project folder name: `ls ~/.claude/projects/` — use the directory name Claude Code auto-generated.

---

## 7. MEMORY.md initialization (strict 200-line cap)

`~/.claude/projects/<folder>/memory/MEMORY.md`:

```markdown
# Memory Index — <PROJECT NAME>

- [Project Architecture](project_architecture.md) — stack / routing / core patterns
- [Development Workflow](project_workflow.md) — rtk commands / forbidden commands / agent delegation
- [Session Workflow](feedback_session_workflow.md) — /clear / explorer / parallel rules
```

Official spec: only the first 200 lines or 25 KB load at session start. Push detailed content into separate topic files.

---

## 8. SETUP_CHECKLIST.md items (completion criteria)

```
## Setup Checklist

- [ ] CLAUDE.md under 200 lines?
- [ ] rules/ files have paths: frontmatter?
- [ ] .claude/agents/ has domain explorers defined?
- [ ] settings.json PostToolUse hooks (tsc / lint) wired?
- [ ] active-projects.json registers this project?
- [ ] memory/ directory + MEMORY.md initialized?
- [ ] AGENTS.md lists forbidden commands?
- [ ] BEST_PRACTICES.md captures domain rules?
```

---

## 9. Multi-agent context handoff protocol

Required fields in every subagent prompt:

1. **Goal** — what to find (a concrete question).
2. **File paths** — where to look (cite known paths).
3. **Context** — why this work matters (1–2 sentences of background).
4. **Response format** — what shape the report should take.

Forbidden:

- Pasting the full chat history.
- Open-ended delegation like "go figure it out".
- "Modify based on findings" — comprehension stays with the main Claude; subagents only execute lookups.

Subagent selection rubric:

| Task type | Agent choice |
|---|---|
| Read-only exploration (need findings) | Explore or a custom domain-explorer |
| Design (plan, needs approval) | Plan agent (plan mode) |
| Simple implementation (1–2 files) | inline (no agent needed) |
| Complex implementation (multi-file) | general-purpose agent |
| Code review | code-reviewer (global agent) |

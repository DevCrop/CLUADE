# Claude Code Harness Architecture (Anthropic-Native Pattern)

This document defines the **architecture pattern** used to organize rules, hooks, memory, and skills across every project on this machine. It is project-agnostic — any new project should read this before adding harness configuration.

Companion docs:
- `ARCHITECTURE.md` — this-machine operations (directory layout, retention, hooks installed)
- `CLAUDE.md` — global operating rules (DO / DON'T)
- `RTK.md` — token-optimized CLI proxy reference
- `AUTOMATION.md` — auto-generated hook registration table

---

## 1. Why This Pattern (Decision Record)

The harness layer adopts **Anthropic-native** patterns: Progressive Disclosure (skill loading), Hook Event Model (deterministic enforcement), and the Plan-Verify Loop (verification cadence). DDD and SOLID-as-primary-architecture were considered and rejected — DDD has no precedent in any official agent framework; SOLID applies to handler code, not to JSON/Markdown configuration where settings precedence drives layering.

Authoritative sources: `anthropic.com/research/building-effective-agents`, `docs.anthropic.com/en/docs/claude-code/{hooks,memory,best-practices,skills,settings}`, `anthropic.com/engineering/effective-harnesses-for-long-running-agents`.

This decision is final. If a future project tries to reintroduce DDD framing, point at this section.

---

## 2. The Pattern (3 Layers + Verification Loop)

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1 — ALWAYS-LOADED CONTEXT                                │
│                                                                 │
│  CLAUDE.md / AGENTS.md   ≤200 lines combined target             │
│  MEMORY.md (auto-memory) index, ≤25 KB                          │
│                                                                 │
│  Rule: only what EVERY session needs                            │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│  LAYER 2 — PATH-SCOPED / ON-DEMAND                              │
│                                                                 │
│  .claude/rules/<topic>.md      loaded when files match `paths:` │
│  memory/<topic>.md             loaded by MEMORY.md link click   │
│  .claude/skills/<skill>/SKILL.md   invoked, never auto-loaded   │
│  .claude/agents/<agent>.md     invoked via Agent tool           │
│                                                                 │
│  Rule: domain-specific knowledge that costs context             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│  LAYER 3 — HOOK-ENFORCED DETERMINISM                            │
│                                                                 │
│  PreToolUse[Bash]  rewrite tool input   (e.g. rtk-prerewrite)   │
│  PostToolUse       file-type checks     (tsc / vitest / lint)   │
│  PreCompact/Post   memory snapshot integrity                    │
│  SessionStart/End  retention + drift drain                      │
│  Stop              token-report append                          │
│  permissions.deny  structural blocks (rm -rf, force push, etc.) │
│                                                                 │
│  Rule: any policy that must hold "zero exceptions"              │
└──────────────────────────┬──────────────────────────────────────┘
                           │ executes
                  [ COMMAND EXECUTION ]
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│  VERIFICATION LOOP                                              │
│                                                                 │
│  rtk gain          quantitative coverage (was RTK applied?)     │
│  rtk discover      qualitative gaps (which commands missed?)    │
│  .drift-queue/     edit drift signals                           │
│  reports/*.md      append-only audit trail                      │
│                                                                 │
│  Feedback rule: if gap detected, fix Layer 3, NOT Layer 1 docs  │
└─────────────────────────────────────────────────────────────────┘
```

**Anthropic naming** (use these terms, not "domain"/"aggregate"):
- "Progressive Disclosure" — the layered loading mechanism for skills
- "Hook Event Model" — Layer 3
- "Plan-Verify Loop" / "Verification" — the loop above
- "Augmented LLM" / "Orchestrator-Workers" — when planning multi-agent flows
- "Precedence Hierarchy" — settings cascade (Managed > Project > User > Local)

---

## 3. What Goes Where (Decision Matrix)

When adding ANY new piece of configuration, ask:

| Question | If yes → place in | Example |
|---|---|---|
| Does every session need this loaded into context? | Layer 1 (CLAUDE.md/AGENTS.md) | "Reply in Korean", "Don't run npm build" |
| Does it apply only to specific file types or paths? | Layer 2 (`.claude/rules/<topic>.md` with `paths:` frontmatter) | TypeScript-only rules, SCSS-only rules |
| Is it persistent learning across sessions for this project? | Layer 2 (`memory/<topic>.md` linked from MEMORY.md) | "User prefers terse responses", project architecture map |
| Is it a multi-step procedure that the user invokes? | Layer 2 (`.claude/skills/<skill>/SKILL.md`) | `/new-route`, `/audit-harness` |
| Must it hold every time, no exceptions, even mid-task? | Layer 3 (hook in `settings.json`) | RTK auto-prefix, file-type lint |
| Is it a structural prohibition (data destruction, credential exfil)? | Layer 3 (`permissions.deny`) | `rm -rf`, force push, `.credentials*` reads |

**If you can't answer — don't add it.** That's the FOMO gate (see §5).

---

## 4. Extension Recipes

### 4.1 Add a Layer 1 rule (advisory, every session)

1. Open project `AGENTS.md` (cross-AI) or `CLAUDE.md` (Claude-specific delta).
2. Add the rule under the correct heading. Keep wording terse.
3. **Verify**: `rtk grep -c "" CLAUDE.md AGENTS.md` — combined ≤200 lines.
4. If combined exceeds 200 lines: move the least-frequently-needed rule to Layer 2.

### 4.2 Add a Layer 2 path-scoped rule

1. Create `.claude/rules/<topic>.md` with frontmatter:
   ```markdown
   ---
   paths: ["**/*.ts", "**/*.tsx"]
   ---
   ```
2. The rule loads only when Claude touches files matching `paths:`.
3. Keep each `<topic>.md` focused — one concern per file.
4. **Verify**: open a file matching the glob, confirm Claude references the rule.

### 4.3 Add a Layer 2 memory topic (project learning)

1. Create `memory/<topic>.md` under the project's auto-memory dir (`~/.claude/projects/<slug>/memory/`).
2. Frontmatter: `name`, `description`, `type` (user / feedback / project / reference).
3. Add one line to `MEMORY.md` index: `- [Title](file.md) — one-line hook`.
4. **Verify**: `MEMORY.md` index stays ≤200 lines / ≤25 KB. Description on the index line should match the topic file's frontmatter `name`.

### 4.4 Add a Layer 2 skill (invoked procedure)

1. Create `.claude/skills/<skill>/SKILL.md` with frontmatter `name`, `description`.
2. Body is the procedure — multi-step, cross-cutting. Static facts belong in rules, not skills.
3. **FOMO gate**: skill must plausibly run ≥3× per month, otherwise inline the steps in a rule.
4. **Verify**: invoke via `/<skill>` from Claude Code; confirm SKILL.md content enters the conversation as a single message (Anthropic Progressive Disclosure level 2).

### 4.5 Add a Layer 3 hook

1. Implement the handler in `~/.claude/hooks/<name>.{js,ps1}`.
2. Schema: read JSON from stdin, optionally write JSON to stdout (`{"modified_input":{...}}` to rewrite, empty to pass through, exit code `2` to block).
3. Register in `~/.claude/settings.json` under the appropriate event (`PreToolUse`, `PostToolUse`, `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreCompact`, `PostCompact`, `Stop`).
4. **FOMO gate**: hook must enforce a policy that has FAILED before. Never add a hook because "it would be cool".
5. **Verify**: pipe a sample event JSON to the handler manually; confirm output. Then update `AUTOMATION.md` registration table.

### 4.6 Add a Layer 3 deny rule

1. Append a pattern to `permissions.deny` in `~/.claude/settings.json` (global) or project `.claude/settings.json` (project-only).
2. Patterns must be portable across shells — see migration entry 2026-04-28 in ARCHITECTURE.md §12. Cover all path forms: `~/...`, `/c/Users/...`, `C:/Users/...`, `%USERPROFILE%/...`.
3. **Verify**: in a sandbox, attempt the denied action — confirm Claude Code refuses it without bypass prompt.

### 4.7 Add a verification loop entry

1. Identify the metric (e.g., "% of Bash calls that hit the hook").
2. Add the check to `hooks/token-report.ps1` (Stop hook) or `hooks/cleanup.ps1` (SessionEnd).
3. Append findings to `reports/<metric>.md` (append-only).
4. **Anti-pattern**: do NOT make verification block on failure — it must be observable, not enforcing. Enforcement belongs in Layer 3.

---

## 5. Anti-Patterns (Anthropic-explicit warnings)

| Anti-pattern | Source | What it looks like here |
|---|---|---|
| Over-specified CLAUDE.md | Best Practices | "If your CLAUDE.md is too long, Claude ignores half of it." Combined CLAUDE.md+AGENTS.md must stay ≤200 lines. |
| Kitchen-sink session | Best Practices | Mixing unrelated tasks in one conversation. Use `/clear` between topics. |
| Correcting over and over | Best Practices | After 2 corrections, `/rewind` or `/clear` and rewrite the prompt. |
| One-shot agent | Effective Harnesses | Letting the agent attempt an entire feature in one go. Constrain to one increment per session; commit progress. |
| Hook exit-code confusion | Hooks docs | Many use exit code 1 (non-blocking) when they meant exit code 2 (blocking). Always exit 2 for policy enforcement. |
| FOMO-driven additions | Vanilla compliance | "Skills look interesting" is not a reason. Every new hook/rule/skill must point to a past incident or measurable benefit. |
| Documentation as enforcement | Inferred from Hooks docs | Writing "always do X" in CLAUDE.md instead of installing a hook. If it must hold every time, it goes in Layer 3. |

---

## 6. Cross-Layer Refactoring Cues

When Layer 1 grows beyond budget, push items down:

- Layer 1 entry referenced only when editing TS files → move to `.claude/rules/frontend.md` (Layer 2).
- Layer 1 entry that's actually a procedure (e.g., "before merging, run X then Y then Z") → move to a skill (Layer 2).
- Layer 1 entry that says "always do X for every Bash call" → migrate to a Layer 3 hook and remove from Layer 1.

The MEMORY.md index follows the same discipline: long memories split into topic files; the index keeps one-line pointers.

---

## 7. Per-Project Bootstrap Checklist

For a new project to inherit this architecture:

- [ ] `<project>/AGENTS.md` exists with cross-AI rules (cross-AI superset of Claude-only rules).
- [ ] `<project>/CLAUDE.md` exists with `@AGENTS.md` import on line 1, plus Claude-only deltas.
- [ ] Combined `CLAUDE.md` + `AGENTS.md` ≤ 200 lines.
- [ ] `<project>/.claude/settings.json` exists with project-specific PostToolUse checks (lint/test/typecheck) and project-only deny rules.
- [ ] `<project>/.claude/rules/` contains path-scoped rules with `paths:` frontmatter.
- [ ] `<project>/.claude/skills/` contains only skills used ≥3×/month.
- [ ] `~/.claude/projects/<slug>/memory/MEMORY.md` index exists; topic files referenced are concrete (no dangling links).
- [ ] No documentation contradicts live state (no "feature X is unavailable" while X is installed; no references to files that don't exist).
- [ ] Project does not redefine global Layer 3 hooks — those cascade from `~/.claude/settings.json` automatically.

Template: `~/.claude/templates/project-init.md` (see ARCHITECTURE.md §1 companion list).

---

## 8. When To Update This Document

- A new architectural decision is made (e.g., adopting a new layer, changing the verification loop).
- A new Anthropic doc supersedes the cited sources — update §1 source list.
- A new anti-pattern is discovered through incident — append to §5.

Do **not** update for:
- A specific project's rule additions (those live in the project, not here).
- Cosmetic changes to existing layers.
- Migrating a single rule from one layer to another (handled by §6 cues, no doc edit needed).

---

## 9. Glossary (this-doc-specific only)

Anthropic terms (Progressive Disclosure, Hook Event Model, Plan-Verify Loop, Precedence Hierarchy) are defined in the upstream sources cited in §1. Terms specific to this document:

| Term | Meaning |
|---|---|
| Harness | Every piece of code, configuration, and execution logic that isn't the model itself — the thing that turns a raw model into an agent. |
| Layer 1 / 2 / 3 | This document's naming for always-loaded / on-demand / hook-enforced configuration tiers. |
| Verification Loop | Append-only audit trail (`rtk gain`, `rtk discover`, `.drift-queue`, `reports/*.md`) that detects gaps for Layer 3 fixes. |
| FOMO gate | Decision rule: every new harness item must justify itself with a past incident or measurable benefit, otherwise skip. |

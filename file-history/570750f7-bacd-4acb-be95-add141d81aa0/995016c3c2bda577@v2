# Claude AI Harness Architecture — Anthropic-Native (Final)

> **Revision history**:
> - v1: SOLID + DDD with bounded contexts (rejected — see Architecture Decision below).
> - v2: Anthropic-native 3-layer pivot (correct framing, but listed Steps E/F/G that were already applied).
> - **v3 (this file)**: Architecture decision documented with full citations; scope reduced to the actual remaining doc contradictions.

---

## Context

**Problem.** Three documentation files now contradict the live system state:

1. `MEMORY.md` line 1 has a stray `s` (`s# Memory Index`) that breaks the index header.
2. `MEMORY.md` line 9 still describes RTK as "no auto-rewrite hook" while the body of the linked `feedback_rtk.md` already says the hook IS active.
3. `AGENTS.md` line 78 still labels RTK as "auto-rewrite hook unavailable (RTK platform limitation)" while line 84 (Self-Check §1) states "PreToolUse hook handles this automatically".

These contradictions are residue from the v1 → v2 transition. Steps E/F/G of the v2 plan are already applied (verified in this session by reading `AGENTS.md:84`, `CLAUDE.md:9`, `feedback_rtk.md`).

**Why it matters.** The harness pivoted from "discipline-based prefix" to "PreToolUse-hook-enforced" when `hooks/rtk-prerewrite.js` was registered in global `settings.json:38`. Sessions reading the stale lines may distrust the hook ("the doc says it doesn't exist") and burn tokens manually re-prefixing.

**Outcome.** Doc surface aligned with live state. No code changes; no hook changes.

---

## Architecture Decision (recorded for future sessions)

User asked whether SOLID + DDD or another pattern is best for this harness. Research conclusion:

| Pattern | Endorsed by official source? | Evidence |
|---|---|---|
| **DDD** (bounded contexts, aggregates, anti-corruption layer) | **No.** Zero official agent framework recommends DDD for harness. | OpenAI Swarm, Microsoft AutoGen/Agent Framework, LangGraph, CrewAI, Anthropic — all silent or use opposite (flat) patterns. Community Medium/ODSC posts mention DDD aspirationally; no official doc adopts it. |
| **SOLID** | **Partial.** Applies to hook/skill *code*, not to the configuration layer. | Anthropic settings precedence (Managed → Project → User → Local) and deny-list accumulation are policy-precedence, not polymorphic substitution. SRP/OCP/LSP do not map cleanly to JSON config. |
| **Anthropic-native** (Progressive Disclosure + Hook Event Model + Plan-Verify Loop) | **Yes — official.** | Skills docs (Progressive Disclosure 3-level: frontmatter → SKILL.md → bundled resources). Hooks docs ("zero exceptions" enforcement, exit-code-2 blocking). Best Practices ("verification is the single highest-leverage practice"). |

**Decision: Anthropic-native.** Mapping for this repo:

```
Layer 1 — Always-loaded (≤200 lines)         CLAUDE.md, AGENTS.md, MEMORY.md index
Layer 2 — Path-scoped / on-demand            .claude/rules/{frontend,php,scss}.md (paths: frontmatter)
                                              memory/<topic>.md (loaded by MEMORY.md links)
                                              .claude/skills/<skill>/SKILL.md (invoked, not auto-loaded)
Layer 3 — Hook-enforced determinism          PreToolUse=rtk-prerewrite.js
                                              PostToolUse=tsc/vitest/php-l/stylelint
                                              PreCompact/PostCompact=memory snapshot
                                              SessionEnd=cleanup + drift; Stop=token-report
                                              permissions.deny=structural blocks
Verification Loop                            rtk gain (quantitative), rtk discover (gap audit),
                                              .drift-queue → review-needed.md
```

**Sources** (all checked this session):
- https://www.anthropic.com/research/building-effective-agents — Augmented LLM, Orchestrator-Workers, Evaluator-Optimizer.
- https://docs.anthropic.com/en/docs/claude-code/hooks — Hook event model + exit-code-2 enforcement.
- https://docs.anthropic.com/en/docs/claude-code/memory — CLAUDE.md hierarchy, ≤200 lines target, `@import` chain.
- https://docs.anthropic.com/en/docs/claude-code/best-practices — "Verification is the single highest-leverage thing you can do."
- https://docs.anthropic.com/en/docs/claude-code/skills — Progressive Disclosure 3 levels.
- https://docs.anthropic.com/en/docs/claude-code/settings — Precedence + deny-list accumulation.
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents — incremental over one-shot, git-as-state.
- Cross-checked: OpenAI Swarm (stateless handoff), Microsoft Agent Framework (5 orchestration types), LangGraph (stateful graph), CrewAI (YAML manifest). None recommend DDD/SOLID for the harness layer.

This decision is final and supersedes the v1 DDD framing in any prior conversation.

---

## Live State (verified this session)

| File | Path | Line(s) checked | State |
|---|---|---|---|
| Global settings | `~/.claude/settings.json` | 38 | OK PreToolUse hook registered → `hooks/rtk-prerewrite.js` |
| Global hook | `~/.claude/hooks/rtk-prerewrite.js` | 1–93 | OK Functional: exempt builtins, env-var skip, `&&` `\|\|` `;` split, pipe stays single segment, RTK_DISABLED bypass |
| Token report | `~/.claude/hooks/token-report.ps1` | 14, 57–64 | OK rtk gain + rtk discover both wired into Stop hook |
| Global RTK ref | `~/.claude/RTK.md` | 130–136 | OK "Hook Status: ACTIVE" present |
| Project rules | `.claude/rules/{frontend,php,scss}.md` | — | OK All three exist |
| Project filters | `.rtk/filters.toml` | — | OK Exists |
| Project AGENTS Self-Check §1 | `AGENTS.md:84` | — | OK Says "PreToolUse hook handles this automatically" |
| Project CLAUDE.md L9 | `CLAUDE.md:9` | — | OK Says "RTK auto-rewrite is **active** via PreToolUse hook" |
| Memory feedback body | `memory/feedback_rtk.md` | 7–9 | OK Says hook auto-prefixes; bypass + reference |

**Inconsistencies remaining** (the targets of this plan):

| # | File | Line | Current | Problem |
|---|---|---|---|---|
| 1 | `memory/MEMORY.md` | 1 | `s# Memory Index — NINEONELABS Renewal` | Stray leading `s` — breaks markdown H1 |
| 2 | `memory/MEMORY.md` | 9 | `[RTK mandatory prefix](feedback_rtk.md) — Native Windows: explicit \`rtk <cmd>\` prefix required (no auto-rewrite hook). Full reference at ~/.claude/RTK.md.` | Description still says "no auto-rewrite hook" but linked file body says hook IS active |
| 3 | `AGENTS.md` | 76–80 | Heading `## RTK (Mandatory Prefix)` + body "Windows native — auto-rewrite hook unavailable (RTK platform limitation). Every Bash call whose output spans more than ~3 lines MUST start with \`rtk\`. Pass-through is safe..." | Contradicts AGENTS.md:84 (hook handles automatically) and CLAUDE.md:9 (hook active). Stale section from v1 era. |

---

## Implementation Plan (3 surgical edits)

### Edit 1 — `memory/MEMORY.md` line 1 typo

**File**: `C:\Users\nineonelabs003\.claude\projects\d------------------260427\memory\MEMORY.md`

```diff
-s# Memory Index — NINEONELABS Renewal
+# Memory Index — NINEONELABS Renewal
```

Tool: `Edit` with `old_string="s# Memory Index — NINEONELABS Renewal"`.

### Edit 2 — `memory/MEMORY.md` line 9 description sync

Description must now match the linked file's body (auto-rewrite hook IS active).

```diff
-- [RTK mandatory prefix](feedback_rtk.md) — Native Windows: explicit `rtk <cmd>` prefix required (no auto-rewrite hook). Full reference at ~/.claude/RTK.md.
+- [RTK auto-rewrite hook active](feedback_rtk.md) — PreToolUse hook auto-prefixes Bash; bypass `RTK_DISABLED=1`. Full reference at ~/.claude/RTK.md.
```

The linked frontmatter `name:` is already `"RTK token optimization — auto-rewrite hook active"` (verified `feedback_rtk.md:2`), so the new index label aligns with the topic file's own name.

### Edit 3 — `AGENTS.md` lines 76–80 RTK section rewrite

**File**: `d:\최신프로젝트\나인원랩스\퍼블\260427\AGENTS.md`

```diff
-## RTK (Mandatory Prefix)
-
-Windows native — auto-rewrite hook unavailable (RTK platform limitation). Every Bash call whose output spans more than ~3 lines MUST start with `rtk`. Pass-through is safe (RTK forwards unknown commands unchanged), so when in doubt, prefix.
-
-Full command list: `%USERPROFILE%\.claude\RTK.md`. Project filters: `.rtk/filters.toml`.
+## RTK (Auto-Prefix via Hook)
+
+PreToolUse hook (`~/.claude/hooks/rtk-prerewrite.js`, registered in global `settings.json`) auto-prefixes every Bash call with `rtk`. Built-ins (`echo`, `pwd`, etc.), already-prefixed commands, and `RTK_DISABLED=1 <cmd>` bypass the rewrite. Chains (`&&` `||` `;`) are split and rewritten per segment; pipes (`|`) stay single-segment. Anthropic "zero exceptions" hook pattern.
+
+Full command list: `%USERPROFILE%\.claude\RTK.md`. Project output filters: `.rtk/filters.toml` (post-execution shaping). Verify per session via `rtk discover` (verification-loop pattern, Best Practices §verification).
```

The Self-Check §1 directly below (line 84) already states the hook handles prefixing — Edit 3 makes the section heading + body consistent with that.

---

## Verification (after the 3 edits)

1. **Markdown renders** — `MEMORY.md` H1 must be `# Memory Index — NINEONELABS Renewal` (no stray `s`):
   ```bash
   rtk grep -n "^# Memory Index" "C:/Users/nineonelabs003/.claude/projects/d------------------260427/memory/MEMORY.md"
   # Expected: 1 match on line 1
   ```

2. **No remaining "no auto-rewrite hook" references** in active docs:
   ```bash
   rtk grep -rn "no auto-rewrite hook" "d:/최신프로젝트/나인원랩스/퍼블/260427/" "C:/Users/nineonelabs003/.claude/projects/d------------------260427/"
   # Expected: 0 matches
   ```

3. **No remaining "auto-rewrite hook unavailable" or "RTK platform limitation"** in active docs:
   ```bash
   rtk grep -rn "auto-rewrite hook unavailable\|RTK platform limitation" "d:/최신프로젝트/나인원랩스/퍼블/260427/"
   # Expected: 0 matches
   ```

4. **AGENTS.md still ≤200 lines** (Anthropic guidance — re-verify after edit):
   ```bash
   rtk grep -c "" "d:/최신프로젝트/나인원랩스/퍼블/260427/AGENTS.md"
   # Expected: ≤200 (was 94 before; estimate ≤96 after)
   ```

5. **Combined CLAUDE.md + AGENTS.md ≤200 lines** (project rule):
   ```bash
   echo $(($(rtk grep -c "" "d:/최신프로젝트/나인원랩스/퍼블/260427/CLAUDE.md") + $(rtk grep -c "" "d:/최신프로젝트/나인원랩스/퍼블/260427/AGENTS.md")))
   # Expected: ≤200
   ```

6. **Hook still functional** (sanity, no code changed but verify nothing broke):
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | node "C:/Users/nineonelabs003/.claude/hooks/rtk-prerewrite.js"
   # Expected: {"modified_input":{"command":"rtk git status"}}
   ```

---

## Critical Files

| File | Change | Lines touched |
|---|---|---|
| `C:\Users\nineonelabs003\.claude\projects\d------------------260427\memory\MEMORY.md` | typo + description sync | 1, 9 |
| `d:\최신프로젝트\나인원랩스\퍼블\260427\AGENTS.md` | RTK section heading + body | 76–80 |

No code edits. No hook edits. No settings edits. No file creation.

## Execution Order

1. Edit MEMORY.md line 1 (typo).
2. Edit MEMORY.md line 9 (description).
3. Edit AGENTS.md lines 76–80 (RTK section).
4. Run the 6 verification commands above. Report any non-zero match for #2/#3.

## Out of Scope (acknowledged but not done here)

- ARCHITECTURE.md formalization of the 3-layer model. The decision IS recorded in this plan file; promoting it into ARCHITECTURE.md is a separate task if the user wants permanent project-level reference.
- Old plan file's "Pending" status table marking E/F/G as done. The status entries are stale but harmless; this plan supersedes that file.
- Reuse of existing functions/utilities: none required — the work is text edits to docs only.

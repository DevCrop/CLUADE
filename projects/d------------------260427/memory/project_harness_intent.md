---
name: Harness scope is intentional forward-investment
description: The 5-doc / 8-hook / auto-memory / drift-queue infrastructure in ~/.claude/ is sized for future framework-based multi-project expansion, not for the current 260427-only state.
type: project
originSessionId: 00c5d050-5189-46a7-98e4-fc921951d76f
---
The global Claude harness (`%USERPROFILE%\.claude\` — 5 architecture docs, 8 hooks, 13-category retention, drift queue, auto-memory, doc SHA monitoring) is **intentionally pre-built** for an upcoming framework-based, multi-project setup. It is NOT over-engineering for the current state.

**Why:** The user plans to scale this machine to N projects on a shared framework base. Infrastructure that looks oversized for one project (HARNESS_ARCHITECTURE.md "project-agnostic" pattern, Extension Recipes 7-section playbook, Migration History "Subsequent deltas" empty table, 5-doc upstream-change monitoring) is sized for that future state. The denominator (project count) will grow; the numerator (infra volume) is fixed up front.

**How to apply:**
- Do **not** propose trimming `~/.claude/` architecture docs, removing Extension Recipes, or collapsing the 5-doc structure on the grounds of "over-engineering" or "FOMO". The volume is justified by the planned expansion, not by current usage frequency.
- Do **not** apply the FOMO gate (≥3×/month rule) to the architecture docs themselves; it applies to hooks/skills/permissions, not to forward-investment documentation.
- Re-evaluation trigger: if no second project has joined this machine within ~12 months, OR if Anthropic's hooks/settings schema changes break the auto-regeneration pipeline. Until then, treat the harness as appropriately scoped.
- When the second project arrives, expect [HARNESS_ARCHITECTURE.md §7 Per-Project Bootstrap Checklist](C:/Users/nineonelabs003/.claude/HARNESS_ARCHITECTURE.md) to be exercised for real — that is the validation point.

**Context:** Logged 2026-04-28 after a doc-cleanup review where the assistant initially scored the setup at 4.0/5 with a 0.5-point deduction for "infrastructure-vs-project-size mismatch". User clarified the expansion intent; revised score is 4.5/5 — solo-setup ceiling, with remaining risk being execution timing on the expansion plan, not the architecture itself.

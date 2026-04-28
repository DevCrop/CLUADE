---
name: Session operating rules (course-correct / context / parallel)
description: Claude Code best-practices session operating patterns — /clear after two failures, context hygiene, parallel explorer calls
type: feedback
originSessionId: 640f6a38-20ef-4a8d-ab1b-a58e4414a23a
---
Session operating rules for this project. The canonical document is `.claude/BEST_PRACTICES.md` Part B; this memory is its summary.

**Course-correct protocol:**
- 1st failure → immediate corrective prompt
- 2nd failure → `Esc Esc` or `/rewind` (do not loop on corrections)
- 3rd or beyond → `/clear`, then restart with a more specific prompt

**Context hygiene:**

- `/clear` is the single largest token-saving lever. Use it deliberately when switching to unrelated work — it cuts the cache so the next session starts with minimal context.
- Files over ~500 lines / open-ended exploration → delegate to `$scene-explorer` (Three.js) / `$php-explorer` (PHP) / Explore subagent.
- Unknown scope or unknown file count → delegate to an explorer immediately, regardless of file size (the goal is to keep main context clean).
- If a single task floods the context, use `/compact <focus>`.
- Trust the PostToolUse tsc hook — do not re-run it manually.

**Parallel processing:**
- Two or more independent explorations → call subagents in a single message.
- Risky changes → split Writer/Reviewer into separate sessions (implementation session ↔ review session).
- Tasks finishing in 1–2 tool calls → do not use a subagent.

**Why:** When the user audited Claude Code's official best practices on 2026-04-25, "active intervention / context management / parallel processing" was the gap that hadn't been documented locally. This rule directly affects token efficiency and debugging recovery speed.

**How to apply:**
- Self-check on every response — if the same mistake appears twice, suggest `/rewind` or `/clear`.
- When the user asks to open a large file → propose explorer delegation first.
- For independent work → always parallelize the tool calls.

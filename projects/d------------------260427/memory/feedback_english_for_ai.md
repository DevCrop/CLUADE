---
name: AI-consumed content must be in English
description: All AI-consumed content (CLAUDE.md, AGENTS.md, rules, hook scripts, plan files, MEMORY topic files, AUTO-mark sections, comments, log messages, status line) must be written in English. User-facing chat responses remain in Korean.
type: feedback
originSessionId: 8b7621d3-e484-4288-a721-16531e8deffe
---
All AI-consumed content must be written in English. User-facing chat responses remain in Korean per the global Response Style rule.

**Why:** Korean-mixed prompts waste tokens (Korean tokenizes ~2x English), reduce prompt-cache hit consistency, and force the model to spend reasoning tokens on translation. Senior AI-harness practice — the model reads English natively, the user reads Korean responses. The user explicitly stated this on 2026-04-27: "내용은 AI가 이해할 수 있게 영문으로 반영" + "앞으로도 AI가 이해하는 내용은 다 영문으로 나오도록".

**How to apply:**
- **New files** (hook scripts, `.md` docs, plan files, `AUTO`-mark sections, code comments, log messages, status line text): English only.
- **Existing core AI-consumed docs to migrate to English when touched**:
  - Global: `D:\.claude\CLAUDE.md`, `D:\.claude\RTK.md`
  - Project: `CLAUDE.md`, `AGENTS.md`, `.claude/rules/*.md`, `.claude/BEST_PRACTICES.md`, `.claude/SETUP_CHECKLIST.md`
  - Memory: `D:\.claude\projects\<proj>\memory\*.md` topic files (excluding pure user notes)
  - Plans: `D:\.claude\plans\*.md`
- **Keep in Korean**: user chat responses, sample copy in view files, brand documents (per `feedback_doc_manager_role.md`).
- **Verbatim regardless of language**: code identifiers, file paths, shell commands, error messages, console output.
- **Migration order** (when bandwidth available): rules > AGENTS.md > CLAUDE.md > BEST_PRACTICES.md > MEMORY topic files > plan files.

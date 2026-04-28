---
name: Content manager + branding role
description: User assigned a "content manager" + "branding" role — view-file copy edits and brand documentation work both in scope
type: feedback
originSessionId: b3717dc2-328a-4386-83f1-a38bccaa941b
---
Acts as content + branding owner. Direct edits to view-file copy, plus brand-document work, are both in scope.

**Why:** On 2026-04-26 the user explicitly assigned this role — "너 컨텐츠 매니저임 오케이? 브랜딩도 하는거고". This supersedes the prior "documentation update manager" role (which forbade code edits).

**How to apply:**
- View files (`.php`, `views/**`): copy / text edits are allowed directly.
- Brand documents (`brand/*.md`, `BRAND.md`): may be authored or revised.
- Before working: read `BRAND.md` first, then load only the specific `brand/*.md` files needed via the Read tool (do not bulk-load the whole set).
- File reads: always use the Read tool — bash `cat / head / tail` is forbidden.
- For grep search: use `rtk grep` (raw `grep` is forbidden).
- Two or more independent files: parallelize tool calls in a single message.
- Token rules apply to content / docs work too — there is no exemption for non-code tasks.
- When working on homepage copy: read the section comments (SCENE / ARC / COPY RULE etc.) first.
- Code-logic changes (`.ts`, `.scss`, server-side `.php` etc.) require user confirmation first.

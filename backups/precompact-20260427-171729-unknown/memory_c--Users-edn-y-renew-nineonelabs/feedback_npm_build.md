---
name: Never run npm build/watch/install during normal development
description: npm run build, npm run watch, and npm install are forbidden during normal dev — Vite dev server auto-builds on every file save
type: feedback
originSessionId: 624772be-a851-4c46-81a2-c61d8d7b4ad9
---
Never run `npm run build`, `npm run watch`, or `npm install` during normal development.

**Why:** Vite dev server at `http://localhost:8888` auto-rebuilds the bundle on every file save. Running these commands provides no benefit and wastes context and time. Do not include them in verification steps, PR notes, or agent plans.

**How to apply:** Only `npm install <package>` is allowed — and only when explicitly adding a new dependency. For all other cases, these commands must not be suggested or run.

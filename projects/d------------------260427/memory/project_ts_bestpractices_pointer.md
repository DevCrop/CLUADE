---
name: TS architecture best practices — pointer
description: Pointer to the canonical TypeScript / Three.js architecture rules document — WebGL lifecycle, hot-path rules, disposal checklist, Theatre rules
type: reference
originSessionId: 3653801a-7908-4a0e-997b-5a4e926dcdb1
---
Full rules: `.claude/BEST_PRACTICES.md` (project root).

Key sections:

- **Where New Code Goes** — file-type routing (objects, scenes, runtime, utils, types, config)
- **WebGL Lifecycle** — AppEngineRuntime → Engine lifecycle, WorksSceneManager secondary-renderer rules
- **Three.js Hot Path** — no per-frame allocation, no `getObjectByName`, uniform rules
- **Disposal Checklist** — cleanup matrix for addEventListener / RAF / Observer / Material / Texture / RenderTarget
- **Theatre Rules** — PageTheatreBinder adapter factory, page-local layout for Works Theatre
- **Review Triggers** — files that require a `$scene-explorer` audit before edits (Engine, Scene, AppManager, etc.)

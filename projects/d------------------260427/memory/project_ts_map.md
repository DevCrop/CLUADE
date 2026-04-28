---
name: TypeScript ownership boundaries
description: AppManager / PageRuntime / PageTheatreBinder 3-way boundary definition + Works standalone-renderer exception + init flow
type: project
originSessionId: 940f3c69-ab68-40c4-809f-8acca066cc76
---

# TypeScript ownership boundaries

## Ownership boundaries (hard rule)

- **AppManager** — owns 3D / engine bootstrap. Delegates Theatre to PageTheatreBinder; does not touch DOM / UI.
- **PageRuntime** — owns DOM / UI lifecycle only. Initializes UI components such as Header / Drawer / Dropdown / CustomCursor. Does not touch the 3D engine.
- **PageTheatreBinder** — dynamically imports a Theatre adapter per page ID, exposing a uniform interface (`applyBootStateIfNeeded` / `startIntroIfNeeded` etc.).

**Exception:** the Works page uses `pages/works/render/WorksSceneManager.ts` as a standalone renderer, separate from the AppManager flow.

## Initialization flow (one line)

`app.ts` → `AppManager.init()` → loads Engine + PageTheatreBinder adapter → AppOrbitRuntime loop. DOM runs separately via `PageRuntime.runPage(root)`.

**Why:** The AppManager / PageRuntime / PageTheatreBinder boundary is not visible from the code itself — without these three rules, 3D / DOM code lands in the wrong place.
**How to apply:** Before adding new code, decide "3D or DOM?" → place the file according to the boundary above. New pages go through the `/new-route` skill.

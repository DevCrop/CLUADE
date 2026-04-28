---
name: NINEONELABS Project Architecture
description: Core architecture decisions — custom MVC, Three.js scene structure, Theatre.js binding locations, bfcache pattern, SEO files
type: project
originSessionId: 9bdf7fa7-352d-44ea-97bc-694667eeaecf
---
Custom PHP 7.4 MVC + Three.js + Theatre.js web agency site renewal project.

**Key architecture decisions:**
- Routing: closure-based (`routes/web.php` + `render()`) — NOT controller-class MVC
- Three.js scenes: `resource/ts/pages/<page>/scene/`
- Theatre.js bindings: `resource/ts/pages/<page>/theatre/`
- Shared code: outside page folders (`resource/ts/runtime/`, `resource/ts/manager/`, etc.)
- TypeScript types: dedicated `resource/ts/types/*.types.ts` files — no inline types, no `any`
- Build: Vite (bundle) + sass CLI (CSS) — never run `npm run build` (dev server auto-rebuilds on save)
- DB tables: `nb_` prefix (e.g. `nb_siteinfo`, `nb_admin`)

**Notable shared utilities (resource/ts/):**

| File | Role |
|---|---|
| `app/ResizeSetup.ts` | resize debounce + visualViewport sync |
| `runtime/SubpageStarfieldRuntime.ts` | shared 3D starfield parallax for contact / careers / inside |
| `ui/WorkCard.ts` | canvas-based texture rendering helper for WorkCard |
| `utils/Device.ts` | device / viewport detection (includes iOS visualViewport) |
| `utils/PerformanceProfile.ts` | automatic performance tier selection (low / mid / high) |

**bfcache support pattern (settled 2026-04-24):**
- Restart / tear down RAF chains via `pageshow` and `pagehide` events
- Applied across `app.ts`, `AnimationLoop.ts`, `LenisRuntime.ts`, `SubpageStarfieldRuntime.ts`
- Do not use `beforeunload` (it disables bfcache entry)

**Author / editor mode pattern:**
- `data-*-mode="author"` attribute → isolated UI via `_utils.scss` selectors
- During Theatre.js Studio editing, header / panel / intro elements get `pointer-events: none` + transparency

**SEO infrastructure:**
- `robots.txt`: blocks admin / api paths, includes sitemap reference
- `views/pages/sitemap.php`: dynamic XML sitemap for works / news / insight / award

**Why:** Designed to eliminate Barba.js / SPA contracts and enforce clear ownership separation between AppManager, PageRuntime, and PageTheatreBinder.

**How to apply:** Always follow this structure when adding new pages or features. Use the `/new-route` skill.

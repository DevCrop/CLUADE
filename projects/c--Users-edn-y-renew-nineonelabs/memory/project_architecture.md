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

| 파일 | 역할 |
|---|---|
| `app/ResizeSetup.ts` | resize debounce + visualViewport 동기화 |
| `runtime/SubpageStarfieldRuntime.ts` | contact/careers/inside 공통 3D 별빛 parallax |
| `ui/WorkCard.ts` | canvas 기반 WorkCard 텍스처 렌더링 유틸 |
| `utils/Device.ts` | iOS visualViewport 포함 기기/뷰포트 감지 |
| `utils/PerformanceProfile.ts` | 성능 티어 자동 선택 (low/mid/high) |

**bfcache 지원 패턴 (2026-04-24 정착):**
- `pageshow` + `pagehide` 이벤트로 RAF 체인 재시작/종료
- `app.ts`, `AnimationLoop.ts`, `LenisRuntime.ts`, `SubpageStarfieldRuntime.ts` 모두 적용
- `beforeunload` 사용 금지 (bfcache 진입 차단)

**Author/editor 모드 패턴:**
- `data-*-mode="author"` attr → `_utils.scss` 셀렉터로 UI 격리
- Theatre.js Studio 편집 중 header, panel, intro 요소를 pointer-events:none + 투명 처리

**SEO 인프라:**
- `robots.txt`: admin/api 경로 차단, sitemap 참조 포함
- `views/pages/sitemap.php`: works/news/insight/award 동적 XML 사이트맵

**Why:** Designed to eliminate Barba.js/SPA contracts and enforce clear ownership separation between AppManager, PageRuntime, and PageTheatreBinder.

**How to apply:** Always follow this structure when adding new pages or features. Use the `/new-route` skill.

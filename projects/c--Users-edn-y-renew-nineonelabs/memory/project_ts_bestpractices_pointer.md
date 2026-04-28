---
name: TS Architecture Best Practices 위치
description: TypeScript/Three.js 아키텍처 핵심 규칙 문서 위치 — WebGL lifecycle, hot-path rules, disposal checklist, Theatre rules
type: reference
originSessionId: 3653801a-7908-4a0e-997b-5a4e926dcdb1
---
Full rules: `c:\Users\edn_y\renew_nineonelabs\.claude\BEST_PRACTICES.md`

Key sections:

- **Where New Code Goes** — 파일 타입별 라우팅 (objects, scenes, runtime, utils, types, config)
- **WebGL Lifecycle** — AppEngineRuntime → Engine 생명주기, WorksSceneManager 2차 렌더러 규칙
- **Three.js Hot Path** — 프레임당 할당 금지, getObjectByName 금지, uniform 규칙
- **Disposal Checklist** — addEventListener/RAF/Observer/Material/Texture/RenderTarget 정리 표
- **Theatre Rules** — PageTheatreBinder 어댑터 팩토리, works Theatre 페이지 로컬 구조
- **Review Triggers** — 수정 전 `$scene-explorer` 감사가 필요한 파일 목록 (Engine, Scene, AppManager 등)

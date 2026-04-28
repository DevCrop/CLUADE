---
name: TypeScript 소유권 경계
description: AppManager/PageRuntime/PageTheatreBinder 3-way 경계 정의 + Works 독립 렌더러 예외 + 초기화 흐름
type: project
originSessionId: 940f3c69-ab68-40c4-809f-8acca066cc76
---

# TypeScript 소유권 경계

## 소유권 경계 (절대 룰)

- **AppManager** — 3D/Engine 부트스트랩 오너. Theatre는 PageTheatreBinder로 위임, DOM/UI는 다루지 않음.
- **PageRuntime** — DOM/UI 라이프사이클만. Header/Drawer/Dropdown/CustomCursor 등 UI 컴포넌트 init. 3D 엔진 안 다룸.
- **PageTheatreBinder** — 페이지 ID → Theatre 어댑터 동적 import. 통일 인터페이스(`applyBootStateIfNeeded` / `startIntroIfNeeded` 등).

**예외:** Works 페이지만 `pages/works/render/WorksSceneManager.ts`를 독립 렌더러로 사용 — AppManager 흐름과 별개.

## 초기화 흐름 (1줄)

`app.ts` → `AppManager.init()` → Engine + PageTheatreBinder 어댑터 로드 → AppOrbitRuntime 루프. DOM은 별도로 `PageRuntime.runPage(root)`.

**Why:** AppManager/PageRuntime/PageTheatreBinder 경계가 코드에서 바로 안 보임 — 이 3규칙을 모르면 3D/DOM 코드가 잘못된 곳에 들어감.
**How to apply:** 새 코드 추가 전 "3D냐 DOM이냐" 판단 → 위 경계 기준으로 파일 위치 결정. 신규 페이지는 `/new-route` skill.

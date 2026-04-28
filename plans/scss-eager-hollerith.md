# 반응형 로직 정비 (SCSS + TS)

## Context

`_main.scss` 검토 중 두 가지 사실이 드러남:

1. **SCSS 누락**: 일부 페이지/서브 SCSS에 데스크톱 전용 고정값(`width: 42%`, `grid-template-columns: repeat(N, 1fr)` 등)이 남고 `@include mq(md/sm)` override가 빠짐. 모바일에서 레이아웃이 좁게 깨짐. 추가로 100vh가 일부 위치에서 dvh 폴백 없이 사용되어 iOS 주소창 변동 시 점프 위험.
2. **TS 핫패스 비효율**: 고빈도 이벤트(resize/pointermove/scroll)에서 매번 `getSnapshot()`을 호출하거나 동기 재계산 수행. 시각적 결함은 없지만 불필요한 CPU 비용.

사용자 룰을 명문화:
- **룰 1 (인라인 mq)**: 반응형은 셀렉터 내부에 직접 `@include mq(...)`. 별도 미디어쿼리 블록 분리 금지.
- **룰 2 (fluid 면제)**: `fluid(min, max)`로 크기 지정 시 fluid가 mobile값(min)을 처리하므로 mq override 불필요. `var(--gutter-*)`, `var(--header-height)`, `var(--input-height)`, `var(--hud-unit)`, `var(--scrollbar-width)`, `var(--modal-viewport-offset)`, `var(--intro-glitch-font)` 등은 모두 fluid 기반 → 면제.
- **TS 목표**: resize/반응형 최적화로 UX 개선, 단 **현 씬의 시각적 동작은 변경하지 않음**.

전수 감사 결과: SCSS 12건 (페이지/서브) + dvh 폴백 4건 + TS 4건 핫패스 + reduced-motion 3건.

`mq()` 기본 방향이 `max-width`인 점에 유의 (`@include mq(md)` = `≤768px`).

---

## Phase A — SCSS 페이지/서브 누락 추가 (12건)

모두 룰 1 (인라인 패턴)으로 작성.

### A-1 ~ A-6: `resource/scss/pages/_main.scss`

**A-1. `.no-main-intro-action__content.content-1` (line 348-354)** — 중복 mq 제거
base 50% + lg 50% 동일값 재선언.
```scss
&.content-1 {
  width: 50%;
  // @include mq(lg) { width: 50%; } 제거
}
```

**A-2. `.no-main-intro-action__content.content-2` (line 355-363)** — md 추가
```scss
&.content-2 {
  width: 42%;
  left: inherit;
  right: 0;
  @include mq(lg) {
    width: 50%;
  }
  @include mq(md) {
    width: 100%;
  }
}
```

**A-3. `.no-main-story__block:first-child` (line 485-488)**
```scss
&:first-child {
  width: 42%;
  margin-left: auto;
  @include mq(md) {
    width: 100%;
    margin-left: 0;
  }
}
```

**A-4. `.no-main-story__stats` (line 513-516)**
```scss
&__stats {
  width: 64%;
  margin-left: auto;
  @include mq(md) {
    width: 100%;
    margin-left: 0;
  }
}
```

**A-5. `.no-main-clients__items` (line 1077-1081)** — sm 단계 추가
```scss
&__items {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--gutter-md);
  @include mq(sm) {
    grid-template-columns: 1fr;
  }
}
```

**A-6. `.no-main-contact__stage` md (line 1209-1213)** — 중복 padding 제거
base가 이미 `padding: var(--gutter-lg)` 전방향. md에서 같은 값 재선언 두 줄 삭제.
```scss
@include mq(md) {
  &__stage {
-   padding-left: var(--gutter-lg);
-   padding-right: var(--gutter-lg);
  }
  // 다른 md 규칙 유지
}
```

### A-7 ~ A-12: `resource/scss/pages/_sub.scss`

**A-7. `.no-sub-about-vision__wrap` (line 378-382)**
```scss
&__wrap {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--gutter-md);
  align-items: stretch;
  @include mq(md) {
    grid-template-columns: 1fr;
  }
}
```

**A-8. `.no-sub-about-mission__wrap` (line 438-443)**
```scss
&__wrap {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--gutter-md);
  align-items: stretch;
  @include mq(md) {
    grid-template-columns: repeat(2, 1fr);
  }
  @include mq(sm) {
    grid-template-columns: 1fr;
  }
}
```

**A-9. `.no-sub-client__items` (line 671-675)**
```scss
&__items {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--gutter-md);
  @include mq(md) {
    grid-template-columns: repeat(2, 1fr);
  }
  @include mq(sm) {
    grid-template-columns: 1fr;
  }
}
```

**A-10. `.no-gallery__list` (line 717-720)**
```scss
&__list {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--gutter-sm);
  @include mq(md) {
    grid-template-columns: repeat(2, 1fr);
  }
  @include mq(sm) {
    grid-template-columns: 1fr;
  }
}
```

**A-11. `.no-sub-works__gallery-item` (line 1464-1474)** — 48% staggered 모바일 리셋
```scss
&-item {
  width: 48%;
  display: flex;
  flex-direction: column;
  &:nth-child(even) {
    margin-left: auto;
    margin-top: -24rem;
  }
  &:nth-child(odd) {
    margin-right: auto;
  }
  @include mq(md) {
    width: 100%;
    &:nth-child(even),
    &:nth-child(odd) {
      margin-left: 0;
      margin-right: 0;
      margin-top: 0;
    }
  }
}
```

**A-12. `.no-sub-work-view__info-list` (line 1997-1999)**
```scss
&-list {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--gutter-sm);
  @include mq(lg) {
    grid-template-columns: repeat(2, 1fr);
  }
  @include mq(sm) {
    grid-template-columns: 1fr;
  }
}
```

---

## Phase B — dvh 폴백 추가 (iOS 주소창 변동 대응) — 4건

`100vh`를 사용 중인 위치에 `100dvh` 한 줄 폴백 추가. dvh를 지원하지 않는 브라우저는 vh로 폴백되므로 안전. 시각적 동작 변경 없음, iOS 모바일 브라우저에서만 점프 제거.

**B-1. `_main.scss:103` `.no-main-intro > div`**
```scss
> div {
  height: 100vh;
  height: 100dvh;
}
```

**B-2. `_main.scss:418` `.no-main-hero__content.slogan`**
base와 md 양쪽에 dvh 추가:
```scss
&.slogan {
  height: 100vh;
  height: 100dvh;
  @include mq(md) {
    height: auto;
    min-height: calc(100vh - var(--header-height));
    min-height: calc(100dvh - var(--header-height));
  }
}
```

**B-3. `_main.scss:578` `.no-main-who__body`**
```scss
&__body {
  position: sticky;
  top: var(--header-height);
  min-height: calc(100vh - var(--header-height));
  min-height: calc(100dvh - var(--header-height));
}
```

**B-4. `_main.scss:873` `.no-main-portfolio__head`**
```scss
&__head {
  min-height: 100vh;
  min-height: 100dvh;
}
```

---

## Phase C — TS 핫패스 최적화 (시각 동작 무변경)

기존 `ResponsiveRuntime` 인프라(snapshot + subscribe + dirty flag)를 그대로 활용. 핵심 패턴은 이미 `Ground.ts:116-118`에서 검증된 `subscribe + _resolutionDirty`.

**C-1. `resource/ts/runtime/SubpageStarfieldRuntime.ts:97-100`** — resize debounce
- `window.addEventListener("resize", ...)` 제거
- `this._unsubscribeResponsive = ResponsiveRuntime.getDefault().subscribe(() => { this._resizeDirty = true; })` 추가
- 다음 RAF tick에서 `_resizeDirty` 검사 후 `_resize()` 1회 호출
- `dispose()`에서 unsubscribe
`ResponsiveRuntime`은 이미 `ResizeSetup.ts:36-43`에서 250ms debounce된 이벤트로 snapshot을 갱신 → 자연 debounce.

**C-2. `resource/ts/pages/works/render/WorksSceneManager.ts:918-939`** — onResize RAF 래핑
- `window.addEventListener("resize", onResize)` 제거 → `ResponsiveRuntime.subscribe()` 교체
- `_resizeDirty` 플래그만 세우고, 다음 `_render()` tick 진입 시 `camera.updateProjectionMatrix()` + `_rebuildScatterPositions()` 1회 처리
- `dispose()`에서 unsubscribe

**C-3. `resource/ts/objects/main/Ground.ts:61-74`** — pointerMove snapshot 캐싱
- `_cachedViewportWidth`, `_cachedViewportHeight` 멤버 추가
- 기존 `subscribe()` 콜백(line 116)에서 `_resolutionDirty=true`와 함께 캐시값 갱신
- `_onPointerMove`는 캐시값만 읽음 (매 60-120Hz `getSnapshot()` 호출 제거)
추가 리스너 없음, 기존 콜백 확장.

**C-4. `resource/ts/runtime/SubpageStarfieldRuntime.ts:121-127`** — scroll handler snapshot 캐싱
C-3와 동일 패턴. subscribe 콜백에서 `_cachedViewportHeight` 갱신, scroll 핸들러는 캐시만 읽음.

---

## Phase D — prefers-reduced-motion 존중 (옵트인 사용자 한정)

`ResponsiveSnapshot.flags.reducedMotion`은 이미 `ResponsiveRuntime.ts:189-193`에서 감지·전파 중인데 실제 애니메이터들이 무시. OS 레벨 접근성 신호이므로 존중하는 것이 표준이며 **씬을 해치는 것이 아니라 해당 사용자의 요청에 응함**. 기본 사용자(reducedMotion=false) 동작 무변경.

**D-1. `Ground.ts` mouse texture 페이드 가속**
`_updateMouseTexture()` 내 reduced-motion일 때 `GROUND_MOUSE_TEXTURE_FADE` 0.94 → 0.6 적용 (잔상 단축).

**D-2. `WorksSceneManager` 카드 transition 감속**
hover/focus 카드 스케일 transition duration을 0 또는 즉시 적용.

**D-3. `SubpageStarfieldRuntime` 별 흐름 정지**
reduced-motion일 때 RAF 루프 정지 또는 1FPS 강제. 별 정적 표시 유지.

각 변경은 `ResponsiveRuntime.subscribe()`로 reducedMotion 변화 즉시 반영 (사용자가 OS 토글 시 라이브 반응).

---

## 작업 순서

1. **Phase A** (SCSS 12건) — 독립적이고 영향 최소.
2. **Phase B** (dvh 폴백 4건) — 한 줄 추가, 안전.
3. **Phase C** (TS 핫패스 4건) — 동작 무변경 비주얼 점검.
4. **Phase D** (reduced-motion 3건) — OS 토글로 검증.

각 Phase마다 `rtk tsc --noEmit` 실행.

---

## Critical Files

**SCSS**:
- `resource/scss/pages/_main.scss` (A-1 ~ A-6, B-1 ~ B-4)
- `resource/scss/pages/_sub.scss` (A-7 ~ A-12)

**TS**:
- `resource/ts/runtime/SubpageStarfieldRuntime.ts` (C-1, C-4, D-3)
- `resource/ts/pages/works/render/WorksSceneManager.ts` (C-2, D-2)
- `resource/ts/objects/main/Ground.ts` (C-3, D-1)

**참조 (수정 없음)**:
- `resource/ts/runtime/ResponsiveRuntime.ts` — `getSnapshot()`, `subscribe()`, `flags.reducedMotion`
- `resource/ts/app/ResizeSetup.ts:36-43` — 이미 250ms debounce된 resize 디스패처
- `resource/scss/abstract/_variables.scss:34-48` — 브레이크포인트 (sm:544, md:768, lg:1024, xl:1440)
- `resource/scss/base/_root.scss` — fluid 기반 토큰 (gutter, header-height 등)

---

## Verification

**SCSS (Phase A+B)**:
- DevTools 뷰포트를 1280 → 1024 → 768 → 543 → 375 순으로 토글
- main 페이지: story 첫 블록·stats가 ≤768에서 full-width 되는지, intro-action content-2가 ≤768에서 100% 되는지, clients items가 ≤544에서 1열 되는지, contact stage 패딩 변화 없는지
- sub 페이지: vision/mission/award/news/works 각 그리드가 단계적 컬럼 수 변화하는지, works gallery item이 ≤768에서 staggered 해제되는지
- iOS Safari (실제 또는 Xcode Simulator): main 페이지 스크롤 시 hero/who/portfolio 영역이 주소창 변동에 점프하지 않는지

**TS Phase C (시각 무변경)**:
- main 페이지 ground hover/scroll → 마우스 잔상 동일
- works 페이지 resize 드래그 burst → 카드 위치 동일, Performance 탭 scripting time 감소 확인
- subpage starfield → 별 위치/흐름 동일, resize 이후 한 박자 후 갱신 확인

**TS Phase D (reduced-motion)**:
- macOS 시스템 환경설정 → 손쉬운 사용 → "동작 줄이기" ON / OFF 토글
- 토글 직후 별 흐름·카드 transition·ground 잔상이 즉시 단순화/풀모션 복귀

**자동 검증**:
- `rtk tsc --noEmit` (각 Phase 후)
- `rtk npm run test`

---

## Out of Scope (의도적 제외)

씬 시각 동작 변경 위험 또는 인프라 대형 리팩터링이라 별도 plan으로:
- mobile에서 cloudCount/raymarching steps 강제 컷 (현 씬 밀도 변경)
- SCSS/TS breakpoint 상수 공유 refactor (양쪽 호출부 동시 수정 필요)
- `Device.isMobile` + viewport 조합으로 PerformanceProfile 재분류 (저-tier 분기 변동)
- `_drawer.scss`/`_footer.scss`/`_header.scss` 등 layout: 감사 결과 모두 정상 (mq(md/lg) max-width 방향 활용 잘 되어 있음)
- 기타 components의 borderline 케이스 (`_detail-prevnext.scss` max-width 40/45%, `_form.scss .no-filter-bar` lg-only column 등): 이미 mq 처리되어 있고 추가 sm 단계는 미세 조정 수준

전수 감사로 확인된 false positive (조치 불필요): drawer center grid (lg에서 column 정상), drawer gnb-sub/badge (md에서 hidden 정상), footer top (md에서 column 정상), prevnext 40% width (max-width 아님, intro card width: min(560px, calc) 자체가 모바일 대응).

# Plan: Works THEATRE=1 Author Mode — Orbit + Auto-Save Fix

## Context

`?THEATRE=1` (author mode)에서 Works 페이지만 orbit이 작동하지 않고 카메라 키프레임 자동저장도 안 된다.  
Main/About/Contact는 정상 동작. 근본 원인 2개를 확인했다.

---

## 조사 결과

### SCSS / author mode attribute — 이상 없음
- PHP 템플릿 (`views/layouts/main.php`)이 `?theatre=1`이면 `<html data-works-mode="author">` 를 서버사이드 렌더링.
- `html[data-works-mode="author"]` SCSS 블록: `.no-works-canvas__canvas` → `pointer-events: auto !important`, `#theatrejs-studio-root` → `pointer-events: auto !important; z-index: 10001`
- Main/About/Contact도 동일한 PHP 패턴. SCSS 수정 불필요.

### Main/About/Contact orbit 동작 방식
- `AppOrbitRuntime` → `engine.start(onUpdate, onRender)` where `onRender = () => orbitRuntime.update()`
- Author mode에서 `orbitRuntime.update()`는 `controls.update()` 호출을 skip (`if mode === author && bridge`) 
- 대신 `TheatreBridge._syncControlsToCameraState()` 가 Theatre bindValues 콜백에서 `controls.update()` 호출
- 그러나 `OrbitControls` r180은 마우스 드래그 이벤트 핸들러 내부(`_handleMouseMoveRotate`)에서 `this.update()`를 **직접 호출** — 따라서 루프 없이도 기본 orbit 작동

### Works orbit 문제 원인 ①: render loop에 `controls.update()` 없음
`WorksTheatreBridge.run()` line 263:
```typescript
engine.start(() => undefined, () => undefined);   // ← 두 콜백 모두 no-op
```
- OrbitControls 내부 이벤트에서 `update()` 호출하므로 드래그 자체는 작동할 수 있으나,  
  마우스 릴리즈 후 damping 애니메이션이 없음
- Main/About/Contact 패턴(controls.update in render loop)과 불일치

### Works 자동저장 문제 원인 ②: `_recordFrame` — 이미 수정됨
이전 세션에서 수정 완료:
```typescript
// 수정 전 (broken): 모든 Theatre props 덮어씀
scrub.capture(({ set }) => { set(object.props, values); });

// 수정 후 (correct): camera만 기록
(scrub as unknown as WorksTheatreScrubCameraPort).capture(({ set }) => {
  set(object.props.camera, values.camera);
});
```

---

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `resource/ts/pages/works/theatre/WorksTheatreBridge.ts` | `engine.start()` render 콜백에 `controls.update()` 추가 |

---

## 변경 상세

### `WorksTheatreBridge.ts` — `run()` 메서드 (line 263)

```typescript
// Before
engine.start(() => undefined, () => undefined);

// After
engine.start(() => undefined, () => {
  this._controls?.update();
});
```

**Why:** `this._controls`는 `engine.start()` 호출 이후 동기적으로 생성되므로, RAF가 처음 발사될 때 이미 세팅 완료. `?.` optional chaining으로 일시적 null 안전 처리.

---

## 검증

1. `rtk tsc --noEmit` — 타입 에러 없음
2. `?theatre=1`로 Works 접속 → orbit 드래그 확인 → 마우스 릴리즈 후 damping smooth 확인
3. orbit 드래그 중 Theatre.js 패널 timeline에 camera 키프레임 자동 기록 확인
4. Main/About/Contact 정상 동작 유지 확인 (이번 변경은 Works만 영향)

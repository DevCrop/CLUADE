# Plan: about-proof-canvas 스크롤 도달 시 렉 제거

## Context

`about-proof-canvas` 섹션에 스크롤로 도달하면 눈에 띄는 프레임 드롭이 발생한다.
earth 섹션은 동일 조건에서 렉이 없다.

## 진단

### 렉의 정확한 원인: Shader 컴파일 지연

`AboutProofRenderer.init()` 는 페이지 로드 시 실행되어 다음을 완료한다:
- WebGL renderer / scene / camera 생성
- API 호출 + 12개 텍스처 로드 (`Promise.all`)
- 카드 Geometry + 각 카드당 `MeshBasicMaterial` 생성

단, Three.js의 실제 **GPU shader 컴파일**은 `renderer.render()` 첫 호출 시점에 발생한다.  
카드 Material에는 `onBeforeCompile` (UV flip 패치)이 붙어 있어 shader 변형 컴파일이 추가로 일어난다.

`IntersectionObserver` 가 canvas를 viewport에서 감지하면 `_startRaf()` → RAF → `renderer.render()` 첫 호출.  
→ 이 순간 12개 카드 material + 행성 atmospheric shader 전부 동시에 GPU 컴파일 → **frame stall**.

earth는 main Engine 파이프라인 안에서 초기화되므로 메인 씬 컴파일 시점에 함께 컴파일 완료. 스크롤 도달 시 이미 warm 상태.

### 왜 init()이 느리게 느껴지지 않는가?

`AboutPageRuntime.init()` 에서 proof / gallery 초기화는 **순차** await:
1. `await this._appManager.run(...)` — 메인 씬
2. `await this._proofRenderer.init(canvas)` — proof (텍스처 로드는 비동기라 기다리지만 shader 컴파일은 없음)
3. `await this._galleryRenderer.init(canvas)` — gallery

페이지 로드 시 GPU stall 없이 조용히 끝난다. 문제는 첫 렌더 시점에 터진다.

## 수정 계획

### Fix 1 — `renderer.compile()` 추가 (핵심)

**파일**: `resource/ts/pages/about/render/AboutProofRenderer.ts`  
**위치**: `init()` 내 `this._syncSize()` 직후, `this._observeVisibility()` 직전 (라인 237–239 사이)

```typescript
// 모든 mesh/material이 scene에 추가된 뒤 shader를 지금 컴파일
if (this._renderer && this._scene && this._camera) {
  this._renderer.compile(this._scene, this._camera);
}
```

`renderer.compile()` 은 scene 내 모든 material의 shader를 즉시 GPU에 컴파일한다.  
이후 첫 `renderer.render()` 호출 시 컴파일 비용이 0 → 스크롤 도달 시 렉 없음.

### Fix 2 — proof + gallery init 병렬화 (보조)

**파일**: `resource/ts/pages/about/runtime/AboutPageRuntime.ts`  
**위치**: 라인 30–50 (proof/gallery 초기화 블록 전체)

현재 순차:
```
await proofRenderer.init()   // ~시간A
await galleryRenderer.init() // ~시간B  (총 A+B)
```

변경 후 병렬:
```
await Promise.all([proofRenderer.init(), galleryRenderer.init()])  // max(A,B)
```

두 렌더러가 독립적인 WebGL context를 사용하므로 병렬 실행 안전.  
페이지 로드 시 네트워크 요청(API + 텍스처)이 동시에 나가 총 init 시간 단축.  
`registerProofProgressCallback` / `registerGalleryProgressCallback` 은 각 init 완료 직후 `.then()` 체인으로 등록.

## 수정 대상 파일

| 파일 | 변경 내용 |
|------|----------|
| `resource/ts/pages/about/render/AboutProofRenderer.ts` | `init()` 라인 237–239 사이 `renderer.compile()` 1줄 추가 |
| `resource/ts/pages/about/runtime/AboutPageRuntime.ts` | proof/gallery init 블록을 `Promise.all` 병렬 구조로 리팩터 |

## 검증

1. `rtk tsc --noEmit` — 타입 오류 없음 확인
2. 브라우저에서 about 페이지 열기 → proof-canvas 섹션까지 스크롤 → 렉/frame drop 없음 확인
3. 페이지 재로드 후 gallery 섹션도 동일 확인

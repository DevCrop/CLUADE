# Context

MAIN 페이지 GPU/CPU 과부하 분석 및 최적화 계획.
이전 세션에서 ABOUT 페이지 최적화 완료 → 동일 방법론으로 MAIN 페이지 적용.
구현 100% 완료 기준.

---

# MAIN 페이지 GPU/CPU 부하 분석 & 최적화 플랜

## 수정 파일 목록
| 파일 | 종류 |
|---|---|
| `resource/ts/core/PostProcessor.ts` | CPU |
| `resource/ts/pages/main/scene/main.scene.ts` | CPU |
| `resource/ts/objects/main/Ground.ts` | CPU |
| `resource/shaders/background/main/hero.fragment.glsl` | GPU |
| `resource/shaders/post-processing/global-cloud-overlay.fragment.glsl` | GPU |
| `resource/shaders/cloud-plane/cloud-plane.fragment.glsl` | GPU |

---

## 🔴 CRITICAL

### 1. PostProcessor.ts — 렌더 루프 내 console.log 2개 제거
- **위치:** `PostProcessor.ts:220`, `PostProcessor.ts:274`
- **내용:**
  - L220: `console.log('[BLOOM:render] hasRoots changed...')` — hasRoots 전환마다 발동
  - L274: `console.log('[BLOOM:darken] depthOff mesh...')` — bloom 패스마다 depthOff mesh 수만큼 발동
- **영향:** console.log는 devtools lock 획득 + 포맷팅 → 렌더 루프 안에서 호출 시 프레임당 수십 ms 소실
- **수정:** 두 console.log 라인 완전 제거

---

### 2. main.scene.ts — DOM querySelector state check 이전 이동 + ref 캐싱

현재 `syncWhoScene`, `syncWorksDetailHead`, `syncClientItems`, `syncContactHead` 4개 함수가 모두:
**DOM 쿼리 실행 → 그 다음에 state guard check** 순서로 되어 있어, 상태 변화 없을 때도 매 progress 이벤트마다 쿼리 실행.

#### 2-A. `syncWhoScene` (L176-203)
- **문제:** L177-179 `querySelectorAll(WHO_TEXT_SELECTOR)` 후 L183 state check
- **수정:**
  - 모듈 레벨에 `let _whoTextItems: HTMLElement[] | null = null` 캐시
  - 첫 호출 시 한 번만 쿼리 → 이후 재사용
  - state check를 쿼리 이전으로 이동: L182 shouldShow 계산 → L183 guard → 그 다음 element 접근

#### 2-B. `syncWorksDetailHead` (L218-271)
- **문제:** L219 `querySelector`, L221-222 `querySelectorAll` 후 L228 state check
- **수정:**
  - `let _worksDetailHeadEl: HTMLElement | null = null` 캐시 (isConnected 체크 포함)
  - `_worksDetailHeadTextItems: HTMLElement[] | null = null` 캐시
  - state check 먼저, 그 다음 element 참조

#### 2-C. `syncClientItems` (L359-391)
- **문제:** L360-362 `querySelectorAll(CLIENT_ITEM_SELECTOR)` 후 L367 state check
- **수정:**
  - `let _clientItems: HTMLElement[] | null = null` 캐시
  - shouldShow 계산 + state check → items 참조 순서로 재배치

#### 2-D. `syncContactHead` (L408-529)
- **문제:** L409-411 `querySelector` 3개 + L413-418 `querySelectorAll` 2개 → 합계 5개 쿼리, 그 후 L421 shouldShow
- **수정:**
  - `let _contactSectionEl`, `_contactHeadEl`, `_contactActionsEl` 캐시 (isConnected 패턴)
  - `_contactTextItems`, `_contactActionItems` 캐시
  - shouldShow 체크를 먼저, 실제 element 사용은 실제 변화 시에만

#### dispose 함수 처리
- 각 dispose 함수에서 캐시된 ref를 `null` 로 리셋 (DOM 제거 후 dangling ref 방지)

---

### 3. hero.fragment.glsl — raymarch 75→57 이터레이션
- **위치:** `resource/shaders/background/main/hero.fragment.glsl:118-121`
- **현재:**
  ```glsl
  MARCH(25, map4);  // 4-octave noise × 25 steps
  MARCH(20, map3);  // 3-octave noise × 20 steps
  MARCH(15, map2);  // 2-octave noise × 15 steps
  MARCH(15, map2);  // 동일 함수 중복 × 15 steps
  ```
  총 75 스텝. 두 번째 map2 패스는 동일 LOD 함수 중복.

- **수정:**
  ```glsl
  MARCH(20, map4);  // 25 → 20
  MARCH(15, map3);  // 20 → 15
  MARCH(22, map2);  // 15+15=30 → 22 (두 패스 통합)
  ```
  총 57 스텝 (24% 감소). `sum.a > 0.99` early-exit이 밀도 높은 구간에서 자연스럽게 절사.

---

## 🟠 HIGH

### 4. global-cloud-overlay.fragment.glsl — rotateUV 상수 inline + god rays 범위 외 skip

#### 4-A. rotateUV 상수 회전 inline
- **위치:** `global-cloud-overlay.fragment.glsl:34, 42` (회전각 0.3, -0.04 — 상수)
- **현재:** `rotateUV()` 호출마다 `cos/sin` 연산 (각 2회) → 3 rotateUV 호출 = 최대 12 trig op
- **수정:**
  - 회전각이 상수인 L34, L42 두 호출: cos/sin 값을 상수로 inline
    - `cos(0.3) = 0.9553`, `sin(0.3) = 0.2955`
    - `cos(-0.04) = 0.9992`, `sin(-0.04) = -0.03999`
  - L68 god rays 회전 (`0.1 + 0.1 * uChapter`): 동적이므로 `main()` 시작부에서 1회만 계산해 재사용

#### 4-B. god rays early exit
- **위치:** `global-cloud-overlay.fragment.glsl:69-77`
- **내용:** god rays는 `uChapter ∈ [2.4, 3.0]` 구간에서만 가시적 (L74-75 smoothstep)
- **수정:** uChapter 범위 외에서 2 texture sample + 복잡 연산 전체 skip
  ```glsl
  float godrayMask = smoothstep(2.4, 2.7, uChapter) * smoothstep(3.0, 2.9, uChapter);
  if (godrayMask > 0.001) { /* god rays 연산 */ }
  ```

---

### 5. Ground.ts — `_updateResolution()` resize-dirty 캐싱
- **위치:** `resource/ts/objects/main/Ground.ts:406-419`
- **현재:** 매 프레임 `ResponsiveRuntime.getDefault().getSnapshot()` 호출 → viewport 변화 없어도 실행
- **수정:**
  - `private _resolutionDirty = true` 플래그 추가
  - ResizeObserver 또는 `ResponsiveRuntime` 변경 구독에서 `_resolutionDirty = true` 설정
  - `_updateResolution()` 내 `if (!this._resolutionDirty) return;` 조기 리턴
  - 업데이트 후 `_resolutionDirty = false`

---

## 🟡 MEDIUM

### 6. cloud-plane.fragment.glsl — guillotine 종속 텍스처 범위 외 skip + cloudShape sin 근사

#### 6-A. guillotine 종속 텍스처 early skip
- **위치:** `cloud-plane.fragment.glsl:58-60`
- **현재:**
  ```glsl
  float guillotine = smoothstep(2.3, 2.2, uChapter - 0.3 * sUv.y + 0.1 * (
      texture2D(tNoise, guillotineUv + 0.02 * texture2D(tNoise, 4.0 * guillotineUv).r).r - 0.5));
  ```
  종속 텍스처 읽기 2개가 항상 실행. uChapter < 2.1이면 결과는 항상 1.0, uChapter > 2.4이면 항상 0.0.
- **수정:**
  ```glsl
  float guillotine;
  if (uChapter < 2.1) {
      guillotine = 1.0;
  } else if (uChapter > 2.4) {
      guillotine = 0.0;
  } else {
      guillotine = smoothstep(2.3, 2.2, uChapter - 0.3 * sUv.y + 0.1 * (
          texture2D(tNoise, guillotineUv + 0.02 * texture2D(tNoise, 4.0 * guillotineUv).r).r - 0.5));
  }
  ```
  uChapter는 uniform → 전체 워프 동일 분기 → divergence 없음.

#### 6-B. cloudShape sin 3개 → triangle wave 근사
- **위치:** `cloud-plane.fragment.glsl:53`
- **현재:** `abs(sin(fUv.x * 50.0 + offset))` 등 sin 3회 호출
- **수정:** `abs(sin(x)) ≈ abs(fract(x * 0.15915) * 2.0 - 1.0)` (triangle wave, fract는 sin보다 저렴)
  ```glsl
  float cloudShape = (
      -0.01 * abs(fract((fUv.x * 50.0 + offset) * 0.15915) * 2.0 - 1.0)
      -0.03 * abs(fract((fUv.x * 15.0 + offset) * 0.15915) * 2.0 - 1.0)
      -0.02 * abs(fract((fUv.x * 17.0 + offset) * 0.15915) * 2.0 - 1.0)
  ) * count;
  ```

### 7. Ground.ts — `_resolveShaderColors()` 변경 시에만 실행
- **위치:** `resource/ts/objects/main/Ground.ts:397-404`
- **현재:** `_syncShaderUniforms()` 내부에서 매 프레임 `setHex()` 3회 호출
- **수정:** 마지막으로 설정한 hex 값 3개를 캐시, 값이 변경됐을 때만 setHex 실행

---

## 우선순위 요약

| 등급 | 파일 | 항목 | 예상 효과 |
|------|------|------|----------|
| 🔴 | PostProcessor.ts | console.log 2개 제거 | 렌더 루프 수십ms 회복 |
| 🔴 | main.scene.ts | DOM 쿼리 5함수 캐싱 | scroll 당 쿼리 0으로 |
| 🔴 | hero.fragment.glsl | raymarch 75→57 | -24% GPU |
| 🟠 | global-cloud-overlay.glsl | rotateUV inline + god rays skip | -8% GPU fullscreen |
| 🟠 | Ground.ts | resize-dirty 캐싱 | -1ms/frame CPU |
| 🟡 | cloud-plane.glsl | guillotine skip + sin 근사 | -5% GPU |
| 🟡 | Ground.ts | color cache | 소폭 CPU |

---

## 검증

- `rtk tsc --noEmit` — TS 에러 없음
- `http://localhost:8888` 메인 페이지 스크롤 → 전 섹션 시각 회귀 없음
- DevTools Performance 탭 → bloom 렌더 패스에서 console.log 사라짐 확인

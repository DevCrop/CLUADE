# Plan: Countdown 3→2→1 리타이밍 + fly-away 단축

## Context

현재 메인페이지 introAction 섹션에서:
- 카운트다운이 5→4→3→2→1 (5자리, 6.9s)으로 진행됨
- Phase Two에서 rocket(Theatre.js) + story text(content-1,2)가 병렬 실행
- story text는 총 ~7.38s, rocket Phase Two는 ~22s → 텍스트가 끝나고 14s의 dead time 발생
- 유저 요청: 카운트다운을 3,2,1로 줄이되 각 숫자의 노출 시간은 늘리고, fly-away는 단축

## 타이밍 설계 (인간 시청 기준)

**카운트다운 per-digit 목표:** ~1.92s/digit (현재 1.38s → 40% 증가)
- "3" → enter 0.38s → hold 1.1s → exit 0.30s → gap 0.14s
- 숫자 하나당 텍스트를 "인식하고 카운트를 느끼는" 시간: 1.1s hold (현재 0.62s의 1.77배)
- 총 카운트다운: 3 × 1.92s = **5.76s**

**Phase Two 목표 wall time: 9s** (현재 22s → 2.4× 단축)
- story text 종료: 0.58 + 3.4 + 3.4 = 7.38s
- rocket exit 마진: 1.62s (텍스트 사라진 뒤 로켓이 빠르게 빠져나감)
- MAIN_INTRO_ACTION_PHASE_TWO_RATE = (10 - 1.633) / 9 ≈ 0.930 (현재 ~0.38)

**orbit CSS animation duration:** 1.38s → 1.92s (per-digit 주기와 동기화)

## 변경 파일 3개

### 1. resource/ts/config/intro.config.ts (lines 79-91)
```ts
// 변경 전
values: ["5", "4", "3", "2", "1"] as const,
enterDuration: 0.34,
holdDuration: 0.62,
exitDuration: 0.28,
gapDuration: 0.14,

// 변경 후
values: ["3", "2", "1"] as const,
enterDuration: 0.38,
holdDuration: 1.1,
exitDuration: 0.30,
gapDuration: 0.14,
```

### 2. resource/ts/pages/main/theatre/MainTheatreConfig.ts (lines 35-37)
```ts
// 변경 전
/** … Target ~22s so story text stays readable. */
MAIN_INTRO_ACTION_PHASE_TWO_RATE = (10 - MAIN_INTRO_ACTION_PHASE_SPLIT_POSITION) / 22;

// 변경 후
/** … Target ~9s: story text ≈7.4s + ~1.6s rocket exit margin. */
MAIN_INTRO_ACTION_PHASE_TWO_RATE = (10 - MAIN_INTRO_ACTION_PHASE_SPLIT_POSITION) / 9;
```

### 3. resource/scss/pages/_main.scss (line 276)
```scss
/* 변경 전 */
animation: no-intro-countdown-orbit-pulse 1.38s linear infinite;

/* 변경 후 */
animation: no-intro-countdown-orbit-pulse 1.92s linear infinite;
```

## 검증

- `rtk tsc --noEmit` (타입 에러 없어야 함 — 값 타입 변경)
- 브라우저 `localhost:8888` 에서 메인페이지 직접 확인:
  - 카운트다운: "3" → "2" → "1" 각 약 1.9s씩 노출
  - orbit 링 펄스가 digit 주기와 동기화
  - Phase Two: story text 끝난 직후 로켓이 빠르게 퇴장 (~1-2s 이내)
  - skip 버튼 동작 정상 확인

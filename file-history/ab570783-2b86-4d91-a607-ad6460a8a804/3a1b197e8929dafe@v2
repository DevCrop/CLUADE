---
name: SCSS 핵심 규칙 + 함수 시그니처
description: var(--token,fallback) 금지, fluid/mq 내부 함수 시그니처, 레이어 우선순위, 브레이크포인트
type: project
originSessionId: 940f3c69-ab68-40c4-809f-8acca066cc76
---

# SCSS 핵심 규칙 + 함수 시그니처

## 금지 규칙

- `var(--token, fallback)` **금지** — fallback 없이 `var(--token)` 직접 사용. 토큰 없으면 `_root.scss`에 추가.
- `0값` 중복 선언 금지 — `base/_init.scss`에 이미 처리됨.

## fluid / mq 시그니처 (`resource/scss/abstract/`)

```scss
// _functions.scss
fluid($y1, $y2, $x1: 375, $x2: 1920)  // → clamp(min, vw+base, max)
minus-fluid(...)                        // 음수 버전
pxToRem($px)                           // $px * 0.1rem  (35 → 3.5rem)

// _mixins.scss
@include mq($key-or-size, $direction: "max")   // max-width
@include mq-min($key)                          // min-width
@include font("ds-heading-1")                  // fluid 타이포 적용
```

## 레이어 우선순위

`reset < base < layout < components < pages < utilities < state`

## 브레이크포인트 (mq key → px)

`xs:375 / sm:544 / md:768 / lg:1024 / xl:1440 / 2xl:1640 / 3xl:1920`

**Why:** fluid/mq는 내부 함수라 공식 문서가 없고, `var(--token, fallback)` 금지는 AGENTS.md에 있지만 놓치기 쉬운 실수.
**How to apply:** 반응형 = `@include mq(key)`. fluid 크기 = `fluid(min, max)`. 토큰 사용 시 fallback 절대 붙이지 않음.

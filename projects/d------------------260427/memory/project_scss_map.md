---
name: SCSS core rules + function signatures
description: var(--token, fallback) forbidden, fluid/mq internal function signatures, layer priority, breakpoints
type: project
originSessionId: 940f3c69-ab68-40c4-809f-8acca066cc76
---

# SCSS core rules + function signatures

## Forbidden

- `var(--token, fallback)` is **forbidden** — use `var(--token)` directly with no fallback. If a token is missing, add it to `_root.scss`.
- Do not redeclare `0` values — already handled in `base/_init.scss`.

## fluid / mq signatures (`resource/scss/abstract/`)

```scss
// _functions.scss
fluid($y1, $y2, $x1: 375, $x2: 1920)  // → clamp(min, vw+base, max)
minus-fluid(...)                        // negative variant
pxToRem($px)                           // $px * 0.1rem  (35 → 3.5rem)

// _mixins.scss
@include mq($key-or-size, $direction: "max")   // max-width
@include mq-min($key)                          // min-width
@include font("ds-heading-1")                  // applies fluid typography
```

## Layer priority

`reset < base < layout < components < pages < utilities < state`

## Breakpoints (mq key → px)

`xs:375 / sm:544 / md:768 / lg:1024 / xl:1440 / 2xl:1640 / 3xl:1920`

**Why:** `fluid` / `mq` are internal helpers with no public docs, and the `var(--token, fallback)` ban — although stated in AGENTS.md — is an easy mistake to repeat.
**How to apply:** Responsive sizing = `@include mq(key)`. Fluid scale = `fluid(min, max)`. When using a token, never attach a fallback.

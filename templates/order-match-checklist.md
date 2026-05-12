# Order Match Verification

> Mandatory before declaring a task done. Fill every section. Do not skip the evidence column — "looks fine" is not evidence.

## 1. Order (verbatim)

```
<paste the user's exact request here, including quoted Korean and any constraints>
```

## 2. Acceptance Criteria

| # | Criterion (observable state) | Evidence (file:line / command output / test result) | Pass |
|---|---|---|---|
| 1 |  |  | [ ] |
| 2 |  |  | [ ] |
| 3 |  |  | [ ] |

## 3. Scope Creep Check

- Was anything modified outside the order?
  - [ ] No
  - [ ] Yes — list each: <files / changes>
- For each yes: justification or revert plan: <…>

## 4. Constraint Compliance

| Constraint | Status |
|---|---|
| Language: Korean for chat / English for AI artifacts | [ ] |
| Paths: `%USERPROFILE%\.claude\` — no `D:\.claude` references | [ ] |
| Tools: only those user authorized | [ ] |
| No banned actions (force push, hard reset, secrets, `--no-verify`) | [ ] |
| Vanilla / FOMO guard: any new feature has documented incident or measurable benefit | [ ] |

## 5. Verdict

- [ ] **COMPLETE** — every criterion has evidence, no scope creep, all constraints honored.
- [ ] **INCOMPLETE** — gaps:
  - <criterion N>: <reason / next step>

If INCOMPLETE: do not say "done". Either complete the gaps or report them explicitly to the user.

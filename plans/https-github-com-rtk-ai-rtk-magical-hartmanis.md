# RTK 설정 검증 및 개선 플랜

## Context

사용자가 RTK가 제대로 타고 있는지 의심. 공식 GitHub(README_ko.md + README.md) 확인 결과,
현재 아키텍처는 **공식 문서 기준 올바름**. 문제는 설정이 아니라 **Claude의 적용 일관성(42% 채택률)**.

---

## 현재 상태 (공식 문서 대조 결과)

| 항목 | 공식 권장 (Windows native) | 현재 설정 | 상태 |
|---|---|---|---|
| Hook auto-rewrite | 미지원 (WSL 전용) | 미설치 | ✅ 정상 |
| CLAUDE.md injection mode | 권장 방식 | @RTK.md 포함 | ✅ 정상 |
| 수동 prefix | 유일한 방법 | RTK.md에 명시 | ✅ 정상 |
| RTK 버전 | - | v0.36.0 | ✅ 최신 |
| 세션 채택률 | 목표 90%+ | 평균 **42%** | ❌ 미달 |

**결론: 아키텍처는 정상. 문제는 Claude의 RTK prefix 적용 일관성.**

---

## 채택률 현황

`rtk session` 기준 오늘 세션들:

| 세션 | 전체 명령 | RTK 사용 | 채택률 |
|---|---|---|---|
| e27dfc38 | 22 | 12 | 55% |
| 8b7621d3 | 18 | 2 | **11%** ← 오늘 리뷰 세션 |
| c8517c76 | 119 | 51 | 43% |
| 평균 | - | - | **42%** |

목표: **90%+**

---

## 근본 원인

현재 RTK.md의 황금 룰:
> "Any Bash command whose output spans more than a few lines requires the `rtk` prefix."

이 규칙은 **판단이 필요** → Claude가 상황에 따라 적용을 누락함.

구체적으로 누락된 패턴:
- `ls <path>` → `rtk ls <path>` 미적용
- `cat <file>` → Read 툴 또는 `rtk read` 미적용
- `find` → `rtk find` 미적용

---

## 수정 계획

### 변경 파일
- `C:/Users/nineonelabs003/.claude/RTK.md`

### 변경 내용

황금 룰 아래에 **판단 불필요한 MUST 목록** 추가:

```markdown
## MUST Prefix (no judgment needed)

These commands ALWAYS require `rtk` prefix in Bash — regardless of expected output length:

| Command | Prefix form |
|---|---|
| ls, ls -la, ls -1 | `rtk ls <path>` |
| find | `rtk find "*.ext" <path>` |
| grep / rg | `rtk grep <pattern> <path>` |
| git status | `rtk git status` |
| git log | `rtk git log` |
| git diff | `rtk git diff` |
| git add / commit / push | `rtk git add / commit / push` |
| npm run / pnpm | `rtk npm run <script>` |
| tsc | `rtk tsc` |
| docker ps / logs | `rtk docker ps/logs` |
| curl (any) | `rtk curl <url>` |

Never use plain `cat` in Bash — use the Read tool or `rtk read`.
Never use plain `ls` in Bash — always `rtk ls`.
```

### 변경하지 않는 것
- `settings.json` — 훅 미설치 유지 (공식 문서상 Windows native 한계)
- `CLAUDE.md` — 현재 @RTK.md 참조로 충분
- Hook 설치 (`rtk init -g`) — WSL 전용, 이 환경에서 불필요

---

## 검증 방법

수정 후 다음 세션에서:
```bash
rtk session          # 채택률 확인 → 목표 90%+
rtk gain --daily     # 오늘 절감량 확인
```

채택률이 90% 미만이면 누락된 명령 패턴을 MUST 목록에 추가.

# RTK 자동화 — 멀티 AI 도구 커버리지 점검

## Context

사용자 워크플로우: Claude Code · Codex · Cursor 세 AI 도구 모두에서 작업.
질문: "내가 명령하면 AI가 자동으로 RTK 적용해서 토큰 절약하는가?"

답: **Claude Code 만 100% 자동, Codex / Cursor 는 텍스트 규칙 의존(반자동~수동)**. 이는 도구 자체의 hook 지원 여부 차이라 완전 자동화는 불가능. 다만 텍스트 규칙을 더 강하게 묶으면 AI 가 자발적으로 RTK 를 쓸 확률이 올라감.

---

## 도구별 현황

### ✅ Claude Code — 완전 자동

| 항목 | 위치 | 상태 |
|---|---|---|
| 글로벌 PreToolUse 훅 | [D:\.claude\settings.json:6-15](D:/.claude/settings.json#L6-L15) | `matcher: "Bash"` + `command: "rtk hook claude"` → 모든 Bash 명령 자동 재작성 |
| 프로젝트 권한 화이트리스트 | [.claude/settings.json](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/settings.json) | rtk·git·docker·npm 허용. 글로벌 hook 과 충돌 없음 |
| 텍스트 규칙 보강 | [CLAUDE.md](d:/최신프로젝트/나인원랩스/퍼블/260427/CLAUDE.md), [AGENTS.md](d:/최신프로젝트/나인원랩스/퍼블/260427/AGENTS.md) | RTK 사용 권고 명시 |

**보강 불필요.** 사용자가 `git status` 라고만 입력해도 Claude 가 hook 통해 `rtk git status` 로 자동 변환.

---

### ⚠️ Codex — 반자동 (hook 미지원, prefix_rule 만)

| 항목 | 위치 | 상태 |
|---|---|---|
| 명령 허가 룰 | [.codex/rules/default.rules:4-14](d:/최신프로젝트/나인원랩스/퍼블/260427/.codex/rules/default.rules#L4-L14) | `prefix_rule(pattern = ["rtk"], decision = "allow", ...)` — rtk 명령은 **허가**되지만 자동 재작성은 안 됨 |
| 비rtk 명령 처리 | [.codex/rules/default.rules:17-26](d:/최신프로젝트/나인원랩스/퍼블/260427/.codex/rules/default.rules#L17-L26) | `git status`, `git diff` 등이 **별도 prefix_rule 로 직접 허가** → AI 가 RTK 안 쓰고 raw 명령 그대로 실행할 가능성 큼 |
| hook 결정 | [AGENTS.md:60-61](d:/최신프로젝트/나인원랩스/퍼블/260427/AGENTS.md#L60-L61) | "Codex hooks intentionally omitted (disabled on Windows). Direct terminal commands not auto-wrapped — use `rtk <command>` explicitly." |
| 글로벌 codex 설정 | `~/.codex/` (확인 못함, 사용자 검증 필요) | 글로벌 hook 등록 가능성 미확인 |

**문제**: Codex 가 RTK 안 쓴 raw 명령을 자유롭게 쓸 수 있음. 룰은 "허가"만 하지 "재작성"은 안 함.

**보강안**:
1. **prefix_rule 우선순위 조정** — raw `git`/`docker`/`rg` 룰을 `decision = "prompt"` 로 바꿔 사용자에게 한 번 묻게 만들고, AGENTS.md 에 "Codex 가 묻거든 rtk prefix 붙여 답하라" 안내 추가. 단점: 자주 묻는 게 귀찮음.
2. **rules 파일 상단에 강제 지침 주석 추가** — Codex 가 매 세션 처음에 룰 파일을 읽으므로 "출력 노이즈가 큰 명령엔 rtk 프리픽스를 자발적으로 사용할 것" 코멘트가 동작 가이드 역할.
3. **글로벌 codex 설정 확인** — `~/.codex/config.toml` 또는 `D:\.codex\` 같은 글로벌 위치에서 prefix_rule 추가 가능한지 사용자 직접 검증.

---

### ⚠️ Cursor — 수동 (텍스트 규칙만, hook 아키텍처상 불가)

| 항목 | 위치 | 상태 |
|---|---|---|
| 핵심 규칙 | [.cursor/rules/project-core.mdc:14](d:/최신프로젝트/나인원랩스/퍼블/260427/.cursor/rules/project-core.mdc#L14) | "For verification, prefer the smallest relevant check: `rtk tsc --noEmit`, `rtk docker compose exec web php -l <file>`, and `rtk git diff`." — `alwaysApply: true` |
| 브랜드 규칙 | [.cursor/rules/brand-work.mdc](d:/최신프로젝트/나인원랩스/퍼블/260427/.cursor/rules/brand-work.mdc) | RTK 무관 |
| hook 시스템 | — | Cursor 는 도구 가로채기 hook 미지원 (구조적 한계) |
| 글로벌 ~/.cursor 룰 | (확인 못함, 사용자 검증 필요) | 글로벌 .cursorrules 또는 ~/.cursor/rules 가 있는지 |

**문제**: project-core.mdc 라인 14가 "verification 명령" 만 RTK 권고. 일반 `git status`, `docker compose logs` 등 일상 명령엔 RTK 강제 안 함.

**보강안**:
1. **project-core.mdc 룰 강화** — 라인 14를 verification 한정에서 "출력이 몇 줄을 초과할 모든 Bash 명령은 rtk 프리픽스" 같은 일반 규칙으로 확장. RTK.md 와 동일한 Golden Rule 인용.
2. **글로벌 ~/.cursor/rules/global.mdc 신설** — 사용자 홈에 RTK 글로벌 규칙 1개 두면 모든 Cursor 프로젝트에 적용. (Cursor 가 글로벌 룰 지원하는지 사용자 확인 필요)

---

## 변경 계획 (우선순위 순)

### 1. Cursor 룰 강화 — RTK 일반 규칙 명시

**파일**: [.cursor/rules/project-core.mdc:14](d:/최신프로젝트/나인원랩스/퍼블/260427/.cursor/rules/project-core.mdc#L14)

기존 verification 한정 권고를 일반 규칙으로 확장:

```markdown
- **RTK 프리픽스 (필수)**: 출력이 몇 줄을 초과할 모든 Bash 명령은 `rtk` 프리픽스 사용. 예: `rtk git status`, `rtk tsc --noEmit`, `rtk docker compose ps`. RTK 는 모르는 명령은 그대로 통과시키므로 항상 안전.
- 검증 표준 명령: `rtk tsc --noEmit`, `rtk docker compose exec web php -l <file>`, `rtk git diff`.
```

이펙트: Cursor 가 매 응답 전 이 룰을 읽으므로 RTK 사용 빈도 상승.

### 2. Codex 룰 헤더에 RTK 가이드 주석 추가

**파일**: [.codex/rules/default.rules:1-3](d:/최신프로젝트/나인원랩스/퍼블/260427/.codex/rules/default.rules#L1-L3)

```
# Repo-specific Codex execution rules for renew_nineonelabs.
# Drive policy: D: drive only. C: paths are forbidden — see AGENTS.md "Drive Policy".
# RTK policy: 출력이 많은 명령은 rtk 프리픽스 사용 (token-optimized). hook 미지원이므로 명령 작성 시 자발적으로 rtk 를 붙일 것. 모르는 명령은 그대로 통과시키므로 안전.
```

비파괴적 추가. 기존 prefix_rule 들은 유지 (rtk 안 붙어도 명령 실행은 가능해야 함 — 강제 차단은 워크플로우 깨짐).

### 3. AGENTS.md "Codex Notes" 섹션 보강

**파일**: [AGENTS.md:60-61](d:/최신프로젝트/나인원랩스/퍼블/260427/AGENTS.md#L60-L61)

기존:
```
See `.codex/config.toml` and `.codex/rules/default.rules`. Codex hooks intentionally omitted (disabled on Windows). Direct terminal commands not auto-wrapped — use `rtk <command>` explicitly.
```

추가:
```
즉, Codex/Cursor 사용자는 매 명령에 `rtk` 프리픽스를 직접 붙여야 함. Claude Code 사용자만 글로벌 hook 으로 자동 재작성됨.
```

이는 사람·AI 양쪽에 명확한 기대치를 설정.

### 4. (사용자 직접 검증) 글로벌 Codex/Cursor 위치 확인

확인할 것:
- `~/.codex/config.toml` — 글로벌 prefix_rule 등록 가능한지
- `~/.cursor/rules/` 또는 `~/.cursorrules` — 글로벌 룰 지원 여부

만약 지원하면 RTK 글로벌 가이드를 글로벌 위치에 두면 모든 프로젝트에 자동 적용.

---

## 변경하지 않을 것

- Claude Code 측 — 이미 hook 으로 100% 자동
- `.codex/rules/default.rules` 의 기존 prefix_rule — raw 명령도 허가되어야 디버깅 시 유연함. RTK 강제는 텍스트 가이드만으로 충분
- 글로벌 `D:\.claude\CLAUDE.md` — 이미 RTK 규칙 명시 + `@RTK.md` import 됨

---

## 검증 방법

1. **Cursor 룰 적용 후**: Cursor 에서 새 채팅 열어 "git status 보여줘" 같은 일상 명령 입력. 모델이 `rtk git status` 로 답하면 룰 적용 성공.
2. **Codex 룰 적용 후**: Codex 세션 시작하고 "프로젝트 빌드 상태 확인해줘" 같은 광범위 명령 입력. 모델이 `rtk tsc --noEmit` 같은 RTK 프리픽스 명령을 자발적으로 제안하는지 확인.
3. **사용자 직접 실행 권유**:
   - `rtk init --show` — 어떤 AI 도구 통합이 활성인지 확인
   - `rtk gain` — 토큰 절약 누적 통계 (Claude 사용분이 대부분일 것)

---
name: 세션 운영 룰 (course-correct / context / parallel)
description: Claude Code best practices 의 세션 운영 패턴 — 두 번 실패 시 /clear, 컨텍스트 위생, 병렬 explorer 호출
type: feedback
originSessionId: 640f6a38-20ef-4a8d-ab1b-a58e4414a23a
---
이 프로젝트의 세션 운영 룰. `.claude/BEST_PRACTICES.md` Part B에 정식 문서화돼 있고, 메모리는 그 요약.

**Course-correct 프로토콜:**
- 1차 실패 → 즉시 수정 prompt
- 2차 실패 → `Esc Esc` 또는 `/rewind` (수정 반복 금지)
- 3차 이상 → `/clear` 후 더 구체적 prompt 로 재시작

**Context 위생:**

- `/clear` = 가장 큰 단일 토큰 절약 레버. 무관 작업 전환 시 의도적으로 사용 — 캐시를 끊어 다음 세션 초기 컨텍스트 크기를 최소화함
- 500라인 이상 파일·열린 탐색 → `$scene-explorer` (Three.js) / `$php-explorer` (PHP) / Explore subagent 위임
- 탐색 범위 불확실 / 파일 수 미상 → 파일 크기와 무관하게 즉시 explorer 위임 (메인 컨텍스트 오염 방지가 목적)
- 한 작업이 컨텍스트를 덮으면 `/compact <focus>` 사용
- PostToolUse tsc hook 신뢰 — 수동 재실행 금지

**병렬 처리:**
- 독립 탐색 2건 이상 → 단일 메시지에서 서브에이전트 동시 호출
- 위험 변경 → Writer/Reviewer 세션 분리 (구현 세션 ↔ 리뷰 세션)
- 1~2 tool call 로 끝나는 작업은 서브에이전트 안 씀

**Why:** 사용자가 2026-04-25 Claude Code 공식 best practices 점검 시 "적극적 개입·컨텍스트 관리·병렬 처리" 영역이 문서화 안 돼 있던 갭을 보강함. 본 룰은 토큰 효율과 디버깅 회복 속도 양쪽에 직결.

**How to apply:**
- 매 응답마다 자가점검 — 같은 실수 두 번이면 `/rewind` 또는 `/clear` 권유
- 사용자가 큰 파일 열어달라 요청 → 먼저 explorer 위임 제안
- 독립 작업이면 항상 병렬 tool call

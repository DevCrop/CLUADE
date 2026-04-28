---
name: RTK token optimization — mandatory prefix
description: All Bash commands prefer `rtk` prefix; full policy in ~/.claude/RTK.md
type: feedback
originSessionId: f4145fdf-c8cb-416a-b0d7-4afed60e2439
---
RTK 정책 단일 출처: `~/.claude/RTK.md` (글로벌). 프로젝트 필터: `.rtk/filters.toml`.

**Why:** 노이즈 큰 명령(git/tsc/docker/test/find/log)을 압축해 컨텍스트 60-90% 절감.

**How to apply:**
- WSL Remote: PreToolUse hook이 자동 prefix
- Native Windows: 명시 `rtk <cmd>` prefix 필수
- 파일 읽기는 항상 Read tool — `cat/head/tail/rtk read` 금지
- 검증: `rtk gain` (카운터 0이면 미호출)

**History:** CHOP은 2026-04-25 완전 제거됨. 글로벌 settings의 chop hook도 2026-04-27 정리.

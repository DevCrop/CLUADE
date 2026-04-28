# Claude Code 100% 자동화 하네스 강화 플랜

## Context

**왜 지금 이 변경인가**
현재 셋업은 SessionStart 4-step / SessionEnd cleanup / PreToolUse RTK / 프로젝트 tsc PostToolUse / MEMORY 11-토픽 분리 / 14-항목 SETUP_CHECKLIST 까지 견고한 기초를 갖췄다. 그러나 시니어 AI 하네스 관점에서 세 가지 결정적 갭이 있다:

1. **공식 hook event 6종(`PostToolUse`·`UserPromptSubmit`·`Stop`·`SubagentStop`·`PreCompact`·`PostCompact`) 전부 비어있음** → 코드 수정 후 docs drift, 콤팩션 후 메모리 손실, 세션 종료 시 토큰 미집계가 모두 수동 의존.
2. **1시간 prompt cache 미사용** → 장시간 세션의 토큰 비용이 RTK 절감(60-90%)에도 불구하고 여전히 prefix 재처리에 누수.
3. **문서 drift 자동 감지 부재** → 공식 docs 변경(check-updates-worker가 SHA diff까지만 함)이 CLAUDE.md/AGENTS.md/BEST_PRACTICES.md 영향 섹션과 연결되지 않음.

**의도된 결과**: Claude 단독 100% 자동화 (다른 AI 모델은 수동 prefix 유지) — hook 결정적 자동화 + prompt cache + 문서 자동 동기화 + 메모리 견고화. RTK·MEMORY 토픽 분리·D 드라이브 정책은 **불변 자산**으로 유지.

---

## 설계 원칙 (불변)

1. **공식 hook event / settings key만 사용** — schema 변경 자동 흡수.
2. **Async-default**, blocking은 correctness-critical일 때만. SessionStart latency `<100ms` 사수.
3. **Idempotent + 재진입 가드** (`$env:CLAUDE_HOOK_DEPTH ≥ 2`면 즉시 exit 0) — hook 무한루프 방지.
4. **Prefix-stable, suffix-volatile** — 1h cache 깨지지 않게 동적 컨텍스트는 prompt 끝 블록에만.
5. **검증된 자산 동결**: [session-start.ps1](D:/.claude/hooks/session-start.ps1) 4-step / [cleanup.ps1](D:/.claude/cleanup.ps1) 보관 정책 / RTK PreToolUse / 프로젝트 tsc PostToolUse / MEMORY 11-토픽 / [permissions.deny](D:/.claude/settings.json) 8개.

---

## 결정 사항 (사용자 확인 완료)

| 항목 | 결정 |
|---|---|
| 범위 | **P0 + P1** 구현, P2는 후속 확장 항목으로 명시만 |
| 1h prompt cache | **켬** + suffix-only 동적 주입 + 룰 변경 시 `prefix-version.txt` bump 자동 invalidate (P1) |
| UserPromptSubmit | **Skip-when-clean** 패턴 — `git status --porcelain` 결과 빈 줄이면 PowerShell 호출 자체 회피 |
| MCP 활성화 | **비활성 유지** — `enabledMcpjsonServers: []` 명시(의도 명확화). 나중에 확장 |

---

## P0 — Day 1-2 (즉시 효과)

### P0-1. 1h prompt cache 활성화
- **Where**: [D:\.claude\settings.json](D:/.claude/settings.json) `env` 섹션
- **What**: `"ENABLE_PROMPT_CACHING_1H": "1"` 추가
- **Risk**: 1시간 동안 stale rule 박힐 수 있음 → P1-3의 `prefix-version.txt` invalidate로 보완

### P0-2. Stop hook → 토큰 사용량 자동 리포팅
- **Where**: 신규 [D:\.claude\hooks\token-report.ps1](D:/.claude/hooks/token-report.ps1), settings.json `Stop` 등록
- **What**: `rtk gain --session --json` → `D:\.claude\reports\token-usage.md` 일별 표 append (date heading idempotent). 7일 baseline 대비 5% 회귀 시 stderr 경고
- **Reuse**: 기존 [check-updates.ps1](D:/.claude/hooks/check-updates.ps1)의 24h gate 패턴 + UTF-8 인코딩 헤더 패턴

### P0-3. PreCompact / PostCompact hook
- **Where**: 신규 [D:\.claude\hooks\precompact-snapshot.ps1](D:/.claude/hooks/precompact-snapshot.ps1), [D:\.claude\hooks\postcompact-verify.ps1](D:/.claude/hooks/postcompact-verify.ps1)
- **What**:
  - `PreCompact`: MEMORY.md + 11 토픽 + 활성 plan 파일을 hard-link로 `D:\.claude\backups\precompact-<sessionId>\` 스냅샷 (디스크 cost ≈ 0)
  - `PostCompact`: import 체인(`@D:\.claude\CLAUDE.md` → 토픽 파일들) 재검증, 깨진 link 시 stderr로 Claude에 자동 경고
- **Reuse**: [cleanup.ps1](D:/.claude/cleanup.ps1)의 backups 회수 정책에 8주 보관 추가

### P0-4. UserPromptSubmit (Skip-when-clean)
- **Where**: 신규 [D:\.claude\hooks\inject-runtime-ctx.ps1](D:/.claude/hooks/inject-runtime-ctx.ps1)
- **What**: 진입 즉시 `git status --porcelain` 1줄 체크. 빈 결과면 `exit 0` (PowerShell 본체 로직 X). 변경 있을 때만 `git status` + `git log -3 --oneline`을 `<context-runtime>...</context-runtime>` **suffix 블록**으로 stdout JSON 출력. 800ms 타임아웃
- **Critical**: prefix 절대 손대지 않음 (1h cache 보존)

### P0-5. AUTO 마크 패턴 확장
- **Where**: [D:\.claude\hooks\update-docs.ps1](D:/.claude/hooks/update-docs.ps1) 확장 + [d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\BEST_PRACTICES.md](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/BEST_PRACTICES.md), [SETUP_CHECKLIST.md](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/SETUP_CHECKLIST.md)에 마크 도입
- **What**: `Update-AutoSection` 함수 추가, `<!-- AUTO:HOOK-EVENTS-START/END -->`, `<!-- AUTO:SKILLS-START/END -->` 처리. settings.json hook event enumerate → AUTOMATION.md 즉시 동기화

### P0-6. SessionStart에 memory-lint 통합
- **Where**: 신규 [D:\.claude\hooks\memory-lint.ps1](D:/.claude/hooks/memory-lint.ps1), [session-start.ps1](D:/.claude/hooks/session-start.ps1) 5-step으로 확장
- **What**: 11개 토픽 파일 50ms 스캔. 깨진 `[text](path)` 링크·존재 X path·빈 섹션 감지 → `D:\.claude\session-env\memory-lint.txt` 1줄 요약. 기존 4-step 순서·idempotency 유지

### P0-7. 프로젝트 PostToolUse 매처 분리
- **Where**: [d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\settings.json](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/settings.json)
- **What**: 기존 단일 `Edit|Write` matcher를 3개로 분리
  - `.ts/.tsx` (기존 유지) → `rtk tsc --noEmit`
  - `.php` → `rtk docker compose exec web php -l <file>` (async)
  - `.scss` → `npx stylelint <file>` (async, dev-dep 검증 후)
  - `.test.ts(x)` → `rtk vitest run <file> --reporter=dot` (async)
- **Reuse**: 기존 Node stdin JSON 파싱 패턴 그대로

---

## P1 — Week 1-2 (자동화 견고화)

### P1-1. 글로벌 PostToolUse (drift detector)
- **Where**: 신규 [D:\.claude\hooks\drift-enqueue.ps1](D:/.claude/hooks/drift-enqueue.ps1), [drift-detect-worker.ps1](D:/.claude/hooks/drift-detect-worker.ps1)
- **What**: `Edit|Write` 매처로 변경 파일 path를 `D:\.claude\.drift-queue\` enqueue. worker가 5분 단위로 BEST_PRACTICES.md의 `<!-- DOC-REF: path/to/file#export -->` 마커와 export 시그니처 비교. 불일치 시 `D:\.claude\review-needed.md`에 섹션·파일·라인 append
- **별도 매처** `Bash` → `npm install|pip install|composer require` 패턴 감지 → `rtk audit --quick` 큐잉

### P1-2. check-updates-worker 영향 섹션 큐잉
- **Where**: [D:\.claude\hooks\check-updates-worker.ps1](D:/.claude/hooks/check-updates-worker.ps1) 확장
- **What**: 공식 docs SHA diff 발견 시 → 해당 doc 키워드(`hooks.md` → "hook", `memory.md` → "memory"·"import")로 CLAUDE.md/AGENTS.md grep → 매칭 섹션을 `review-needed.md`로 큐잉

### P1-3. Prefix-version invalidate hint (1h cache 보호)
- **Where**: [update-docs.ps1](D:/.claude/hooks/update-docs.ps1) + 신규 `D:\.claude\.docs-cache\prefix-version.txt`
- **What**: CLAUDE.md / 룰 파일 / AGENTS.md mtime 체크해서 변경 감지 시 prefix-version.txt bump. UserPromptSubmit hook이 첫 호출에서 이 값을 읽어 prompt suffix에 `<cache-bust v="N"/>` 1줄 주입 → 다음 prompt에서 cache invalidate
- **Risk**: 매 prompt 파일 stat 1회 — 무시 가능

### P1-4. statusLine v2 (OpenTelemetry 메타)
- **Where**: 신규 [D:\.claude\statusline.ps1](D:/.claude/statusline.ps1), settings.json `statusLine` 등록
- **What**: effort.level / `cache_read_input_tokens` / 토큰 baseline 대비 % 노출. JSON stdin 파싱

### P1-5. BEST_PRACTICES.md 토픽 분리 (조건부 로드)
- **Where**: [d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\rules\](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/rules/) 하위 또는 별도 디렉토리
- **What**: 6.2KB → `bp-frontend.md` / `bp-webgl.md` / `bp-php.md` / `bp-scss.md` 4분리. 각 파일 frontmatter `paths: ['resource/ts/**/*.ts']` 등으로 조건부 로드. 메인 BEST_PRACTICES.md는 인덱스(2KB 이하)만 유지
- **Reuse**: 기존 [.claude/rules/](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/rules/) 의 `paths:` frontmatter 패턴 (검증된 공식 스펙)

### P1-6. 주간 memory zip backup
- **Where**: [session-start.ps1](D:/.claude/hooks/session-start.ps1) backup 단계 추가, [cleanup.ps1](D:/.claude/cleanup.ps1) 회수 정책 확장
- **What**: ISO week 비교, 새 주차이면 `Compress-Archive` → `D:\.claude\backups\memory-YYYYWW.zip`. 8주 보관

### P1-7. MCP 의도 명시 (비활성 유지)
- **Where**: [d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\settings.json](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/settings.json)
- **What**: `"enabledMcpjsonServers": []` 명시 추가 (현재 키 자체가 없음 → 의도 불분명). 주석으로 "추후 확장 시 Figma/Notion 우선 검토" 메모

---

## P2 — 후속 확장 (이번에는 구현 X, 명시만)

| 항목 | 트리거 조건 |
|---|---|
| `/pr-prep` skill (git diff → PR body draft) | PR 생성 빈도 주 3회 이상 시 |
| stale memory 60일 검증 | 토픽 파일 누적 20개 초과 시 |
| skill description ≤1536자 lint | skill 5개 이상 운영 시 |
| MCP-in-hook (Notion 자동 동기화) | MCP 활성화 결정 시 |
| TaskCreated hook 연동 | 공식 GA 후 |

---

## 충돌·리스크 매트릭스

| 리스크 | 시나리오 | 완화책 |
|---|---|---|
| PowerShell 인코딩 | 한글 파일명/주석 ANSI 깨짐 | 모든 신규 ps1 첫 줄 `[Console]::OutputEncoding=[Text.Encoding]::UTF8`, `Out-File -Encoding UTF8` 강제. 기존 ASCII 분리자(`->`) 패턴 유지 |
| 비동기 worker 누수 | drift-detect-worker 등 백그라운드 누적 | worker 시작 시 `Get-Process powershell ... -like '*hooks*'` count > 5 면 즉시 exit. cleanup.ps1에 24h 이상 worker kill 추가 |
| Hook 무한루프 | PostToolUse(Edit) 내부에서 review-needed.md를 Edit | 재진입 가드 `$env:CLAUDE_HOOK_DEPTH`. write 대상은 항상 hook 미감시 디렉터리(`reports/`, `session-env/`, `.drift-queue/`, `review-needed.md`) |
| 1M context × 1h cache TTL | 룰이 1시간 박힘 | P1-3 prefix-version invalidate. UserPromptSubmit suffix-only |
| 공식 schema 변경 | hook 키 rename / event 삭제 | check-updates-worker가 `settings.md` SHA diff 감지하면 review-needed 자동 큐잉 (P1-2와 동일) |
| RTK 통계 왜곡 | 1h cache 도입 후 cache_read와 RTK filtered 혼합 | token-usage.md에 `cache_read` / `rtk_filtered` 별도 컬럼 분리 |
| UserPromptSubmit 800ms 초과 | git 큰 리포지토리에서 status 느림 | Skip-when-clean fast-path. timeout 800ms 시 빈 출력 fallback |

---

## Critical Files

### 신규 (8개 hook + 2개 supporting)
- [D:\.claude\hooks\token-report.ps1](D:/.claude/hooks/token-report.ps1)
- [D:\.claude\hooks\precompact-snapshot.ps1](D:/.claude/hooks/precompact-snapshot.ps1)
- [D:\.claude\hooks\postcompact-verify.ps1](D:/.claude/hooks/postcompact-verify.ps1)
- [D:\.claude\hooks\inject-runtime-ctx.ps1](D:/.claude/hooks/inject-runtime-ctx.ps1)
- [D:\.claude\hooks\memory-lint.ps1](D:/.claude/hooks/memory-lint.ps1)
- [D:\.claude\hooks\drift-enqueue.ps1](D:/.claude/hooks/drift-enqueue.ps1)
- [D:\.claude\hooks\drift-detect-worker.ps1](D:/.claude/hooks/drift-detect-worker.ps1)
- [D:\.claude\statusline.ps1](D:/.claude/statusline.ps1)
- `D:\.claude\reports\token-usage.md` (자동 생성)
- `D:\.claude\.docs-cache\prefix-version.txt` (자동 생성)

### 수정
- [D:\.claude\settings.json](D:/.claude/settings.json) — hooks 5종 추가 + env + statusLine
- [D:\.claude\hooks\session-start.ps1](D:/.claude/hooks/session-start.ps1) — 5-step 확장 (memory-lint, weekly backup)
- [D:\.claude\hooks\update-docs.ps1](D:/.claude/hooks/update-docs.ps1) — Update-AutoSection 함수 + prefix-version bump
- [D:\.claude\hooks\check-updates-worker.ps1](D:/.claude/hooks/check-updates-worker.ps1) — 영향 섹션 큐잉 로직
- [D:\.claude\cleanup.ps1](D:/.claude/cleanup.ps1) — backups 8주 회수 + 24h worker kill
- [d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\settings.json](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/settings.json) — PostToolUse 매처 3분리 + MCP 빈 화이트리스트 명시
- [d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\BEST_PRACTICES.md](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/BEST_PRACTICES.md) — 토픽 4분리 + 인덱스화 + AUTO 마크
- [d:\최신프로젝트\나인원랩스\퍼블\260427\.claude\SETUP_CHECKLIST.md](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/SETUP_CHECKLIST.md) — AUTO 마크 도입

### 불변 (건드리지 않음)
- [D:\.claude\hooks\session-start.ps1](D:/.claude/hooks/session-start.ps1)의 4-step **순서**
- [D:\.claude\cleanup.ps1](D:/.claude/cleanup.ps1) 기본 보관 정책 (plans 2일 / shell-snapshots 7일 / file-history 14일 / projects 30일·pinned 제외)
- RTK PreToolUse(Bash) 자동 재작성
- 프로젝트 [.claude/rules/{frontend,php,scss}.md](d:/최신프로젝트/나인원랩스/퍼블/260427/.claude/rules/) `paths:` frontmatter 구조
- MEMORY.md 11-토픽 분리
- [permissions.deny](D:/.claude/settings.json) 8개 항목

---

## 실행 순서

1. **Day 1**: P0-1 (1h cache) → P0-7 (프로젝트 매처 분리) → P0-5 (AUTO 마크) → P0-6 (memory-lint) — 모두 저위험·즉시 효과
2. **Day 2**: P0-4 (UserPromptSubmit skip-when-clean) → P0-3 (PreCompact/PostCompact) → P0-2 (Stop token-report) — hook 등록 후 `claude --debug hooks` 검증
3. **Week 1**: P1-1 (drift detector) → P1-2 (check-updates 영향 큐잉) → P1-3 (prefix-version invalidate) → P1-7 (MCP 빈 화이트리스트 명시)
4. **Week 2**: P1-4 (statusLine v2) → P1-5 (BEST_PRACTICES 토픽 분리) → P1-6 (주간 memory zip)

---

## Verification

### 단위 검증
- **P0-1**: `claude --debug api` 출력에서 `cache_creation_input_tokens` / `cache_read_input_tokens` 비율 확인 → 24h 후 read 비율 ≥ 70% 목표
- **P0-2**: Stop hook 1회 트리거 후 `D:\.claude\reports\token-usage.md` 에 오늘 날짜 헤딩 + RTK gain 표 append 확인. 두 번 트리거해도 항목 중복 없음(idempotent)
- **P0-3**: `/compact` 강제 호출 → `D:\.claude\backups\precompact-*` 디렉토리 생성, 모든 토픽 hard-link 존재 → PostCompact stderr에 깨진 import 없음
- **P0-4**: clean 리포지토리에서 prompt 1회 → PowerShell 프로세스 0개 spawn (Process Monitor 확인). dirty 상태에서 prompt → suffix `<context-runtime>` 블록 stdout JSON으로 출력
- **P0-5**: settings.json에 hook 추가 후 다음 SessionStart → AUTOMATION.md AUTO 섹션 자동 반영
- **P0-6**: 의도적으로 깨진 링크 삽입 → SessionStart 직후 `memory-lint.txt`에 보고
- **P0-7**: `.test.ts` 저장 시 tsc는 안 돌고 vitest만 돈다. `.php` 저장 시 `php -l`만, `.scss` 저장 시 stylelint만

### 통합 검증
- **Hook 무한루프 회피**: PostToolUse hook 내부에서 review-needed.md를 Edit해도 재진입 가드로 1회 후 즉시 종료
- **1h cache 무파괴**: CLAUDE.md를 수정하지 않은 채 24h 세션 → cache_read 비율 ≥ 70%. CLAUDE.md 수정 → 다음 prompt에서 cache invalidate (P1-3)
- **공식 스펙 정합**: `claude --debug hooks` 출력이 [code.claude.com/docs/en/hooks.md](https://code.claude.com/docs/en/hooks.md) 의 event 이름과 일치

### 회귀 검증 (불변 자산)
- SessionStart latency `<100ms` 유지 (5-step 확장 후에도)
- cleanup.ps1 기본 보관 정책 변경 없음 — `git diff` 로 라인 단위 확인
- RTK PreToolUse 명령 재작성률 변동 없음 — `rtk gain --history` 비교
- MEMORY 11-토픽 파일 개수·구조 그대로

### 7일 baseline
- token-usage.md 7일 데이터 축적 → cache_read 비율 / RTK 절감률 / 일별 토큰 사용량 그래프 안정 여부 확인
- review-needed.md에 false positive drift 항목이 5개 이하인지 (5개 초과 시 drift detector 룰 튜닝)

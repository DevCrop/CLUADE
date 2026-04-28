# Claude Code 토큰 최적화 감사 — NINEONELABS 환경

## Context

- 현 세션 통계: $0.2251 / 코드 0줄 / Sonnet 캐시 히트율 73% (양호) / **Haiku cache read 0%** / Wall 15h vs API 40s
- 사용자 요청: 글로벌 `~/.claude/`, 프로젝트 `.claude/`, CLAUDE.md/AGENTS.md, 메모리, hook, MCP, 공식 권고를 베이스로 토큰 최적화 상태 디테일 감사 + 페이즈별 처리 방안
- 진단 결과: **좀비 hook 1건 + 매-편집 hook 2건 + 동일 룰 3중 중복 + 거대한 AGENTS.md** 가 가장 큰 누수원. 메모리/agents/skills/rules 구조 자체는 양호.

---

## 발견 사항 (심각도 순)

### 🚨 CRITICAL

#### 1. 좀비 CHOP PreToolUse hook — `~/.claude/settings.json:18-22`
```json
{ "matcher": "Bash", "hooks": [{ "command": "\"C:/Users/edn_y/AppData/Local/Programs/chop/chop.exe\" hook" }] }
```
- 사용자 메모리(`feedback_rtk.md`)는 **CHOP이 2026-04-25 완전 제거됨**을 명시
- 그러나 글로벌 settings에 hook이 살아 있음 → 매 Bash 호출마다 chop.exe 실행 시도
- 실행 실패 시 stderr 또는 hook 응답이 컨텍스트로 주입될 수 있음, 최소 latency 추가
- **rtk hook과 동일한 matcher에 중복 등록**되어 있어 두 번 실행됨

#### 2. PostToolUse `rtk gain` 매-편집 주입 — `~/.claude/settings.json:3-13`
```json
{ "matcher": "Edit|Write", "command": "rtk gain ... systemMessage" }
```
- 매 Edit/Write마다 systemMessage로 stdout 전체를 컨텍스트에 추가
- 100번 편집 = systemMessage 100건 누적 (각 수십~수백 토큰)
- `rtk gain`은 디버깅 명령. **자동 hook이 아닌 수동 호출**이 적절 (RTK.md 자체에 "메타: 항상 rtk 직접 호출" 명시됨)

### ⚠️ HIGH

#### 3. RTK 룰 3중 중복 — 매 세션 시스템 프롬프트에 동일 내용 3번 적재
- `~/.claude/CLAUDE.md` 4-6줄: "RTK 필수" + `@RTK.md` import
- `~/.claude/RTK.md`: 전체 RTK 가이드 (~80줄)
- `c:\...\renew_nineonelabs\AGENTS.md` 25-56줄: "Token Optimization → RTK" 섹션 재기재
- 매 세션 시작마다 동일 RTK 정책이 ~150줄 분량으로 컨텍스트에 적재됨
- 추가: 메모리 `feedback_rtk.md`까지 합치면 **4중 중복**

#### 4. AGENTS.md 비대화 — 105줄, 컨텍스트 영구 적재
- 단일 파일에: 브랜드 정체성 + 프로젝트 디폴트 + 토큰 최적화 + 아키텍처 + 편집 룰 + 검증 + 테스트 디스시플린 + 스킬 + Codex 노트
- 공식 권고는 "concise & durable" — 대부분 룰은 필요 시점에만 로드하면 됨 (예: Brand Identity는 카피 작성 시에만 필요, Codex Notes는 Claude 세션과 무관)
- 현재 `.claude/rules/{frontend,php,scss}.md`는 `paths:` 프론트매터로 자동 로드되어 잘 분리돼 있는데, 정작 AGENTS.md 본문은 안 분리됨

#### 5. PostToolUse `tsc --noEmit` — 프로젝트 `.claude/settings.json:16-26`
- 매 `.ts/.tsx` 저장마다 전체 프로젝트 typecheck, `stdio:'inherit'`로 출력 그대로 받음
- 대형 프로젝트(현 repo: `resource/ts/` 광범위)에서 typecheck 출력이 큼 + tsc 자체가 수 초 소요
- 합리적이긴 하나 **편집 빈도가 높을 때 누수 큼**. 옵션: matcher를 좁히거나, `.test.ts` 제외, 또는 commit pre-hook으로 이전

### 🟡 MEDIUM

#### 6. `allowedTools` 레거시 키 사용 — 프로젝트 `.claude/settings.json:2`
- 현 settings.json은 deprecated 형식인 `"allowedTools": [...]`
- settings.local.json은 올바른 `"permissions": { "allow": [...] }` 사용
- 두 파일이 **서로 다른 스키마** → settings.json 쪽 권한이 적용 안 될 가능성

#### 7. 글로벌 plugins marketplace 다수 설치 — `~/.claude/plugins/marketplaces/.../external_plugins/`
- asana / context7 / discord / fakechat / firebase / github / gitlab / greptile 등 ~10+ 플러그인 디렉토리 존재
- `~/.claude/plugins/config.json`이 없으므로 **현재는 비활성** 가능성 높음
- 그러나 `.mcp.json` 파일들이 활성화되면 MCP 서버가 시스템 프롬프트에 instructions를 주입 (현재 컨텍스트의 Figma/Gmail/Calendar/Drive/Notion이 그 예 — Figma 한 개만 ~600 토큰)

#### 8. MCP instructions 무거움
- 현 세션에 Figma + Gmail + Google Calendar + Google Drive + Notion **5개 활성**
- Figma instructions만 봐도 ~600+ 토큰. 5개 합치면 수천 토큰을 매 세션 적재
- Gmail/Calendar/Drive는 거의 안 쓴다면 비활성화가 큰 절약

### 🟢 LOW (양호)

- **메모리 시스템**: 12 파일, MEMORY.md 13줄 — 깔끔, 200줄 룰 내
- **`.claude/agents/`**: scene-explorer / php-explorer 도메인 분리 — 모범
- **`.claude/skills/`**: migration / new-route — 모범
- **`.claude/rules/`**: paths: 프론트매터 자동 로드 — 모범
- **BEST_PRACTICES.md**: 코드 가이드 분리 — 모범
- **세션 통계**: Sonnet 캐시 히트 73%, Haiku 0%는 Claude Code 내부 짧은 호출 특성상 정상

---

## 페이즈별 처리 방안

각 페이즈는 **독립 실행 가능**. 위에서 아래로 갈수록 ROI 감소.

### Phase 1 — 즉시 적용 (15분, ROI 최대)

**목표**: 좀비 hook 제거 + 매-편집 hook 정리.

1.1. **글로벌 `~/.claude/settings.json` 수정**
   - `PreToolUse`에서 `chop.exe hook` 항목 **삭제** (`rtk hook claude`만 남김)
   - `PostToolUse` `rtk gain` hook **삭제** (수동으로 `rtk gain` 호출 권장)
   - `SessionEnd cleanup.ps1`은 유지 (비동기 + 세션당 1회)

1.2. **검증**
   - VS Code Claude Code 재시작
   - 새 세션에서 임의 Bash 한 번 실행 → 응답 시간 단축 확인
   - `rtk gain --history`로 누적 검증
   - 새 세션 시작 후 ~30분 작업 후 통계 비교

**예상 절감**: Bash 호출당 latency 50-200ms × 세션당 ~50회, Edit/Write당 systemMessage 누적 제거 (수만 토큰/세션).

---

### Phase 2 — 룰 중복 제거 (30분, ROI 큼)

**목표**: RTK 룰을 단일 출처로 통합.

2.1. **AGENTS.md 슬림화** — `c:\...\renew_nineonelabs\AGENTS.md` ✅ 사용자 확정
   - "Token Optimization" 섹션 (25-56줄) **삭제** → 글로벌 `~/.claude/RTK.md` 단일 출처로 위임
   - 대신 한 줄로: `> Token rules: see ~/.claude/RTK.md (global). Project filters: .rtk/filters.toml.`
   - **"Brand Identity" 섹션 (5-14줄) 완전 삭제** — 사용자: "view 파일에 HTML로 있어서 필요없어"
   - "Codex Notes" 섹션은 별도 `CODEX.md`로 분리하거나 `.codex/`로 이동
   - 목표 라인 수: **~40줄 이내**

2.2. **글로벌 `~/.claude/CLAUDE.md` 단순화**
   - "RTK 필수" 한 줄 + `@RTK.md` import만 남김 (이미 거의 그 상태)

2.3. **메모리 `feedback_rtk.md` 보존 vs 삭제 결정**
   - 메모리는 **검색 기반 회상**이므로 매 세션 적재 안 됨 → 유지해도 무방
   - 단, 내용이 RTK.md와 동일하면 1줄 요약으로 축소: "RTK 정책: ~/.claude/RTK.md 참조. CHOP은 2026-04-25 제거"

**예상 절감**: 매 세션 시스템 프롬프트 ~100-150줄 (≈800-1200 토큰) 감소.

---

### Phase 3 — Hook 미세 튜닝 (20분, ROI 중)

**목표**: 프로젝트 PostToolUse `tsc` hook의 누수 축소.

3.1. **프로젝트 `.claude/settings.json` 수정**
   - `allowedTools` → `permissions.allow`로 키 변경 (settings.local.json과 스키마 통일)
   - tsc hook 옵션 A: 그대로 유지 (현재 `paths:`를 프론트매터로 좁히고 있음)
   - tsc hook 옵션 B: `.test.ts` 매처에서 제외, errors-only stderr 캡처
   - tsc hook 옵션 C: hook 제거 + Stop hook으로 이동 (편집 끝났을 때 1회만)

3.2. **권장 옵션**: B + C 절충 → 매 편집 그대로 두되 `.test.ts` 제외 (테스트는 더 자주 깨짐)

**예상 절감**: 편집 빈도 높은 세션에서 typecheck 호출 30-50% 감소.

---

### Phase 4 — MCP 전체 비활성화 (10분, ROI 매우 큼) ✅ 사용자 확정

**목표**: Figma / Gmail / Calendar / Drive / Notion **5개 전부 비활성** (사용자: "다 안써 지워도돼").

4.1. **`/mcp` 슬래시 명령**으로 각각 disconnect, 또는
4.2. **`~/.claude/settings.json`의 `mcpServers`** 항목 모두 제거 (또는 `enableAllProjectMcpServers: false`)
4.3. **확인**: 새 세션에서 시스템 프롬프트에 MCP instructions 없는지 확인

**예상 절감**: ~3000-5000 토큰/세션 (Figma instructions만 ~600 토큰, 5개 합계). **이번 감사에서 가장 큰 단일 절감.**

---

### Phase 5 — 세션 운영 습관 (반복적)

**목표**: 통계 데이터 기반 행동 변경.

5.1. **15시간 세션 끄기** — Wall 15h vs API 40s는 5분 캐시 TTL을 다수 만료시킴. 작업 끝나면 `/clear` 또는 세션 종료
5.2. **Plan/Implement 세션 분리** — 플래닝 후 `/clear` → 구현은 새 세션에서 (현재 이 세션이 그 예시)
5.3. **`rtk gain` 주간 점검** — `rtk gain --daily` 로 추세 모니터링

---

## 핵심 파일 (수정 대상)

| 페이즈 | 파일 | 변경 |
|---|---|---|
| 1 | `C:\Users\edn_y\.claude\settings.json` | chop hook 삭제, rtk gain hook 삭제 |
| 2 | `c:\Users\edn_y\renew_nineonelabs\AGENTS.md` | Token Optimization / Brand / Codex 섹션 분리·삭제 |
| 2 | `c:\...\renew_nineonelabs\.claude\rules\branding.md` | 신규 (paths: views/**/*.php) |
| 2 | `C:\Users\edn_y\.claude\projects\...\memory\feedback_rtk.md` | 1줄로 축소 |
| 3 | `c:\...\renew_nineonelabs\.claude\settings.json` | allowedTools→permissions.allow, tsc matcher 좁힘 |
| 4 | (사용자 답변 후) MCP 비활성 | `/mcp` 또는 settings 수정 |

## 검증 방법

- **Phase 1 직후**: 새 세션 → 임의 Bash 실행 → 응답 latency 비교, `rtk gain --history`
- **Phase 2 직후**: 새 세션 → 첫 cache write 토큰 수 비교 (settings 변경 전 후 30k → 25k 정도 기대)
- **Phase 3 직후**: `.ts` 저장 5회 후 컨텍스트 사용량 비교
- **종합**: 1주일 후 `rtk gain --daily`로 누적 절감 확인. 동일 작업량 기준 30-50% 토큰 감소가 목표.

## 사용자 확정 사항 (2026-04-27)

1. ✅ CHOP hook 제거
2. ✅ `rtk gain` PostToolUse hook 제거
3. ✅ MCP 5개(Figma/Gmail/Calendar/Drive/Notion) **전부 비활성**
4. ✅ AGENTS.md "Brand Identity" 섹션 **완전 삭제** (view에 HTML로 존재)

## 예상 총 절감 (세션당)

- Phase 1: Bash latency 50-200ms × 50회 + Edit/Write systemMessage 누적 제거
- Phase 2: 시스템 프롬프트 ~150줄 (~1200 토큰) 감소
- Phase 3: typecheck 호출 30-50% 감소
- Phase 4: ~3000-5000 토큰 (MCP instructions 5개 제거) — **최대 단일 절감**
- **합계 추정**: 시스템 프롬프트 매 세션 5000-7000 토큰 감소 + 누적 누수 hook 제거

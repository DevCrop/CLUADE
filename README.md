# Global Claude Code Harness (Windows Native)

> 개인용 Windows 네이티브 Claude Code 하네스. RTK 토큰 최적화 + 자동화 훅 + 프롬프트 분류 알고리즘이 묶음으로 들어있습니다.
> **초급 개발자도 이 가이드만 따라가면 동일 환경을 재구성할 수 있도록** 작성했습니다.

---

## 목차

1. [이 저장소가 뭐냐](#1-이-저장소가-뭐냐)
2. [선행 준비 (필수)](#2-선행-준비-필수)
3. [설치 단계](#3-설치-단계)
4. [디렉터리 구조](#4-디렉터리-구조)
5. [핵심 문서 안내](#5-핵심-문서-안내)
6. [훅 시스템](#6-훅-시스템)
7. [동작 확인](#7-동작-확인)
8. [자주 묻는 문제 (FAQ)](#8-자주-묻는-문제-faq)
9. [절대 하지 말 것](#9-절대-하지-말-것)

---

## 1. 이 저장소가 뭐냐

`%USERPROFILE%\.claude\` 폴더 전체의 백업 + 공유본입니다. 다음 기능이 들어있습니다.

- **Claude Code 동작 규칙** (`CLAUDE.md`, `PROMPT_ALGO.md`) — Claude가 프롬프트를 받았을 때 어떤 verbosity/thinking/tool use 기본값을 쓸지 결정하는 알고리즘
- **RTK (Rust Token Killer) 연동** (`RTK.md`) — `git`, `npm`, `tsc`, `docker` 같은 시끄러운 CLI를 자동으로 토큰 최적화하는 프록시
- **자동화 훅 9개** (`hooks/*.ps1`) — 세션 시작/종료, 드리프트 감지, 컴팩션 백업, 토큰 통계 등
- **프로젝트 부트스트랩 템플릿** (`templates/`) — 새 프로젝트 시작 시 복사해서 쓰는 파일
- **슬래시 명령 스킬** (`skills/`) — `/rtk-reference`, `/rtk-discover` 등

⚠️ **개인용 설정**이라 그대로 가져다 쓰기보단 본인 환경에 맞게 수정하길 권장합니다.

---

## 2. 선행 준비 (필수)

| 항목 | 최소 버전 | 설치 명령 / 링크 |
|------|-----------|------------------|
| **Windows** | 10 (Build 19045+) 또는 11 | — |
| **PowerShell** | 5.1 이상 (7.x 권장) | Windows 기본 탑재 |
| **Git** | 2.40+ | https://git-scm.com/download/win |
| **Node.js** | 18 LTS 이상 | https://nodejs.org/ |
| **Claude Code CLI** | 최신 | `npm install -g @anthropic-ai/claude-code` |
| **RTK** | v0.37.2 이상 | `cargo install rtk` 또는 https://github.com/rtk-ai/rtk |
| **VS Code** | 최신 | https://code.visualstudio.com/ |
| **VS Code Claude Code 확장** | 최신 | VS Code 마켓플레이스에서 "Claude Code" 검색 |
| **GitHub 계정 + SSH/HTTPS 인증** | — | `git config --global user.name` / `user.email` |

### 2-1. UTF-8 콘솔 강제 (한국어 깨짐 방지 — 매우 중요)

PowerShell `$PROFILE`에 아래를 추가하세요. 없으면 한글 로그가 `???`나 `Ã¥`로 깨집니다.

```powershell
# 콘솔 코드페이지를 UTF-8(65001)로 강제
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
```

`$PROFILE` 경로 확인: PowerShell에서 `$PROFILE` 입력 후 엔터.

### 2-2. RTK 설치 확인

```powershell
rtk --version          # rtk 0.37.x 이상 출력되어야 함
rtk gain               # 분석 화면이 떠야 정상
```

`command not found`가 뜨면 `cargo install rtk` 다시 실행하거나 PATH 확인.

---

## 3. 설치 단계

### 3-1. 기존 `.claude\` 폴더 백업

⚠️ **기존 설정이 있으면 먼저 통째로 백업하세요.** 이 저장소를 덮어쓰면 기존 세션·메모리·토큰이 다 날아갑니다.

```powershell
$backup = "$env:USERPROFILE\.claude.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -Recurse -Force "$env:USERPROFILE\.claude" $backup
Write-Host "백업 완료: $backup"
```

### 3-2. 저장소 클론

`%USERPROFILE%\.claude\` 위치에 직접 클론합니다.

```powershell
# 기존 폴더가 비어있어야 함 (또는 별도 위치에 클론 후 내용물 복사)
cd $env:USERPROFILE
git clone https://github.com/DevCrop/CLUADE.git .claude
cd .claude
git checkout 260512    # 또는 main
```

이미 폴더가 있는 경우:

```powershell
cd $env:USERPROFILE\.claude
git init
git remote add origin https://github.com/DevCrop/CLUADE.git
git fetch origin
git checkout -f 260512
```

### 3-3. 민감 파일 별도 생성

⚠️ **저장소에는 들어있지 않습니다 (의도적 제외).** 직접 만들어야 합니다.

```
.credentials.json          # MCP 서버 인증 토큰
.claude.json               # Claude Code 세션 상태 (자동 생성됨)
mcp-needs-auth-cache.json  # MCP 인증 캐시 (자동 생성됨)
```

`.claude.json`과 `mcp-needs-auth-cache.json`은 Claude Code가 처음 실행되면 알아서 생성합니다. `.credentials.json`은 MCP 서버를 쓸 때 자동/수동으로 채워집니다.

### 3-4. 훅 스크립트 실행 권한 확인

```powershell
# PowerShell 실행 정책이 RemoteSigned 이상이어야 함
Get-ExecutionPolicy
# Restricted면 아래 실행:
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### 3-5. settings.json 경로 확인

`settings.json`의 훅 경로가 `%USERPROFILE%/.claude/hooks/...`로 되어있는지 확인. 다른 위치에 클론했다면 경로 수정 필요.

### 3-6. 첫 세션 실행

VS Code에서 Claude Code 확장을 열고 새 세션을 시작하세요. SessionStart 훅이 자동 실행되면서:

- 메모리 정리
- 24시간 게이트 문서 업데이트 체크
- 드리프트 큐 정리
- AUTOMATION.md AUTO 마크 갱신

이 일어납니다. 에러 없이 통과되면 정상.

---

## 4. 디렉터리 구조

```
%USERPROFILE%\.claude\
│
├── README.md                    # 이 파일
│
├── CLAUDE.md                    # ★ 글로벌 운영 규칙 (DO / DON'T, RTK, 메모리)
├── PROMPT_ALGO.md               # ★ 프롬프트 분류 알고리즘 (자동 적용)
├── RTK.md                       # RTK CLI 명령 참조
├── ARCHITECTURE.md              # 시스템 아키텍처 (드라이브, 경로, 정책)
├── AUTOMATION.md                # 자동화 훅 상세 (AUTO 마크는 자동 갱신)
├── HARNESS_ARCHITECTURE.md      # 하네스 설계 패턴 (3-Layer + Verification Loop)
│
├── settings.json                # ★ 훅 등록 / 권한 / 모델 설정
├── settings.local.json          # 호스트별 오버라이드 (선택)
│
├── cleanup.ps1                  # SessionEnd 정리 스크립트
├── statusline.ps1               # 상태줄 렌더러
│
├── hooks/                       # PowerShell 훅 (9개 등록)
│   ├── session-start.ps1        #   SessionStart 메인
│   ├── update-docs.ps1          #   AUTO 마크 자동 갱신
│   ├── auto-pin.ps1             #   현 프로젝트 핀
│   ├── memory-lint.ps1          #   MEMORY.md 무결성 검사
│   ├── memory-backup.ps1        #   주간 메모리 백업
│   ├── check-updates.ps1        #   24h 게이트 문서 업데이트 체크
│   ├── check-updates-worker.ps1 #   백그라운드 워커
│   ├── archive-plans.ps1        #   60일 이상 플랜 아카이브
│   ├── drift-enqueue.ps1        #   PostToolUse 큐잉
│   ├── drift-detect-worker.ps1  #   SessionEnd 드리프트 감지
│   ├── inject-runtime-ctx.ps1   #   UserPromptSubmit git 컨텍스트 주입
│   ├── precompact-snapshot.ps1  #   PreCompact 백업
│   ├── postcompact-verify.ps1   #   PostCompact 검증
│   ├── token-report.ps1         #   Stop 토큰 통계
│   ├── oneshot-consolidate.ps1  #   D드라이브 잔존물 통합
│   └── rtk-prerewrite.js        #   (옛 Node 훅 — 현재는 native rtk 사용)
│
├── templates/                   # 새 프로젝트 시작 시 복사
│   ├── project-init.md          #   신규 프로젝트 부트스트랩 가이드
│   ├── project-fork.md          #   기존 프로젝트 포크 가이드
│   └── order-match-checklist.md #   Order Match 검증 체크리스트
│
└── skills/                      # 슬래시 명령
    ├── rtk-discover/            #   /rtk-discover (Windows CWD 워크어라운드)
    └── rtk-reference/           #   /rtk-reference (RTK 명령 참조)
```

**자동 생성/관리 디렉터리** (.gitignore로 제외됨):

```
projects/ backups/ file-history/ shell-snapshots/ sessions/
session-env/ paste-cache/ downloads/ telemetry/ cache/
.docs-cache/ .drift-queue/ reports/ plans/ ide/ docs/
```

---

## 5. 핵심 문서 안내

### 5-1. `CLAUDE.md` — 최우선 규칙

Claude가 매 세션마다 로드합니다. DO / DON'T, RTK 강제, Order Match 검증 절차, 메모리 시스템 정의가 들어있습니다.

**개인 환경에 맞춰 수정해야 할 곳:**

- 사용자 언어 (현재 한국어 응답 + 영문 아티팩트)
- 기본 모델 / 에스컬레이션 정책
- 메모리 디렉터리 경로

### 5-2. `PROMPT_ALGO.md` — 프롬프트 분류

새로 추가된 문서. Claude가 매 프롬프트를 받으면 다음 5종으로 자동 분류하고 기본 동작을 정합니다.

| 유형 | 신호 | Verbosity | Thinking | Tools |
|------|------|-----------|----------|-------|
| CONVERSATIONAL | 질문, 단순 조회 | 최소 | 끔 | 검색 필요 시만 |
| CODING | 구현, 수정, 디버그 | 코드 우선 | 알고리즘 설계 시 | 병렬 |
| RESEARCH | 조사, 비교, 감사 | 종합적 | 켬 (적응형) | 병렬 검색 |
| AGENTIC | 멀티스텝 자율 | 마일스톤만 | 매 행동 전 | 서브에이전트 |
| CREATIVE | 작성, 디자인 | 풍부 | 가벼움 | 매체별 |

### 5-3. `RTK.md` — 토큰 최적화

`git status` → `rtk git status`로 자동 변환되어 출력이 압축됩니다. 60–90% 토큰 절감.

수동 사용:
```bash
rtk gain              # 절감 통계
rtk gain --history    # 명령 이력
rtk discover          # 미사용 기회 분석
rtk proxy <cmd>       # 필터 없이 raw 출력
```

### 5-4. `ARCHITECTURE.md` / `HARNESS_ARCHITECTURE.md`

전자는 **이 환경**의 실제 아키텍처(드라이브, 경로, 훅), 후자는 **하네스 설계 패턴**(다른 프로젝트에도 적용 가능한 일반론).

### 5-5. `AUTOMATION.md`

훅 동작 다이어그램, 자동 갱신되는 표(`AUTO:HOOK-EVENTS` 마크 사이는 `update-docs.ps1`가 매 SessionStart마다 다시 씀), 트러블슈팅.

---

## 6. 훅 시스템

`settings.json`에 등록된 9개 명령이 8개 이벤트에 묶여 동작합니다.

| 이벤트 | 훅 | 시점 | 역할 |
|--------|-----|------|------|
| `SessionStart` | session-start.ps1 | 세션 열 때 | 모든 시작 작업 순차 실행 |
| `SessionEnd` | cleanup.ps1 | 세션 닫을 때 | 13종 디렉터리 회전, 백업, 정리 |
| `SessionEnd` | drift-detect-worker.ps1 | 세션 닫을 때 | 드리프트 큐 비우기 |
| `PostToolUse` | drift-enqueue.ps1 | 파일 편집 후 | 드리프트 큐에 추가 |
| `UserPromptSubmit` | inject-runtime-ctx.ps1 | 프롬프트 제출 직전 | git status 더러우면 컨텍스트 주입 |
| `PreCompact` | precompact-snapshot.ps1 | 컴팩션 직전 | 중요 파일 하드링크 스냅샷 |
| `PostCompact` | postcompact-verify.ps1 | 컴팩션 직후 | @import 체인 검증 |
| `Stop` | token-report.ps1 | 응답 끝날 때 | 토큰 사용량 누적 |
| `PreToolUse(Bash)` | rtk hook claude | 모든 Bash 실행 직전 | rtk 자동 prefix |

⚠️ **훅을 새로 추가하지 마세요** (CLAUDE.md FOMO 가드 참조). 기존 9개로 대부분 커버됩니다.

---

## 7. 동작 확인

설치가 끝났으면 아래로 검증합니다.

### 7-1. RTK 자동 rewrite 동작

VS Code Claude Code 세션에서 다음 입력:
```
status 보여줘
```

Claude가 `git status`를 실행하려고 하면 hook이 자동으로 `rtk git status`로 바꿔서 압축된 출력이 떠야 합니다.

### 7-2. PROMPT_ALGO 로드 확인

세션에서 `CLAUDE.md`를 읽도록 시켜본 뒤, 끝의 `@PROMPT_ALGO.md`가 따라 로드됐는지 확인.

### 7-3. 훅 정상 동작 확인

```powershell
# SessionEnd 로그 (마지막 세션 정리)
Get-Content "$env:USERPROFILE\.claude\cleanup.log" -Tail 20

# 토큰 사용 리포트
Get-Content "$env:USERPROFILE\.claude\reports\token-usage.md" -Tail 30
```

### 7-4. 한국어 콘솔 동작 확인

```powershell
chcp                  # 65001이 나와야 함
"한글 출력 테스트"      # 깨지지 않고 그대로 나와야 함
```

---

## 8. 자주 묻는 문제 (FAQ)

### Q1. SessionStart 훅이 실행 안 됨

```powershell
# 실행 정책 확인
Get-ExecutionPolicy -Scope CurrentUser
# RemoteSigned 또는 Unrestricted여야 함
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Q2. 콘솔에서 한글이 `???`로 나옴

`$PROFILE`에 [2-1. UTF-8 콘솔 강제](#2-1-utf-8-콘솔-강제-한국어-깨짐-방지--매우-중요) 블록이 빠진 상태. 추가 후 PowerShell 재시작.

### Q3. `rtk: command not found`

`cargo install rtk`로 재설치 후 `$env:PATH` 확인:
```powershell
$env:PATH -split ';' | Where-Object { $_ -match 'cargo' }
# %USERPROFILE%\.cargo\bin 이 PATH에 있어야 함
```

### Q4. `bypassPermissions` 모드 위험하지 않나?

`settings.json`에 `permissions.defaultMode = "bypassPermissions"`가 설정돼 있습니다. **Docker나 격리 환경 안에서만** 안전합니다. 호스트에서 직접 사용 시:

- `permissions.deny`에 `rm -rf`, `git push --force`, `git reset --hard`, `.credentials*` 등이 명시돼 있어 최소한의 안전망 작동
- 새 위험 명령은 `permissions.deny`에 추가 필요

### Q5. `.credentials.json`이 GitHub에 올라가지 않을까?

`.gitignore`에 등록돼 있어 git이 트래킹하지 않습니다. 추가로 다음 파일들도 제외됨:
```
.credentials.json
.claude.json
mcp-needs-auth-cache.json
active-projects.json
history.jsonl
settings.local.json
backups/ sessions/ projects/ file-history/ shell-snapshots/ reports/ plans/
```

### Q6. 컴팩션(context 압축)이 일어나면 메모리 날아가나?

`PreCompact` 훅이 직전에 하드링크로 스냅샷을 떠두고, `PostCompact` 훅이 @import 체인 무결성을 검증합니다. 만약 손실되면 `backups/precompact-*`에서 복구 가능. 28일 후 자동 삭제.

### Q7. 한국어 답변 / 영어 답변 정책?

`CLAUDE.md`에 정의:
- **챗 응답**: 한국어
- **AI 소비 아티팩트** (문서, 훅, 플랜, 메모리, 주석, 로그): **영어**
- **코드 식별자, 경로, 명령, 에러 메시지**: 영어 그대로

이 README는 사용자(사람) 대상이라 한국어로 작성됨.

---

## 9. 절대 하지 말 것

1. ❌ `.claude` 폴더 루트를 **D드라이브로 이동** (NTFS 정션 포함). 글로벌 인프라는 `%USERPROFILE%`에 고정.
2. ❌ `.credentials.json` / `.claude.json` / `mcp-needs-auth-cache.json` **커밋**. 이미 `.gitignore` 등록됨.
3. ❌ `git push --force` / `git reset --hard` **명시적 지시 없이** 실행.
4. ❌ `--no-verify` / `rm -rf` 같은 **파괴적 단축키로 우회**. 근본 원인 수정.
5. ❌ 훅 / 스킬 / MCP / 규칙 **무분별 추가**. FOMO 가드 — 월 3회 이상 실제 사용 또는 측정 가능 이익 증명 시에만 추가.
6. ❌ Anthropic 기본 동작과 다른 커스터마이징을 **사고 없이** 도입. Vanilla compliance 원칙.

---

## 라이선스 / 책임

이 저장소는 **개인 백업용**으로 공개됩니다. 그대로 가져다 써도 되지만 **본인 환경에 맞게 수정 필수**이며, 잘못된 설정으로 인한 데이터 손실에 대해 저장소 작성자는 책임지지 않습니다.

특히 `permissions.bypassPermissions` 모드는 격리 환경 외에서 위험할 수 있으니, 도입 전 `settings.json`의 `permissions.deny` 목록을 본인 워크플로우에 맞게 보강하세요.

---

## 기여 / 문의

- 리포지토리: https://github.com/DevCrop/CLUADE
- 브랜치: `260512` (최신 작업), `main` (안정)
- 이슈 / PR: GitHub Issues 사용

🤖 Generated with [Claude Code](https://claude.com/claude-code)

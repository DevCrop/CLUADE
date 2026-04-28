# Plan: 공식 문서 기반 멀티 프로젝트 + 멀티 에이전트 AI 아키텍처

## Context
공식 docs(hooks · memory · sub-agents) 분석 결과 현재 설정에서 3가지 수정이 필요함:
1. **`Stop` 훅 오용** — `Stop`은 매 응답 후 실행. 정리용 훅은 공식적으로 `SessionEnd`가 맞음
2. **에이전트 파일 미정의** — `$scene-explorer` 등은 `.claude/agents/` 파일로 정의해야 함
3. **cleanup.ps1 OCP 위반** — 프로젝트명 하드코딩 (Registry 패턴으로 교체)

---

## 공식 문서 핵심 발견 (설계 근거)

| 발견 | 적용 |
|------|------|
| `SessionEnd` 훅 존재 — 세션 종료 시 1회만 실행 | Stop → SessionEnd 교체 |
| 에이전트 파일: `.claude/agents/` (프로젝트) / `~/.claude/agents/` (전역) | 에이전트 정식 정의 가이드 |
| `~/.claude/rules/` — 모든 프로젝트에 적용되는 전역 개인 규칙 | 글로벌 규칙 레이어 |
| MEMORY.md: 처음 200줄 또는 25KB만 세션 시작 시 로드 | 인덱스 200줄 유지 |
| 서브에이전트 `memory` 필드: `user/project/local` — 에이전트도 메모리 가능 | agent 파일 설계 |
| `async: true` 훅 옵션 — 비차단 실행 | cleanup 훅 async화 |

---

## 변경 1: settings.json — Stop → SessionEnd + async

**파일:** `C:\Users\edn_y\.claude\settings.json`

`Stop` 훅을 `SessionEnd`로 교체 + `async: true` 추가.

```json
"SessionEnd": [
  {
    "hooks": [
      {
        "type": "command",
        "async": true,
        "command": "powershell.exe -NonInteractive -File \"C:/Users/edn_y/.claude/cleanup.ps1\""
      }
    ]
  }
]
```

이유:
- `Stop` = 매 응답 후 실행 (과도한 실행)
- `SessionEnd` = 세션 종료 시 1회 실행 (의미론적으로 올바름)
- `async: true` = 종료를 차단하지 않음

---

## 변경 2: active-projects.json — Project Registry (신규)

**파일:** `C:\Users\edn_y\.claude\active-projects.json`

```json
{
  "pinned": [
    "c--Users-edn-y-renew-nineonelabs"
  ]
}
```

SOLID 적용:
- **OCP**: 새 프로젝트 = 이 파일에만 추가 (cleanup.ps1 수정 불필요)
- **DIP**: cleanup.ps1은 Registry 추상화에 의존 (구체적 폴더명 제거)

---

## 변경 3: cleanup.ps1 — Registry 기반 리팩터

**파일:** `C:\Users\edn_y\.claude\cleanup.ps1`

핵심 변경:
- stdin으로 SessionEnd payload 수신 (end_reason 활용 가능)
- active-projects.json 읽어서 pinned 목록 로드
- recency 휴리스틱 + pinned 보호 조합

```powershell
# SessionEnd payload 수신
$hookData = $null
try {
    $rawInput = [Console]::In.ReadToEnd()
    if ($rawInput) { $hookData = $rawInput | ConvertFrom-Json }
} catch {}

# Registry 읽기
$registryPath = "$base\active-projects.json"
$registry = if (Test-Path $registryPath) {
    Get-Content $registryPath | ConvertFrom-Json
} else { $null }
$pinned = if ($registry -and $registry.pinned) { $registry.pinned } else { @() }

# projects/: pinned이거나 14일 이내 수정이면 보호 / 30일 이상이면 삭제
Get-ChildItem "$base\projects" -Directory -ErrorAction SilentlyContinue |
    Where-Object {
        $name = $_.Name
        $isPinned = $pinned | Where-Object { $name -like "*$_*" }
        $isRecent = $_.LastWriteTime -gt (Get-Date).AddDays(-14)
        -not $isPinned -and -not $isRecent -and
        $_.LastWriteTime -lt (Get-Date).AddDays(-30)
    } |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force; $projDeleted++ }
```

---

## 변경 4: templates/project-init.md — 공식 패턴 기반 부트스트랩

**파일:** `C:\Users\edn_y\.claude\templates\project-init.md`

### 포함 구조

```
<project>/
├── AGENTS.md                    ← Cross-AI 규칙 (브랜드·스택·RTK·검증·금지)
├── CLAUDE.md                    ← @AGENTS.md + Claude 전용 델타
└── .claude/
    ├── CLAUDE.md                ← (선택) 상세 프로젝트 규칙
    ├── BEST_PRACTICES.md        ← 도메인 불변 아키텍처 규칙
    ├── SETUP_CHECKLIST.md       ← 하네스 셋업 검증
    ├── settings.json            ← PostToolUse tsc 훅
    ├── rules/                   ← Interface Segregation
    │   ├── frontend.md          ← paths: **/*.ts, **/*.tsx
    │   ├── backend.md           ← paths: **/*.py/**/*.go/**/*.php
    │   └── style.md             ← paths: **/*.scss/**/*.css
    └── agents/                  ← 공식 에이전트 정의 파일
        ├── scene-explorer.md    ← Three.js 전용 Explore agent
        └── php-explorer.md      ← PHP 전용 Explore agent
```

### 에이전트 파일 공식 포맷

```markdown
---
name: scene-explorer
description: Use when exploring Three.js scene structure, objects, shaders,
  theatre bindings, or runtime relationships in resource/ts/. Use for tasks
  involving Engine, Scene, AppManager, WorksSceneManager, Theatre bindings.
tools: Read, Grep, Glob
model: haiku
disallowedTools: Write, Edit, Bash
---

You are a read-only Three.js architecture explorer for this project.
Focus on: scene graph ownership, lifecycle methods, disposal patterns,
Theatre bindings, and runtime coordination.
Report file paths and line numbers for every finding.
```

### 전역 에이전트 (`~/.claude/agents/`) 패턴

프로젝트 무관 공통 에이전트는 `~/.claude/agents/`에 정의:
```markdown
---
name: code-reviewer
description: Use proactively after significant code changes for quality review.
tools: Read, Grep, Glob
model: sonnet
---
```

### SessionEnd 훅 (cleanup)

```json
"SessionEnd": [{
  "hooks": [{
    "type": "command",
    "async": true,
    "command": "powershell.exe -NonInteractive -File \"C:/Users/edn_y/.claude/cleanup.ps1\""
  }]
}]
```

### active-projects.json 등록

```json
{ "pinned": ["c--Users-edn-y-<project-folder>"] }
```

### MEMORY.md 초기화 (200줄 제한 엄수)

```markdown
# Memory Index — <PROJECT NAME>

- [Project Architecture](project_architecture.md) — 스택·라우팅·핵심 패턴
- [Development Workflow](project_workflow.md) — rtk 커맨드·금지 커맨드·agent 위임
- [Session Workflow](feedback_session_workflow.md) — /clear·explorer·parallel 룰
```

---

## 변경 파일 목록

| 파일 | 작업 |
|------|------|
| `~/.claude/settings.json` | Stop → SessionEnd + async: true |
| `~/.claude/active-projects.json` | 신규 (Project Registry) |
| `~/.claude/cleanup.ps1` | Registry 기반 + stdin payload 수신 |
| `~/.claude/templates/project-init.md` | 신규 (공식 패턴 포함 부트스트랩 가이드) |

## 보존

- CLAUDE.md · RTK.md ✅
- memory/*.md ✅
- BEST_PRACTICES.md · AGENTS.md ✅

## 검증

1. `cat settings.json` — SessionEnd 훅 확인, Stop 제거 확인
2. cleanup.ps1 수동 실행 → cleanup.log 정상 기록
3. `cat active-projects.json` — pinned 배열 확인
4. templates/project-init.md 존재 확인

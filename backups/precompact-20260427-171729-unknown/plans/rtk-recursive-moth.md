# 글로벌 .claude — SessionStart 훅 활성화 + 자동 핀 등록

## Context

이전 작업에서 글로벌 .claude 정비 완료 (settings.json, cleanup.ps1, CLAUDE.md, 메모리 이관 등). 이번엔 **빠져있던 SessionStart 훅 활성화**.

`D:\.claude\hooks\` 에 이미 스크립트 4개가 준비되어 있지만 `settings.json` 에 SessionStart 훅이 한 번도 등록된 적 없어서 **지금까지 한 번도 실행되지 않았음**.

---

## 현황 파악

### hooks/ 스크립트 4개 (이미 잘 작성됨)

| 파일 | 역할 | 상태 |
|---|---|---|
| [session-start.ps1:1-9](D:/.claude/hooks/session-start.ps1) | 진입점. check-updates + archive-plans 호출 | ✅ 완성 — 하지만 등록 안 됨 |
| [check-updates.ps1:1-28](D:/.claude/hooks/check-updates.ps1) | 24시간 게이트 후 워커 백그라운드 spawn | ✅ 완성 |
| [check-updates-worker.ps1](D:/.claude/hooks/check-updates-worker.ps1) | 공식 문서 SHA256 변경 감지 + docs-updates.md 기록 | ✅ 완성 |
| [archive-plans.ps1:1-22](D:/.claude/hooks/archive-plans.ps1) | 60일 이상 플랜 파일 → plans/archive/ 이동 | ✅ 완성 |

### settings.json 현황

**SessionStart 훅 없음.** PreToolUse(rtk) + SessionEnd(cleanup.ps1) 만 등록됨.
→ [D:\.claude\settings.json](D:/.claude/settings.json)

### active-projects.json

현재 pinned: `["d------------------260427"]` 단일 항목. 신규 프로젝트 진입 시 수동 등록 필요.

---

## 변경 계획

### 1. settings.json — SessionStart 훅 등록

**파일**: [D:\.claude\settings.json](D:/.claude/settings.json)

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "powershell.exe -NonInteractive -File \"D:/.claude/hooks/session-start.ps1\"",
        "async": true
      }
    ]
  }
]
```

- `async: true` — 세션 시작 블로킹 없음 (check-updates.ps1 자체도 <100ms 설계)
- 기존 check-updates + archive-plans 가 즉시 활성화됨

### 2. auto-pin.ps1 신규 생성

**파일**: `D:\.claude\hooks\auto-pin.ps1` (신규)

역할: 세션 시작 시 현재 프로젝트 폴더를 탐지해 active-projects.json 에 자동 등록.

로직:
1. SessionStart payload (`stdin`) 에서 `cwd` 추출 시도
2. cwd 마지막 세그먼트 (e.g., `260427`) 로 `D:\.claude\projects\` 내 폴더 부분 일치 탐색
3. 찾으면 pinned 에 추가 (중복 방지 — `$pinned -notcontains $match`)
4. cwd payload 없으면 fallback: `D:\.claude\projects\` 에서 오늘(`AddDays(0)`) 수정된 폴더 자동 추가
5. 추가 시 `D:\.claude\cleanup.log` 에 `[timestamp] auto-pin: <folder>` 기록

```powershell
# auto-pin.ps1 — idempotent, <50ms
$ErrorActionPreference = 'SilentlyContinue'
$base = 'D:\.claude'
$projectsDir = "$base\projects"
$registryPath = "$base\active-projects.json"

# SessionStart payload에서 cwd 추출
$cwd = $null
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $cwd = ($raw | ConvertFrom-Json).cwd }
} catch {}

# projects/ 에서 대상 폴더 탐색
$match = $null
if ($cwd) {
    $seg = Split-Path $cwd -Leaf   # 마지막 경로 세그먼트 (예: "260427")
    $match = Get-ChildItem $projectsDir -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -like "*$seg*" } |
             Select-Object -First 1 -ExpandProperty Name
}
# fallback: 오늘 수정된 폴더
if (-not $match) {
    $match = Get-ChildItem $projectsDir -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.LastWriteTime -gt (Get-Date).Date } |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1 -ExpandProperty Name
}

if (-not $match) { exit 0 }

# active-projects.json 업데이트 (중복 방지)
$registry = if (Test-Path $registryPath) {
    Get-Content $registryPath -Raw | ConvertFrom-Json
} else { [PSCustomObject]@{ pinned = @() } }

$pinned = @($registry.pinned)
if ($pinned -notcontains $match) {
    $pinned += $match
    $registry.pinned = $pinned
    $registry | ConvertTo-Json | Set-Content $registryPath -Encoding UTF8
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
    "[$ts] auto-pin: $match" | Add-Content "$base\cleanup.log"
}

exit 0
```

### 3. session-start.ps1 — auto-pin 호출 추가

**파일**: [D:\.claude\hooks\session-start.ps1](D:/.claude/hooks/session-start.ps1)

기존 2줄 호출에 1줄 추가:

```powershell
& "$PSScriptRoot\auto-pin.ps1"
& "$PSScriptRoot\check-updates.ps1"
& "$PSScriptRoot\archive-plans.ps1"
```

auto-pin 을 먼저 실행하는 이유: 프로젝트 탐지 후 cleanup.ps1 이 해당 세션 내에서 실행될 때 pinned 보호 받을 수 있게.

---

## 주의 사항

- `async: true` 로 실행되므로 session-start.ps1 은 stdin payload 를 받을 수 없음 → auto-pin.ps1 의 cwd 추출은 실패하고 **fallback 경로(오늘 수정된 폴더)만 동작**. 이는 문제없음 — 세션 시작 직후 projects/ 폴더가 today로 업데이트되므로.
- 대안: `async: false` 로 설정하면 stdin payload 수신 가능하지만 세션 시작이 스크립트 완료까지 대기. check-updates.ps1 이 자체적으로 <100ms 설계되어 있어 허용 가능. **→ `async: false` 권장.**

---

## 검증 방법

1. **settings.json JSON 유효성**: `powershell -Command "Get-Content D:/.claude/settings.json -Raw | ConvertFrom-Json"`
2. **session-start.ps1 dry-run**: `powershell -File D:/.claude/hooks/session-start.ps1`
   - cleanup.log 에 `auto-pin:` 라인이 찍히면 성공
   - 이미 pinned 상태라 변화 없으면 정상 (중복 추가 방지 동작)
3. **신규 프로젝트 시뮬레이션**: active-projects.json 에서 `d------------------260427` 제거 → session-start.ps1 재실행 → 다시 추가됐는지 확인 → 복구

---

## 변경하지 않을 것

- check-updates.ps1 / check-updates-worker.ps1 / archive-plans.ps1 — 이미 잘 작성됨
- cleanup.ps1 의 pinned 매칭 로직 — 부분 일치로 이미 호환

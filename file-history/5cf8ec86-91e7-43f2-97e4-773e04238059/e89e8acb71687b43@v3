# Automation Documentation System

## Context

`D:\.claude\AUTOMATION.md` (architect-quality docs)가 이미 생성됨. 남은 작업:
1. `update-docs.ps1` — SessionStart마다 AUTOMATION.md 내 마커 구간(`<!-- AUTO:SCRIPTS-START/END -->`, `<!-- AUTO:TIMESTAMP -->`)을 실제 스크립트 목록 + 타임스탬프로 교체하는 generator
2. `session-start.ps1` 업데이트 — `update-docs.ps1` 호출 추가
3. 스모크 테스트 — 마커 치환 결과 검증

이미 완료된 것: AUTOMATION.md 파일 생성 (완전한 아키텍처 문서), hooks 디렉터리 구조, 기존 3개 ps1 스크립트.

## Files to Create/Modify

| # | File | Action |
|---|---|---|
| 1 | `D:\.claude\hooks\update-docs.ps1` | 신규 생성 — 마커 기반 in-place 재생성 |
| 2 | `D:\.claude\hooks\session-start.ps1` | `update-docs.ps1` 호출 라인 추가 |

## Implementation Detail

### update-docs.ps1 로직

```
1. D:\.claude\AUTOMATION.md 존재 확인
2. hooks/*.ps1 파일 목록 → 이름 오름차순 정렬
3. 각 파일 첫 줄 주석(# ...) 읽어 description 추출
4. Markdown 표 생성: | `script.ps1` | description | YYYY-MM-DD |
5. 정규식으로 <!-- AUTO:SCRIPTS-START --> ~ <!-- AUTO:SCRIPTS-END --> 구간 치환
6. 정규식으로 <!-- AUTO:TIMESTAMP --> 앞의 날짜시간 치환
7. Set-Content -Encoding UTF8
```

주의 사항:
- PowerShell 5.1: `Get-Content -Raw`로 전체 읽고 `-replace` (regex (?s) DOTALL 플래그)
- 한글/ASCII 안전: 마커 치환만, 나머지 정적 구간 보존
- 실패해도 AUTOMATION.md를 손상시키지 않도록 — 치환 결과를 변수에 저장 후 일괄 Write

### session-start.ps1 변경

현재:
```powershell
& "$PSScriptRoot\auto-pin.ps1"
& "$PSScriptRoot\check-updates.ps1"
& "$PSScriptRoot\archive-plans.ps1"
```

변경 (update-docs를 첫 번째로 실행):
```powershell
& "$PSScriptRoot\update-docs.ps1"
& "$PSScriptRoot\auto-pin.ps1"
& "$PSScriptRoot\check-updates.ps1"
& "$PSScriptRoot\archive-plans.ps1"
```

update-docs가 먼저 실행되어야 AUTOMATION.md의 타임스탬프가 세션 시작 직후 즉시 반영됨.

## Verification

1. `powershell.exe -NonInteractive -File "D:/.claude/hooks/update-docs.ps1"` 직접 실행
2. AUTOMATION.md 열어서 확인:
   - `<!-- AUTO:SCRIPTS-START -->` ~ `<!-- AUTO:SCRIPTS-END -->` 사이에 현재 hooks/*.ps1 파일 표 생성됨
   - `**Last verified**:` 뒤 타임스탬프가 현재 시간으로 업데이트됨
3. 정적 섹션(Architecture, Design decisions 등) 보존 확인

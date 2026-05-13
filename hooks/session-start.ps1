# SessionStart entry point. Calls all session-start tasks in order.
# All called scripts are idempotent and exit fast (<100ms target combined).

$ErrorActionPreference = 'SilentlyContinue'

# D-drive remnant detection: if a previous session left D:\.claude or D:\.claude-data,
# spawn oneshot-consolidate.ps1 detached so it migrates without blocking session start.
$ClaudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$marker     = Join-Path $ClaudeRoot '.consolidation-done'
$oneshot    = Join-Path $PSScriptRoot 'oneshot-consolidate.ps1'
$dRemnant   = (Test-Path 'D:\.claude') -or (Test-Path 'D:\.claude-data') -or
              (Test-Path 'D:\migration-tmp') -or
              ((Get-ChildItem 'D:\' -Filter 'backup-claude-*.zip' -ErrorAction SilentlyContinue).Count -gt 0)

if ($dRemnant -and -not (Test-Path $marker) -and (Test-Path $oneshot)) {
    # Synchronous: must finish before auto-pin / memory-lint touch projects/.
    # Cross-drive robocopy of ~158 MB on NVMe takes 5-15s. One-time only.
    & $oneshot
}

& "$PSScriptRoot\update-docs.ps1"
& "$PSScriptRoot\auto-pin.ps1"
& "$PSScriptRoot\memory-lint.ps1"
& "$PSScriptRoot\memory-backup.ps1"
& "$PSScriptRoot\check-updates.ps1"
& "$PSScriptRoot\archive-plans.ps1"

exit 0

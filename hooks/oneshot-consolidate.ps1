# One-shot D-drive consolidation worker.
# Triggered by session-start.ps1 when D:\.claude or D:\.claude-data is detected.
# Idempotent: a marker file prevents re-runs after success. Designed to be spawned
# detached so SessionStart returns quickly while migration completes in background.

[CmdletBinding()]
param(
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Continue'

$ClaudeRoot = Join-Path $env:USERPROFILE '.claude'
$marker     = Join-Path $ClaudeRoot '.consolidation-done'
$auditLog   = Join-Path $ClaudeRoot 'cleanup.log'
$archiveDir = Join-Path $env:USERPROFILE '.claude-archive'

$names = @(
    'projects','file-history','shell-snapshots','backups','plans','reports',
    'sessions','session-env','paste-cache','downloads','telemetry','cache',
    '.docs-cache','.drift-queue'
)

function Write-Audit {
    param([string]$Line)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
    "[$ts] oneshot-consolidate: $Line" | Add-Content -Path $auditLog -ErrorAction SilentlyContinue
}

function Test-DRemnants {
    return (Test-Path 'D:\.claude') -or
           (Test-Path 'D:\.claude-data') -or
           ((Get-ChildItem 'D:\' -Filter 'backup-claude-*.zip' -ErrorAction SilentlyContinue).Count -gt 0) -or
           (Test-Path 'D:\migration-tmp')
}

function Get-VerificationReport {
    $report = [ordered]@{}
    $report['D:\.claude exists']           = Test-Path 'D:\.claude'
    $report['D:\.claude-data exists']      = Test-Path 'D:\.claude-data'
    $report['D:\migration-tmp exists']     = Test-Path 'D:\migration-tmp'
    $backups = Get-ChildItem 'D:\' -Filter 'backup-claude-*.zip' -ErrorAction SilentlyContinue
    $report['D backup zips']               = $backups.Count

    $envUser    = [System.Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','User')
    $envMachine = [System.Environment]::GetEnvironmentVariable('CLAUDE_CONFIG_DIR','Machine')
    $report['env CLAUDE_CONFIG_DIR User']    = if ($envUser)    { $envUser }    else { '<null>' }
    $report['env CLAUDE_CONFIG_DIR Machine'] = if ($envMachine) { $envMachine } else { '<null>' }

    $junctionCount = 0
    foreach ($n in $names) {
        $p = Join-Path $ClaudeRoot $n
        if (Test-Path $p) {
            $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            if ($item -and $item.LinkType -eq 'Junction') { $junctionCount++ }
        }
    }
    $report['junctions on C']                = $junctionCount

    $report['marker .consolidation-done']    = Test-Path $marker
    return $report
}

# Verify-only path: report and exit
if ($VerifyOnly) {
    Get-VerificationReport | Format-Table -AutoSize
    return
}

# Skip if marker present AND no D remnants
if ((Test-Path $marker) -and -not (Test-DRemnants)) {
    return
}

# Defensive: clear inherited env var so child commands resolve to default location
Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue

Write-Audit 'starting consolidation'

# Phase 0.A — safety net: snapshot current D:\.claude-data\ before destructive moves
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
}
$rollbackZip = Join-Path $archiveDir 'rollback-pre-consolidation.zip'
if ((Test-Path 'D:\.claude-data') -and -not (Test-Path $rollbackZip)) {
    try {
        Compress-Archive -Path 'D:\.claude-data\*' -DestinationPath $rollbackZip -CompressionLevel Optimal -Force -ErrorAction Stop
        Write-Audit "rollback zip created: $rollbackZip"
    } catch {
        Write-Audit "rollback zip FAIL: $($_.Exception.Message); aborting"
        return
    }
}

# Phase 0.B — junction removal + data move (D -> C)
$movedCount = 0
foreach ($n in $names) {
    $cPath = Join-Path $ClaudeRoot $n
    $dPath = Join-Path 'D:\.claude-data' $n

    if (Test-Path $cPath) {
        $item = Get-Item -LiteralPath $cPath -Force -ErrorAction SilentlyContinue
        if ($item.LinkType -eq 'Junction') {
            try {
                & cmd.exe /c "rmdir `"$cPath`"" 2>&1 | Out-Null
            } catch {
                Write-Audit "junction rmdir FAIL [$n]: $($_.Exception.Message)"
                continue
            }
        }
    }

    if (Test-Path $dPath) {
        try {
            $rcArgs = @($dPath, $cPath, '/MOVE', '/E', '/R:2', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
            & robocopy.exe @rcArgs | Out-Null
            $movedCount++
        } catch {
            Write-Audit "robocopy FAIL [$n]: $($_.Exception.Message)"
        }
    } else {
        if (-not (Test-Path $cPath)) {
            New-Item -ItemType Directory -Force -Path $cPath | Out-Null
        }
    }
}
Write-Audit "moved $movedCount/$($names.Count) data dirs from D to C"

# Phase 0.C — D-drive cleanup
$cleanupTargets = @(
    'D:\.claude'
    'D:\.claude-data'
    'D:\migration-tmp'
)
foreach ($t in $cleanupTargets) {
    if (Test-Path $t) {
        try {
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Stop
            Write-Audit "deleted: $t"
        } catch {
            Write-Audit "delete FAIL [$t]: $($_.Exception.Message)"
        }
    }
}

# Move D backup zips to C archive
Get-ChildItem 'D:\' -Filter 'backup-claude-*.zip' -ErrorAction SilentlyContinue | ForEach-Object {
    $dst = Join-Path $archiveDir $_.Name
    try {
        Move-Item -LiteralPath $_.FullName -Destination $dst -Force -ErrorAction Stop
        Write-Audit "archived backup: $($_.Name)"
    } catch {
        Write-Audit "backup archive FAIL [$($_.Name)]: $($_.Exception.Message)"
    }
}

# Recycle Bin claude artifacts (best effort)
try {
    Get-ChildItem 'D:\$RECYCLE.BIN' -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'claude' } |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
} catch {}

# Phase 6 — env var defensive removal (in case it got reset somehow)
try { [System.Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_DIR', $null, 'User') } catch {}

# Bump prefix-version.txt to invalidate prompt cache after structural change
try {
    $cacheDir = Join-Path $ClaudeRoot '.docs-cache'
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }
    $pvFile = Join-Path $cacheDir 'prefix-version.txt'
    $newVer = 1
    $newTicks = (Get-Date).Ticks
    if (Test-Path $pvFile) {
        $prev = (Get-Content $pvFile -Raw -ErrorAction SilentlyContinue).Trim() -split '\s+'
        if ($prev.Count -ge 1) { [void][long]::TryParse($prev[0], [ref]$newVer); $newVer++ }
    }
    Set-Content -Path $pvFile -Value "$newVer $newTicks" -Encoding UTF8 -NoNewline
} catch {}

# Final state check
if (-not (Test-DRemnants)) {
    Set-Content -Path $marker -Value (Get-Date -Format 'o') -Encoding UTF8 -NoNewline
    Write-Audit 'consolidation COMPLETE - marker written'
} else {
    Write-Audit 'consolidation PARTIAL - D remnants still present'
}

# Self-verification: emit summary
$report = Get-VerificationReport
$summary = ($report.GetEnumerator() | ForEach-Object { "  $($_.Key) = $($_.Value)" }) -join "`n"
Write-Audit "verification:`n$summary"

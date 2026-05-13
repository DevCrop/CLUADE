# SessionEnd cleanup: rotate plans / shell-snapshots / file-history / projects / session-env / backups,
# verify MEMORY.md link integrity, and cull stale background workers.

$base = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$logFile = "$base\cleanup.log"

# SessionEnd payload (informational only: source / end_reason)
$hookData = $null
try {
    $rawInput = [Console]::In.ReadToEnd()
    if ($rawInput) { $hookData = $rawInput | ConvertFrom-Json }
} catch {}

# Project registry: pinned projects are protected from rotation
$registryPath = "$base\active-projects.json"
$registry = if (Test-Path $registryPath) {
    Get-Content $registryPath -Raw | ConvertFrom-Json
} else { $null }
$pinned = if ($registry -and $registry.pinned) { $registry.pinned } else { @() }

# plans/: delete files older than 2 days
$plansDeleted = 0
Get-ChildItem "$base\plans" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-2) } |
    ForEach-Object { Remove-Item $_.FullName -Force; $plansDeleted++ }

# shell-snapshots/: delete files older than 7 days
$ssDeleted = 0
Get-ChildItem "$base\shell-snapshots" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    ForEach-Object { Remove-Item $_.FullName -Force; $ssDeleted++ }

# file-history/: delete UUID dirs older than 14 days
$fhDeleted = 0
Get-ChildItem "$base\file-history" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force; $fhDeleted++ }

# projects/: registry-pinned + recency guard (OCP/DIP)
$projDeleted = 0
Get-ChildItem "$base\projects" -Directory -ErrorAction SilentlyContinue |
    Where-Object {
        $name = $_.Name
        $isPinned = $pinned | Where-Object { $name -like "*$_*" }
        $isRecent = $_.LastWriteTime -gt (Get-Date).AddDays(-14)
        -not $isPinned -and -not $isRecent -and
        $_.LastWriteTime -lt (Get-Date).AddDays(-30)
    } |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force; $projDeleted++ }

# session-env/: drop empty subdirectories
$seDeleted = 0
Get-ChildItem "$base\session-env" -Directory -ErrorAction SilentlyContinue |
    Where-Object { (Get-ChildItem $_.FullName -Force).Count -eq 0 } |
    ForEach-Object { Remove-Item $_.FullName -Force; $seDeleted++ }

# backups/: precompact-* >28 days, memory-*.zip >56 days
$backupsDeleted = 0
Get-ChildItem "$base\backups" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'precompact-*' -and $_.LastWriteTime -lt (Get-Date).AddDays(-28) } |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force; $backupsDeleted++ }
Get-ChildItem "$base\backups" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'memory-*.zip' -and $_.LastWriteTime -lt (Get-Date).AddDays(-56) } |
    ForEach-Object { Remove-Item $_.FullName -Force; $backupsDeleted++ }

# Extended retention (gap fill): cap unbounded growth in volatile dirs
$cacheDeleted = 0
$extendedRotations = @(
    @{ Path = "$base\.docs-cache";  Days = 90; Type = 'File' }
    @{ Path = "$base\.drift-queue"; Days =  7; Type = 'File' }
    @{ Path = "$base\cache";        Days = 14; Type = 'File' }
    @{ Path = "$base\downloads";    Days = 30; Type = 'File' }
    @{ Path = "$base\paste-cache";  Days =  7; Type = 'File' }
    @{ Path = "$base\telemetry";    Days = 30; Type = 'File' }
)
foreach ($r in $extendedRotations) {
    if (-not (Test-Path $r.Path)) { continue }
    Get-ChildItem $r.Path -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$r.Days) } |
        ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue; $cacheDeleted++ }
}

# MEMORY.md reference integrity (per project)
Get-ChildItem "$base\projects" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $memoryDir = Join-Path $_.FullName 'memory'
    $memIndex = Get-Content "$memoryDir\MEMORY.md" -ErrorAction SilentlyContinue
    if ($memIndex) {
        $memIndex | Select-String '\[.*\]\(([^)]+\.md)\)' | ForEach-Object {
            $ref = $_.Matches[0].Groups[1].Value
            if ($ref -notlike 'http*' -and -not (Test-Path "$memoryDir\$ref")) {
                "[$timestamp] WARN: MEMORY.md ($($memoryDir)) references missing file: $ref" | Add-Content $logFile
            }
        }
    }
}

# Stale hook workers (>24h): kill leftover powershell processes tied to <ClaudeRoot>\hooks\
$workerKilled = 0
try {
    $hooksPathRegex = [regex]::Escape((Join-Path $base 'hooks')) + '\\'
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match $hooksPathRegex } |
        Where-Object { $_.CreationDate -lt (Get-Date).AddHours(-24) } |
        ForEach-Object {
            try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop; $workerKilled++ } catch {}
        }
} catch {}

# Audit log row
$endReason = if ($hookData -and $hookData.source) { $hookData.source }
              elseif ($hookData -and $hookData.end_reason) { $hookData.end_reason }
              else { 'unknown' }
"[$timestamp] end:$endReason plans:$plansDeleted shell-snapshots:$ssDeleted file-history:$fhDeleted projects:$projDeleted session-env:$seDeleted backups:$backupsDeleted cache-files:$cacheDeleted workers:$workerKilled" |
    Add-Content $logFile

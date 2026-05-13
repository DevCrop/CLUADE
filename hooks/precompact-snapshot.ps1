# PreCompact hook: snapshot project memory + active plans via hard-links.
# Disk cost is effectively zero on NTFS. Falls back to copy if hard-link is unsupported.

$ErrorActionPreference = 'SilentlyContinue'

$sessionId = 'unknown'
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) {
        $obj = $raw | ConvertFrom-Json
        if ($obj.session_id) { $sessionId = $obj.session_id }
    }
} catch {}

$ClaudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$ts   = Get-Date -Format 'yyyyMMdd-HHmmss'
$snap = Join-Path $ClaudeRoot "backups\precompact-$ts-$sessionId"
New-Item -ItemType Directory -Force -Path $snap | Out-Null

function Add-Snapshot {
    param([string]$Source, [string]$DestDir)
    if (-not (Test-Path $Source)) { return }
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    Get-ChildItem $Source -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = Join-Path $DestDir $_.Name
        try {
            New-Item -ItemType HardLink -Path $dest -Target $_.FullName -ErrorAction Stop | Out-Null
        } catch {
            Copy-Item -Path $_.FullName -Destination $dest -Force
        }
    }
}

# Memory: per-project memory dirs (active set: modified within last 30 days)
$cutoff = (Get-Date).AddDays(-30)
Get-ChildItem (Join-Path $ClaudeRoot 'projects') -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $cutoff } |
    ForEach-Object {
        $memDir = Join-Path $_.FullName 'memory'
        Add-Snapshot -Source $memDir -DestDir (Join-Path $snap "memory_$($_.Name)")
    }

# Plans: active plan files
Add-Snapshot -Source (Join-Path $ClaudeRoot 'plans') -DestDir (Join-Path $snap 'plans')

# Rule files: load-bearing artifacts that the next turn must keep coherent
$ruleSnap = Join-Path $snap 'rules'
New-Item -ItemType Directory -Force -Path $ruleSnap | Out-Null
$ruleFiles = @('CLAUDE.md','RTK.md','AUTOMATION.md','settings.json','active-projects.json')
foreach ($f in $ruleFiles) {
    $src = Join-Path $ClaudeRoot $f
    if (Test-Path $src) {
        $dst = Join-Path $ruleSnap $f
        try {
            New-Item -ItemType HardLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
        } catch {
            Copy-Item -Path $src -Destination $dst -Force
        }
    }
}

exit 0

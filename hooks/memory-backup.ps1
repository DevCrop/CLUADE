# Weekly snapshot of every project memory dir into ~/.claude/backups/memory-YYYYWW.zip.
# Idempotent: skip when this week's archive already exists. Disk-cheap and silent.

$ErrorActionPreference = 'SilentlyContinue'

$base       = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$backupsDir = Join-Path $base 'backups'
if (-not (Test-Path $backupsDir)) { New-Item -ItemType Directory -Force -Path $backupsDir | Out-Null }

$now  = Get-Date
$cal  = [Globalization.CultureInfo]::InvariantCulture.Calendar
$week = $cal.GetWeekOfYear($now, [Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
$archive = Join-Path $backupsDir ("memory-{0:D4}{1:D2}.zip" -f $now.Year, $week)
if (Test-Path $archive) { exit 0 }

$sources = @()
Get-ChildItem (Join-Path $base 'projects') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $memDir = Join-Path $_.FullName 'memory'
    if (Test-Path $memDir) { $sources += $memDir }
}
if ($sources.Count -eq 0) { exit 0 }

try {
    Compress-Archive -Path $sources -DestinationPath $archive -Force -ErrorAction Stop
} catch {}

exit 0

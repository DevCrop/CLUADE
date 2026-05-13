# PostCompact hook: verify @import chain integrity in core AI-consumed files
# AND confirm the active plan file (most recent in plans/) is still readable.
# Surfaces broken refs via stderr so Claude reacts in the next turn, and writes
# a marker file that statusline.ps1 reads to display 'compact:warn'.

$ErrorActionPreference = 'SilentlyContinue'

$ClaudeRoot   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$warnFile     = Join-Path $ClaudeRoot 'session-env\compact-warning.txt'
$warnings     = @()

function Get-BrokenImports {
    param([string]$File)
    if (-not (Test-Path $File)) { return @() }
    $body = Get-Content $File -Raw -Encoding UTF8
    if (-not $body) { return @() }
    $broken = @()
    $importMatches = [regex]::Matches($body, '@([^\s)]+\.md)')
    foreach ($m in $importMatches) {
        $ref = $m.Groups[1].Value
        $abs = if ([System.IO.Path]::IsPathRooted($ref)) {
            $ref
        } else {
            Join-Path (Split-Path $File -Parent) $ref
        }
        if (-not (Test-Path $abs)) {
            $broken += "$File -> $ref"
        }
    }
    return $broken
}

# 1. Rule file @import chains
$candidates = @(
    (Join-Path $ClaudeRoot 'CLAUDE.md'),
    (Join-Path $ClaudeRoot 'RTK.md')
)

foreach ($c in $candidates) {
    if (-not (Test-Path $c)) {
        $warnings += "missing rule file: $c"
        continue
    }
    $broken = Get-BrokenImports $c
    foreach ($b in $broken) { $warnings += "broken @import: $b" }
}

# 2. Active plan readability
$plansDir = Join-Path $ClaudeRoot 'plans'
if (Test-Path $plansDir) {
    $activePlan = Get-ChildItem $plansDir -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($activePlan) {
        try {
            $body = Get-Content $activePlan.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            if (-not $body) { $warnings += "active plan empty: $($activePlan.Name)" }
        } catch {
            $warnings += "active plan unreadable: $($activePlan.Name) - $($_.Exception.Message)"
        }
    }
}

# 3. Surface + persist
if ($warnings.Count -gt 0) {
    [Console]::Error.WriteLine('[postcompact-verify] issues:')
    foreach ($w in $warnings) { [Console]::Error.WriteLine("  - $w") }

    $envDir = Split-Path $warnFile -Parent
    if (-not (Test-Path $envDir)) { New-Item -ItemType Directory -Force -Path $envDir | Out-Null }
    $stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    "[$stamp] $($warnings.Count) issue(s):`n$(($warnings | ForEach-Object { '  - ' + $_ }) -join "`n")" |
        Set-Content -Path $warnFile -Encoding UTF8 -NoNewline
} else {
    # Clear stale warnings on a clean compact
    if (Test-Path $warnFile) { Remove-Item $warnFile -Force -ErrorAction SilentlyContinue }
}

exit 0

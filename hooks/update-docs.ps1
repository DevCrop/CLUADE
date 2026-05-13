# Regenerate AUTO-marked sections in ~/.claude/AUTOMATION.md on every session start.
# Marks supported: SCRIPTS, HOOK-EVENTS, SKILLS, TIMESTAMP. Idempotent.

$ErrorActionPreference = 'SilentlyContinue'

$ClaudeRoot   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$hooksDir     = Join-Path $ClaudeRoot 'hooks'
$skillsDir    = Join-Path $ClaudeRoot 'skills'
$docFile      = Join-Path $ClaudeRoot 'AUTOMATION.md'
$settingsFile = Join-Path $ClaudeRoot 'settings.json'
$cacheDir     = Join-Path $ClaudeRoot '.docs-cache'
$prefixVerFile = Join-Path $cacheDir 'prefix-version.txt'
$timestamp    = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'

if (-not (Test-Path $docFile)) { exit 0 }

$content = Get-Content $docFile -Raw -Encoding UTF8
if (-not $content) { exit 0 }

function Update-AutoSection {
    param(
        [string]$Body,
        [string]$Marker,
        [string]$Block
    )
    $startTag = "<!-- AUTO:$Marker-START -->"
    $endTag   = "<!-- AUTO:$Marker-END -->"
    $pattern  = '(?s)' + [regex]::Escape($startTag) + '.*?' + [regex]::Escape($endTag)
    $replacement = "$startTag`n$Block`n$endTag"
    if ($Body -match $pattern) {
        return [regex]::Replace($Body, $pattern, $replacement)
    }
    return $Body
}

# 1. SCRIPTS: hook scripts table built from first-line comments
$scriptRows = @('| Script | Description | Modified |', '|---|---|---|')
Get-ChildItem -Path $hooksDir -Filter '*.ps1' -File |
    Sort-Object Name |
    ForEach-Object {
        $desc = (Get-Content $_.FullName -TotalCount 1 -Encoding UTF8) -replace '^#\s*', '' -replace '\s+$', ''
        $modified = $_.LastWriteTime.ToString('yyyy-MM-dd')
        $scriptRows += "| ``$($_.Name)`` | $desc | $modified |"
    }
$content = Update-AutoSection -Body $content -Marker 'SCRIPTS' -Block ($scriptRows -join "`n")

# 2. HOOK-EVENTS: events registered in settings.json
$hookRows = @('| Event | Matcher | Async | Command (truncated) |', '|---|---|---|---|')
if (Test-Path $settingsFile) {
    try {
        $settings = Get-Content $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($settings.hooks) {
            $settings.hooks.PSObject.Properties | Sort-Object Name | ForEach-Object {
                $eventName = $_.Name
                foreach ($entry in @($_.Value)) {
                    $matcher = if ($entry.matcher) { $entry.matcher } else { '*' }
                    foreach ($h in @($entry.hooks)) {
                        $async = if ($h.async) { 'yes' } else { 'no' }
                        $cmd = $h.command
                        if ($cmd.Length -gt 80) { $cmd = $cmd.Substring(0, 77) + '...' }
                        $cmd = $cmd -replace '\|', '\|'
                        $hookRows += "| $eventName | $matcher | $async | ``$cmd`` |"
                    }
                }
            }
        }
    } catch { }
}
if ($hookRows.Count -le 2) { $hookRows += '| _(none registered)_ |  |  |  |' }
$content = Update-AutoSection -Body $content -Marker 'HOOK-EVENTS' -Block ($hookRows -join "`n")

# 3. SKILLS: SKILL.md frontmatter (name + description) from ~/.claude/skills/<name>/SKILL.md
$skillRows = @('| Skill | Description |', '|---|---|')
if (Test-Path $skillsDir) {
    Get-ChildItem -Path $skillsDir -Directory | Sort-Object Name | ForEach-Object {
        $skillFile = Join-Path $_.FullName 'SKILL.md'
        if (Test-Path $skillFile) {
            $head = Get-Content $skillFile -TotalCount 20 -Encoding UTF8
            $name = (($head | Where-Object { $_ -match '^name:' } | Select-Object -First 1) -replace '^name:\s*', '').Trim()
            $desc = (($head | Where-Object { $_ -match '^description:' } | Select-Object -First 1) -replace '^description:\s*', '').Trim()
            if (-not $name) { $name = $_.Name }
            $skillRows += "| ``$name`` | $desc |"
        }
    }
}
if ($skillRows.Count -le 2) { $skillRows += '| _(none registered)_ |  |' }
$content = Update-AutoSection -Body $content -Marker 'SKILLS' -Block ($skillRows -join "`n")

# 4. TIMESTAMP: replace the "Last verified" line, keep the AUTO:TIMESTAMP marker intact
$content = [regex]::Replace(
    $content,
    '\*\*Last verified\*\*: .*',
    "**Last verified**: $timestamp <!-- AUTO:TIMESTAMP -->"
)

Set-Content -Path $docFile -Value $content -Encoding UTF8 -NoNewline

# 5. prefix-version bump: detect mtime changes on rule/policy files used as prompt prefix.
# Bumping here invalidates the 1h prompt cache on the next prompt (UserPromptSubmit reads this).
try {
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }

    $watched = @(
        (Join-Path $ClaudeRoot 'CLAUDE.md'),
        (Join-Path $ClaudeRoot 'RTK.md'),
        (Join-Path $ClaudeRoot 'AUTOMATION.md')
    )
    $latestTicks = 0
    foreach ($p in $watched) {
        if (Test-Path $p) {
            $ticks = (Get-Item $p).LastWriteTimeUtc.Ticks
            if ($ticks -gt $latestTicks) { $latestTicks = $ticks }
        }
    }
    $prevTicks = 0
    $prevVersion = 0
    if (Test-Path $prefixVerFile) {
        $prev = Get-Content $prefixVerFile -Raw -ErrorAction SilentlyContinue
        if ($prev) {
            $parts = $prev.Trim() -split '\s+'
            if ($parts.Count -ge 2) {
                [void][long]::TryParse($parts[0], [ref]$prevVersion)
                [void][long]::TryParse($parts[1], [ref]$prevTicks)
            }
        }
    }
    if ($latestTicks -gt $prevTicks) {
        $newVersion = $prevVersion + 1
        Set-Content -Path $prefixVerFile -Value "$newVersion $latestTicks" -Encoding UTF8 -NoNewline
    }
} catch { }

exit 0

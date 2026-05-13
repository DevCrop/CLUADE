# Custom status line: cwd-leaf | model | effort | today's session count from token-usage.md.
# Stdin payload: { session_id, model:{id,display_name}, workspace:{current_dir,project_dir}, ... }

$ErrorActionPreference = 'SilentlyContinue'

$ClaudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }

$obj = $null
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $obj = $raw | ConvertFrom-Json }
} catch {}

$model = '?'
if ($obj -and $obj.model -and $obj.model.display_name) { $model = $obj.model.display_name }

$cwd = $null
if ($obj -and $obj.workspace -and $obj.workspace.current_dir) { $cwd = $obj.workspace.current_dir }
elseif ($obj -and $obj.cwd) { $cwd = $obj.cwd }
if (-not $cwd) { $cwd = (Get-Location).Path }
$leaf = Split-Path $cwd -Leaf

# Effort level from global settings
$effort = '?'
try {
    $settings = Get-Content (Join-Path $ClaudeRoot 'settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.effortLevel) { $effort = $settings.effortLevel }
} catch {}

# Today's session count from token-usage.md
$sessions = '0'
$tu = Join-Path $ClaudeRoot 'reports\token-usage.md'
if (Test-Path $tu) {
    $today = Get-Date -Format 'yyyy-MM-dd'
    $body  = Get-Content $tu -Raw -Encoding UTF8
    if ($body -and $body -match "(?ms)## $today\s*\r?\n(.+?)(?=\r?\n## |\z)") {
        $section = $matches[1]
        $rows = @(($section -split "`r?`n") | Where-Object { $_ -match '^\|\s*\d{2}:\d{2}\b' })
        $sessions = $rows.Count.ToString()
    }
}

# Cache hit indicator from prefix-version.txt (presence => 1h cache active)
$cacheTag = ''
if (Test-Path (Join-Path $ClaudeRoot '.docs-cache\prefix-version.txt')) { $cacheTag = ' cache:1h' }

# Compact warning: postcompact-verify writes session-env/compact-warning.txt when @import / active plan is broken
$compactTag = ''
if (Test-Path (Join-Path $ClaudeRoot 'session-env\compact-warning.txt')) { $compactTag = ' compact:warn' }

Write-Output ("{0} | {1} | effort:{2}{3}{4} | sessions:{5}" -f $leaf, $model, $effort, $cacheTag, $compactTag, $sessions)

exit 0

# UserPromptSubmit hook: inject git runtime context only when the repo is dirty.
# Skip-when-clean fast-path keeps the 1h prompt cache warm on noise-free turns.
# Output goes to stdout and gets folded into the prompt by Claude Code.

$ErrorActionPreference = 'SilentlyContinue'

# Re-entry guard against hook recursion
$depth = 0
[void][int]::TryParse($env:CLAUDE_HOOK_DEPTH, [ref]$depth)
if ($depth -ge 1) { exit 0 }
$env:CLAUDE_HOOK_DEPTH = ($depth + 1)

# Read JSON payload from stdin (cwd, session_id available)
$cwd = $null
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) {
        $payload = $raw | ConvertFrom-Json
        if ($payload.cwd) { $cwd = $payload.cwd }
    }
} catch {}
if (-not $cwd) { $cwd = (Get-Location).Path }

# Bail silently if not a git repo
if (-not (Test-Path (Join-Path $cwd '.git'))) { exit 0 }

# Quick dirty check
$porcelain = & git -C $cwd status --porcelain 2>$null
if (-not $porcelain) { exit 0 }   # clean -> no injection, prompt cache stays warm

# Dirty: collect compact runtime context (caps to keep tokens low)
$statusBlock = ($porcelain | Select-Object -First 15) -join "`n"
$logRaw = & git -C $cwd log --oneline -3 2>$null
$logBlock = if ($logRaw) { ($logRaw | Select-Object -First 3) -join "`n" } else { '' }

# Cache invalidation hint: append the prefix-version tag if it has been bumped
$cacheTag = ''
$ClaudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$prefixVerFile = Join-Path $ClaudeRoot '.docs-cache\prefix-version.txt'
if (Test-Path $prefixVerFile) {
    $pv = (Get-Content $prefixVerFile -Raw -ErrorAction SilentlyContinue)
    if ($pv) {
        $ver = ($pv.Trim() -split '\s+')[0]
        if ($ver) { $cacheTag = "<cache-bust v=`"$ver`"/>" }
    }
}

$out = "<context-runtime>`n## git status (truncated)`n$statusBlock"
if ($logBlock) { $out += "`n`n## recent commits`n$logBlock" }
$out += "`n</context-runtime>"
if ($cacheTag) { $out += "`n$cacheTag" }

Write-Output $out

exit 0

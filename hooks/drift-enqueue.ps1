# PostToolUse hook: enqueue edited file paths and dep-install commands.
# Async, fast, silent. Worker (drift-detect-worker.ps1) processes the queue at SessionEnd.

$ErrorActionPreference = 'SilentlyContinue'

# Re-entry guard
$depth = 0
[void][int]::TryParse($env:CLAUDE_HOOK_DEPTH, [ref]$depth)
if ($depth -ge 1) { exit 0 }
$env:CLAUDE_HOOK_DEPTH = ($depth + 1)

$ClaudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$queueDir = Join-Path $ClaudeRoot '.drift-queue'
if (-not (Test-Path $queueDir)) { New-Item -ItemType Directory -Force -Path $queueDir | Out-Null }

$obj = $null
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $obj = $raw | ConvertFrom-Json }
} catch {}
if (-not $obj) { exit 0 }

$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fff'
$toolName = $obj.tool_name

# Edit / Write: enqueue edited file path. Skip files inside the Claude config root or its data store
# (D:\.claude-data\) to avoid feedback loops.
if ($toolName -eq 'Edit' -or $toolName -eq 'Write') {
    $file = $null
    if ($obj.tool_input -and $obj.tool_input.file_path) { $file = $obj.tool_input.file_path }
    if ($file) {
        $rootNorm     = ($ClaudeRoot      -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
        $dataNorm     = 'd:/.claude-data'
        $fileNorm     = ($file -replace '\\', '/').ToLowerInvariant()
        $insideClaude = $fileNorm.StartsWith($rootNorm + '/') -or $fileNorm.StartsWith($dataNorm + '/')
        if (-not $insideClaude) {
            "$ts`t$file" | Add-Content -Path (Join-Path $queueDir 'enqueued.tsv') -Encoding UTF8
        }
    }
    exit 0
}

# Bash: detect dep-install patterns and route to a separate audit queue
if ($toolName -eq 'Bash') {
    $cmd = $null
    if ($obj.tool_input -and $obj.tool_input.command) { $cmd = $obj.tool_input.command }
    if ($cmd -and ($cmd -match '\b(npm install|pip install|composer require|pnpm add|yarn add)\b')) {
        "$ts`t$cmd" | Add-Content -Path (Join-Path $queueDir 'dep-audit.tsv') -Encoding UTF8
    }
}

exit 0

# Detached worker: SHA-diff Claude Code release + key official docs; append findings to docs-updates.md and queue impact sections to review-needed.md.
# No auto-edits to CLAUDE.md / AGENTS.md -- surface only, user decides.

$ErrorActionPreference = 'SilentlyContinue'

[Net.ServicePointManager]::SecurityProtocol = `
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ClaudeRoot  = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$cacheDir    = Join-Path $ClaudeRoot '.docs-cache'
$updatesFile = Join-Path $ClaudeRoot 'docs-updates.md'
$reviewFile  = Join-Path $ClaudeRoot 'review-needed.md'
$today       = Get-Date -Format 'yyyy-MM-dd'
$changes     = @()
$reviewItems = @()

function Save-Hash {
    param([string]$path, [string]$value)
    Set-Content -Path $path -Value $value -Encoding UTF8
}

function Get-CachedHash {
    param([string]$path)
    if (Test-Path $path) { return (Get-Content $path -Raw).Trim() }
    return ''
}

function Get-ContentHash {
    param([byte[]]$bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    $sha.Dispose()
    return $hash
}

# Map official-doc names to local-policy keywords. When upstream doc changes,
# we grep our policy files for these keywords and queue the matched sections.
$docKeywords = @{
    'memory'         = @('memory', 'MEMORY.md', '@import', 'auto-memory')
    'hooks'          = @('hook', 'PreToolUse', 'PostToolUse', 'UserPromptSubmit', 'SessionStart', 'SessionEnd')
    'best-practices' = @('best practice', 'BEST_PRACTICES')
    'settings'       = @('settings.json', 'permissions', 'enabledMcpjsonServers')
    'context-window' = @('context window', 'compact', 'PreCompact', 'PostCompact')
}

# Policy files to scan for impact when an upstream doc changes
$policyFiles = @(
    (Join-Path $ClaudeRoot 'CLAUDE.md'),
    (Join-Path $ClaudeRoot 'RTK.md'),
    (Join-Path $ClaudeRoot 'AUTOMATION.md')
)

function Get-ImpactLines {
    param([string]$DocName, [string[]]$Keywords)
    $hits = @()
    foreach ($pf in $policyFiles) {
        if (-not (Test-Path $pf)) { continue }
        $lines = Get-Content $pf -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($kw in $Keywords) {
                if ($lines[$i] -match [regex]::Escape($kw)) {
                    $snippet = $lines[$i].Trim()
                    if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 77) + '...' }
                    $hits += "- **upstream**: official ``$DocName.md`` changed; ``$pf`` line $($i+1) contains ``$kw``: ``$snippet``"
                    break
                }
            }
        }
    }
    return $hits
}

# 1. Claude Code CLI release tag
try {
    $headers = @{ 'User-Agent' = 'claude-code-docs-watcher' }
    $rel = Invoke-RestMethod 'https://api.github.com/repos/anthropics/claude-code/releases/latest' `
        -Headers $headers -TimeoutSec 8
    $tagFile = Join-Path $cacheDir 'release-tag.txt'
    $cached = Get-CachedHash $tagFile
    if ($rel.tag_name -and $rel.tag_name -ne $cached) {
        if ($cached -ne '') {
            $changes += "- **Claude Code release**: $($rel.tag_name) (was: $cached) -> $($rel.html_url)"
        }
        Save-Hash $tagFile $rel.tag_name
    }
} catch { }

# 2. Key official docs (SHA256 diff + impact queueing)
$docs = @(
    @{ name = 'memory';          url = 'https://code.claude.com/docs/en/memory.md' }
    @{ name = 'hooks';           url = 'https://code.claude.com/docs/en/hooks.md' }
    @{ name = 'best-practices';  url = 'https://code.claude.com/docs/en/best-practices.md' }
    @{ name = 'settings';        url = 'https://code.claude.com/docs/en/settings.md' }
    @{ name = 'context-window';  url = 'https://code.claude.com/docs/en/context-window.md' }
)

foreach ($doc in $docs) {
    try {
        $resp = Invoke-WebRequest $doc.url -TimeoutSec 8 -UseBasicParsing
        if ($resp.StatusCode -ne 200) { continue }
        $bytes = if ($resp.Content -is [byte[]]) { $resp.Content } else { [Text.Encoding]::UTF8.GetBytes($resp.Content) }
        $hash = Get-ContentHash $bytes
        $hashFile = Join-Path $cacheDir "$($doc.name).sha256"
        $cached = Get-CachedHash $hashFile
        if ($hash -ne $cached) {
            if ($cached -ne '') {
                $changes += "- **Doc updated**: $($doc.name) -> $($doc.url)"
                $kws = $docKeywords[$doc.name]
                if ($kws) {
                    $impacts = Get-ImpactLines -DocName $doc.name -Keywords $kws
                    if ($impacts) { $reviewItems += $impacts }
                }
            }
            Save-Hash $hashFile $hash
        }
    } catch { }
}

# Append docs-updates.md
if ($changes.Count -gt 0) {
    $entry = "## $today`n" + ($changes -join "`n") + "`n"
    if (-not (Test-Path $updatesFile)) {
        $header = "# Claude Code Upstream Updates`n`nAuto-generated by SessionStart hook. Review and decide what to apply.`n`n"
        Set-Content -Path $updatesFile -Value ($header + $entry) -Encoding UTF8
    } else {
        Add-Content -Path $updatesFile -Value $entry -Encoding UTF8
    }
}

# Append review-needed.md (impact queueing)
if ($reviewItems.Count -gt 0) {
    if (-not (Test-Path $reviewFile)) {
        $header = @(
            '# Review Needed (auto-generated)',
            '',
            '_Items appended by ``drift-detect-worker.ps1`` and ``check-updates-worker.ps1``. Read top-down. Resolve and remove sections._',
            ''
        ) -join "`n"
        Set-Content -Path $reviewFile -Value $header -Encoding UTF8
    }
    $content = Get-Content $reviewFile -Raw -Encoding UTF8
    $dayHeader = "## $today"
    if (-not $content -or ($content -notmatch [regex]::Escape($dayHeader))) {
        Add-Content -Path $reviewFile -Value "`n$dayHeader`n" -Encoding UTF8
    }
    foreach ($item in $reviewItems) {
        Add-Content -Path $reviewFile -Value $item -Encoding UTF8
    }
}

exit 0

# Drift detector worker: drain .drift-queue, append findings to ~/.claude/review-needed.md.
# Compares edited file paths against BEST_PRACTICES.md `<!-- DOC-REF: path -->` markers across
# all projects under ~/.claude/projects/. Idempotent per-day heading.

$ErrorActionPreference = 'SilentlyContinue'

# Re-entry guard
$depth = 0
[void][int]::TryParse($env:CLAUDE_HOOK_DEPTH, [ref]$depth)
if ($depth -ge 1) { exit 0 }
$env:CLAUDE_HOOK_DEPTH = ($depth + 1)

$ClaudeRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$queueDir   = Join-Path $ClaudeRoot '.drift-queue'
$reviewFile = Join-Path $ClaudeRoot 'review-needed.md'
if (-not (Test-Path $queueDir)) { exit 0 }

$enqueueFile  = Join-Path $queueDir 'enqueued.tsv'
$depAuditFile = Join-Path $queueDir 'dep-audit.tsv'
$findings = @()
$today = Get-Date -Format 'yyyy-MM-dd'

# Collect DOC-REF markers from any BEST_PRACTICES.md across known project paths
$bpRefs = @{}
$projectRegistry = Join-Path $ClaudeRoot 'active-projects.json'
$projectRoots = @()
if (Test-Path $projectRegistry) {
    try {
        $reg = Get-Content $projectRegistry -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($reg.projects) {
            foreach ($p in $reg.projects.PSObject.Properties) { $projectRoots += $p.Value }
        }
    } catch {}
}
# Fallback: try the obvious project paths
$projectRoots += 'd:\최신프로젝트\나인원랩스\퍼블\260427'
foreach ($root in ($projectRoots | Select-Object -Unique)) {
    $bpFile = Join-Path $root '.claude\BEST_PRACTICES.md'
    if (-not (Test-Path $bpFile)) { continue }
    $bpBody = Get-Content $bpFile -Raw -Encoding UTF8
    if (-not $bpBody) { continue }
    $matches = [regex]::Matches($bpBody, '<!--\s*DOC-REF:\s*([^\s>]+)\s*-->')
    foreach ($m in $matches) {
        $ref = $m.Groups[1].Value
        if (-not $bpRefs.ContainsKey($ref)) { $bpRefs[$ref] = $bpFile }
    }
}

# 1. File-edit drift detection
if (Test-Path $enqueueFile) {
    $editedPaths = Get-Content $enqueueFile -Encoding UTF8 |
        ForEach-Object { ($_ -split "`t", 2)[1] } |
        Where-Object { $_ } |
        Sort-Object -Unique

    foreach ($edited in $editedPaths) {
        $normalized = ($edited -replace '\\', '/').ToLowerInvariant()
        foreach ($ref in $bpRefs.Keys) {
            $refClean = (($ref -split '#')[0] -replace '\\', '/').ToLowerInvariant()
            if ($refClean -and $normalized.EndsWith($refClean)) {
                $findings += "- **drift**: ``$($bpRefs[$ref])`` references ``$ref`` which was edited (``$edited``). Re-verify the doc reference."
            }
        }
    }
    Remove-Item $enqueueFile -Force -ErrorAction SilentlyContinue
}

# 2. Dependency-install audit queue
if (Test-Path $depAuditFile) {
    $installs = Get-Content $depAuditFile -Encoding UTF8
    foreach ($line in $installs) {
        $parts = $line -split "`t", 2
        if ($parts.Count -eq 2) {
            $findings += "- **dep-audit**: ``$($parts[1])`` ran at $($parts[0]) -- verify lockfile, license, and supply-chain risk."
        }
    }
    Remove-Item $depAuditFile -Force -ErrorAction SilentlyContinue
}

if ($findings.Count -eq 0) { exit 0 }

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
foreach ($f in $findings) {
    Add-Content -Path $reviewFile -Value $f -Encoding UTF8
}

exit 0

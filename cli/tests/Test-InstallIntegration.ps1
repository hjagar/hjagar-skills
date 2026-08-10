# Subprocess-level integration tests (Phase 1.2, LOCAL-mode approval) for
# install.ps1. Runs the REAL script as a child pwsh process with
# $env:USERPROFILE sandboxed to a throwaway temp dir, so nothing ever touches
# the real user's ~/.gemini, ~/.claude, ~/.hjagar, etc.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$InstallPs1 = Join-Path $ScriptDir "..\install.ps1"

$script:Pass = 0
$script:Fail = 0

function Assert-True {
    param([string]$Desc, [bool]$Cond)
    if ($Cond) { $script:Pass++; Write-Host "ok - $Desc" }
    else { $script:Fail++; Write-Host "NOT OK - $Desc" }
}

function Invoke-Sandboxed {
    param([string[]]$ScriptArgs, [string]$HomeDir)
    $env:USERPROFILE = $HomeDir
    $out = & pwsh -NoProfile -File $InstallPs1 @ScriptArgs 2>&1 | Out-String
    return @{ Output = $out; ExitCode = $LASTEXITCODE }
}

# ---------------------------------------------------------------------------
# Phase 1.2 — threat matrix: malformed -Skill values must exit 1.
# ---------------------------------------------------------------------------
foreach ($bad in @("a b", "../x", '$(id)')) {
    $homeDir = Join-Path $env:TEMP ("install-ps1-threat-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
    $r = Invoke-Sandboxed -ScriptArgs @("-Skill", $bad) -HomeDir $homeDir
    Assert-True "malformed -Skill '$bad' exits 1" ($r.ExitCode -eq 1)
    Remove-Item $homeDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# LOCAL mode approval test: unchanged filesystem-only behavior still works.
# ---------------------------------------------------------------------------
$homeDir = Join-Path $env:TEMP ("install-ps1-local-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
$r = Invoke-Sandboxed -ScriptArgs @("-Local", "-Path", $RepoRoot, "-Skill", "req-discovery") -HomeDir $homeDir
Assert-True "LOCAL mode install (req-discovery) succeeds" ($r.ExitCode -eq 0)
Assert-True "LOCAL mode installs under requested skill name" `
    (Test-Path (Join-Path $homeDir ".gemini\skills\req-discovery\SKILL.md"))
Remove-Item $homeDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "install-integration (ps1 subprocess): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

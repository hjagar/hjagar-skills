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

# ---------------------------------------------------------------------------
# US-23 — Kiro is a kept, tested special case: a flat steering file must be
# generated at ~/.kiro/steering/<skill>.md with `inclusion: always` injected
# as the second line of the copied SKILL.md's YAML frontmatter.
# ---------------------------------------------------------------------------
$homeDir = Join-Path $env:TEMP ("install-ps1-kiro-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
$r = Invoke-Sandboxed -ScriptArgs @("-Local", "-Path", $RepoRoot, "-Skill", "req-discovery") -HomeDir $homeDir
$kiroFile = Join-Path $homeDir ".kiro\steering\req-discovery.md"
Assert-True "LOCAL mode install (req-discovery) succeeds for Kiro case" ($r.ExitCode -eq 0)
Assert-True "Kiro steering file is generated" (Test-Path $kiroFile)
if (Test-Path $kiroFile) {
    $kiroLines = Get-Content -Path $kiroFile
    Assert-True "Kiro steering file's first line is the '---' frontmatter delimiter" ($kiroLines[0] -eq "---")
    Assert-True "Kiro steering file injects 'inclusion: always' as the second line" ($kiroLines[1] -eq "inclusion: always")
}
Remove-Item $homeDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "install-integration (ps1 subprocess): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

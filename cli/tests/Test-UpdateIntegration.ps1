# Subprocess-level integration tests (Phase 1.2 threat matrix) for
# update.ps1. Runs the REAL script as a child pwsh process with
# $env:USERPROFILE sandboxed to a throwaway temp dir.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UpdatePs1 = Join-Path $ScriptDir "..\update.ps1"

$script:Pass = 0
$script:Fail = 0

function Assert-True {
    param([string]$Desc, [bool]$Cond)
    if ($Cond) { $script:Pass++; Write-Host "ok - $Desc" }
    else { $script:Fail++; Write-Host "NOT OK - $Desc" }
}

foreach ($bad in @("a b", "../x", '$(id)')) {
    $homeDir = Join-Path $env:TEMP ("update-ps1-threat-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
    $env:USERPROFILE = $homeDir
    & pwsh -NoProfile -File $UpdatePs1 -Skill $bad *> $null
    $exitCode = $LASTEXITCODE
    Assert-True "malformed -Skill '$bad' exits 1" ($exitCode -eq 1)
    Remove-Item $homeDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "update-integration (ps1 subprocess): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

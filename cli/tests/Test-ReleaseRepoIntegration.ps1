# Subprocess-level integration tests (PR2, US-17 Phase 1.4 / 4.3) for
# Release-Repo.ps1's D6 preflight guard. Runs Release-Repo.ps1 as a REAL
# child pwsh process against a throwaway scratch git "monorepo", with a fake
# gh/shellcheck shimmed onto PATH (see cli/tests/fixtures/release-bin/) so
# `gh`'s answer is deterministic and no test ever makes a real network call.
# A real, unrestricted `git` is still used so the actual git-repo-selection
# logic under test is real, not stubbed. Nothing here ever touches this
# repo's own git state. `Compress-Archive` (native PowerShell, no external
# `zip` dependency) packages the release.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$ReleaseRepoPs1Src = Join-Path $RepoRoot "cli\Release-Repo.ps1"
$QualityGateSrc = Join-Path $RepoRoot "cli\lib\quality-gate.ps1"
$PayloadShSrc = Join-Path $RepoRoot "cli\lib\skill-payload.sh"
$PayloadPs1Src = Join-Path $RepoRoot "cli\lib\skill-payload.ps1"
$FixturesBin = Join-Path $ScriptDir "fixtures\release-bin"

$script:Pass = 0
$script:Fail = 0

function Assert-True {
    param([string]$Desc, [bool]$Cond)
    if ($Cond) { $script:Pass++; Write-Host "ok - $Desc" }
    else { $script:Fail++; Write-Host "NOT OK - $Desc" }
}

function Assert-Contains {
    param([string]$Desc, [string]$Haystack, [string]$Needle)
    if ($Haystack -and $Haystack.Contains($Needle)) { $script:Pass++; Write-Host "ok - $Desc" }
    else { $script:Fail++; Write-Host "NOT OK - $Desc (expected to find [$Needle])" }
}

# Builds a fresh scratch "monorepo" at $Dir containing exactly what
# Release-Repo.ps1 needs: a skill directory, cli/lib/*, and the script under
# test itself — so `git rev-parse --show-toplevel` resolves to the scratch
# root and `. (Join-Path $repoRoot "cli/lib/quality-gate.ps1")` finds it
# there.
function New-ScratchRepo {
    param([string]$Dir)
    if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $Dir "skills\test-skill") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Dir "cli\lib") -Force | Out-Null

    $skillMd = @"
---
name: test-skill
description: "fixture skill for Release-Repo.ps1 integration tests"
metadata:
  version: "1.0.0"
---
Fixture body.
"@
    Set-Content -Path (Join-Path $Dir "skills\test-skill\SKILL.md") -Value $skillMd

    Copy-Item -Path $QualityGateSrc -Destination (Join-Path $Dir "cli\lib\quality-gate.ps1") -Force
    Copy-Item -Path $PayloadShSrc -Destination (Join-Path $Dir "cli\lib\skill-payload.sh") -Force
    Copy-Item -Path $PayloadPs1Src -Destination (Join-Path $Dir "cli\lib\skill-payload.ps1") -Force
    Copy-Item -Path $ReleaseRepoPs1Src -Destination (Join-Path $Dir "cli\Release-Repo.ps1") -Force

    Push-Location $Dir
    try {
        git init -q
        git checkout -q -b main 2>$null
        if ($LASTEXITCODE -ne 0) { git branch -q -m main }
        git config user.email "release-repo-test@example.com"
        git config user.name "Release Repo Test"
        git add -A
        git commit -q -m "scratch repo init"
    } finally {
        Pop-Location
    }
}

function Invoke-ReleaseRepoPs1 {
    param(
        [string]$Dir,
        [hashtable]$ExtraEnv = @{}
    )
    $homeDir = Join-Path $env:TEMP ("release-repo-ps1-home-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $homeDir -Force | Out-Null

    $origPath = $env:Path
    $origVars = @{}
    try {
        $env:Path = "$FixturesBin;$origPath"
        $env:USERPROFILE = $homeDir
        foreach ($key in $ExtraEnv.Keys) {
            $origVars[$key] = [System.Environment]::GetEnvironmentVariable($key)
            [System.Environment]::SetEnvironmentVariable($key, $ExtraEnv[$key])
        }

        Push-Location $Dir
        try {
            $out = "y" | & pwsh -NoProfile -File (Join-Path $Dir "cli\Release-Repo.ps1") -Skill "test-skill" -ReleaseType "patch" 2>&1 | Out-String
            return @{ Output = $out; ExitCode = $LASTEXITCODE }
        } finally {
            Pop-Location
        }
    } finally {
        $env:Path = $origPath
        foreach ($key in $ExtraEnv.Keys) {
            [System.Environment]::SetEnvironmentVariable($key, $origVars[$key])
        }
        Remove-Item $homeDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Scenario (Phase 1.4): an extra `upstream` remote misconfiguration causes
# `gh` to resolve a different base repo than `origin` — D6 preflight MUST
# abort before any tag or push, with no tag created.
# ---------------------------------------------------------------------------
$scratchA = Join-Path $env:TEMP ("release-repo-ps1-scratchA-" + [Guid]::NewGuid())
New-ScratchRepo -Dir $scratchA

Push-Location $scratchA
try {
    git remote add origin "https://github.com/hjagar/hjagar-skills.git"
    git remote add upstream "https://github.com/someone-else/other-repo.git"
} finally {
    Pop-Location
}

$resultA = Invoke-ReleaseRepoPs1 -Dir $scratchA
Assert-True "extra upstream remote: Release-Repo.ps1 exits non-zero" ($resultA.ExitCode -eq 1)
Assert-Contains "extra upstream remote: preflight names the mismatch" $resultA.Output "publish target mismatch"
Assert-Contains "extra upstream remote: error names the wrongly-resolved repo" $resultA.Output "someone-else/other-repo"
Assert-Contains "extra upstream remote: error names the expected repo" $resultA.Output "hjagar/hjagar-skills"

Push-Location $scratchA
try {
    $tagListA = git tag -l
} finally {
    Pop-Location
}
Assert-True "extra upstream remote: no git tag was created" (-not $tagListA)

# ---------------------------------------------------------------------------
# Scenario (Phase 4.3 regression guard): matching publish target — preflight
# passes and the normal tag+push+release flow completes.
# ---------------------------------------------------------------------------
$scratchB = Join-Path $env:TEMP ("release-repo-ps1-scratchB-" + [Guid]::NewGuid())
New-ScratchRepo -Dir $scratchB
$bareOrigin = Join-Path $env:TEMP ("release-repo-ps1-origin-" + [Guid]::NewGuid())
git init -q --bare $bareOrigin | Out-Null

Push-Location $scratchB
try {
    git remote add origin $bareOrigin
    git push -q origin main
} finally {
    Pop-Location
}

$resultB = Invoke-ReleaseRepoPs1 -Dir $scratchB -ExtraEnv @{ FAKE_REPO_VIEW_RESULT = "hjagar/hjagar-skills" }
Assert-True "matching publish target: Release-Repo.ps1 succeeds end-to-end" ($resultB.ExitCode -eq 0)
Assert-Contains "matching publish target: publish target confirmed message shown" $resultB.Output "Publish target confirmed: hjagar/hjagar-skills"
Assert-Contains "matching publish target: reaches the final Done message" $resultB.Output "Done. Release test-skill-v1.0.1 published."

Push-Location $scratchB
try {
    $tagListB = git tag -l
} finally {
    Pop-Location
}
Assert-Contains "matching publish target: tag was created" ($tagListB -join "`n") "test-skill-v1.0.1"

# ---------------------------------------------------------------------------
# Scenario (Phase 1.4, triangulation): gh cannot resolve any repo at all —
# must also abort before tag/push, with a distinct, named error.
# ---------------------------------------------------------------------------
$scratchC = Join-Path $env:TEMP ("release-repo-ps1-scratchC-" + [Guid]::NewGuid())
New-ScratchRepo -Dir $scratchC

Push-Location $scratchC
try {
    git remote add origin "https://github.com/hjagar/hjagar-skills.git"
} finally {
    Pop-Location
}

$resultC = Invoke-ReleaseRepoPs1 -Dir $scratchC -ExtraEnv @{ FAKE_REPO_VIEW_EMPTY = "1" }
Assert-True "gh cannot resolve any repo: Release-Repo.ps1 exits non-zero" ($resultC.ExitCode -eq 1)
Assert-Contains "gh cannot resolve any repo: distinct error explains the cause" $resultC.Output "could not resolve the publish target repo"

Push-Location $scratchC
try {
    $tagListC = git tag -l
} finally {
    Pop-Location
}
Assert-True "gh cannot resolve any repo: no git tag was created" (-not $tagListC)

Remove-Item $scratchA, $scratchB, $scratchC, $bareOrigin -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "release-repo-integration (ps1 subprocess): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

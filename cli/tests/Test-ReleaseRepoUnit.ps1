# Unit tests (PR2, US-17 Phase 4.3): Test-PublishTarget (D6 preflight guard)
# + New-ReleaseStagingPayload/Compress-ReleasePayload (D4 zip layout) in
# Release-Repo.ps1. Dot-sourcing Release-Repo.ps1 is safe because it is
# guarded (`if ($MyInvocation.InvocationName -ne '.') { Main }`) — no git
# tag/push/gh release create/prerequisite-check side effects run.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReleaseRepoPs1 = Join-Path $ScriptDir "..\Release-Repo.ps1"

$script:Pass = 0
$script:Fail = 0

function Assert-Eq {
    param([string]$Desc, $Expected, $Actual)
    if ($Expected -eq $Actual) {
        $script:Pass++
        Write-Host "ok - $Desc"
    } else {
        $script:Fail++
        Write-Host "NOT OK - $Desc (expected [$Expected], got [$Actual])"
    }
}

function Assert-True {
    param([string]$Desc, [bool]$Cond)
    if ($Cond) {
        $script:Pass++
        Write-Host "ok - $Desc"
    } else {
        $script:Fail++
        Write-Host "NOT OK - $Desc"
    }
}

function Assert-Contains {
    param([string]$Desc, [string]$Haystack, [string]$Needle)
    if ($Haystack -and $Haystack.Contains($Needle)) {
        $script:Pass++
        Write-Host "ok - $Desc"
    } else {
        $script:Fail++
        Write-Host "NOT OK - $Desc (expected [$Haystack] to contain [$Needle])"
    }
}

# --- Sourcing safety ---------------------------------------------------------
# Dot-sourcing must be a pure no-op (no prerequisite checks, no banner, no git
# side effects) — that's the whole point of guarding Main().
$sourceOutput = . $ReleaseRepoPs1 2>&1 | Out-String
Assert-Eq "dot-sourcing Release-Repo.ps1 produces no output (Main() did not run)" "" $sourceOutput.Trim()

Assert-Eq "REPO constant is the monorepo" "hjagar/hjagar-skills" $REPO
Assert-True "Main is defined as a function after dot-sourcing" ((Get-Command Main -ErrorAction SilentlyContinue) -ne $null)

# --- Test-PublishTarget (US-17 D6 preflight, pure) --------------------------

Assert-True "matching publish target accepted" (Test-PublishTarget -Expected "hjagar/hjagar-skills" -Actual "hjagar/hjagar-skills")
Assert-True "mismatched publish target rejected" (-not (Test-PublishTarget -Expected "hjagar/hjagar-skills" -Actual "someone-else/other-repo"))
Assert-True "empty resolved repo (gh failed) rejected" (-not (Test-PublishTarget -Expected "hjagar/hjagar-skills" -Actual ""))

# Triangulation: a second, different mismatch pair must also be rejected.
Assert-True "second mismatched pair (legacy mirror repo) also rejected" `
    (-not (Test-PublishTarget -Expected "hjagar/hjagar-skills" -Actual "hjagar/us-refinement"))

# Error TEXT assertions run via a nested subprocess: Test-PublishTarget's
# error writer uses [Console]::Error.WriteLine (matching install.ps1's
# Write-NoReleaseError convention - real, undecorated stderr text for CLI
# users), which bypasses PowerShell's own error stream and is therefore only
# capturable via `2>&1` at the OS process boundary, not from an in-process
# function call within this same session (cli/tests/test-parity.sh uses the
# identical nested-subprocess technique for the same reason).
$errOutput = pwsh -NoProfile -Command "
    . '$ReleaseRepoPs1' | Out-Null
    Test-PublishTarget -Expected 'hjagar/hjagar-skills' -Actual 'someone-else/other-repo' | Out-Null
" 2>&1 | Out-String
Assert-Contains "mismatch error names the resolved repo" $errOutput "someone-else/other-repo"
Assert-Contains "mismatch error names the expected repo" $errOutput "hjagar/hjagar-skills"
Assert-Contains "mismatch error mentions aborting before tag/push" $errOutput "Aborting before any tag or push"

$errOutputEmpty = pwsh -NoProfile -Command "
    . '$ReleaseRepoPs1' | Out-Null
    Test-PublishTarget -Expected 'hjagar/hjagar-skills' -Actual '' | Out-Null
" 2>&1 | Out-String
Assert-Contains "empty-resolution error explains the cause" $errOutputEmpty "could not resolve the publish target repo"

# --- New-ReleaseStagingPayload (US-17 D4, pure filesystem staging) ---------

$stageTmp = Join-Path $env:TEMP ("release-repo-stage-" + [Guid]::NewGuid())
$fakeRepoRoot = Join-Path $stageTmp "repo-root"
$fakeSkillDir = Join-Path $fakeRepoRoot "skills\req-discovery"
$stagingDir = Join-Path $stageTmp "staging"

New-Item -ItemType Directory -Path (Join-Path $fakeRepoRoot "cli\lib") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fakeSkillDir "assets") -Force | Out-Null
Set-Content -Path (Join-Path $fakeSkillDir "SKILL.md") -Value "# req-discovery SKILL.md"
Set-Content -Path (Join-Path $fakeSkillDir "assets\example.txt") -Value "asset content"
Set-Content -Path (Join-Path $fakeRepoRoot "cli\lib\skill-payload.sh") -Value "#!/usr/bin/env bash"
Set-Content -Path (Join-Path $fakeRepoRoot "cli\lib\skill-payload.ps1") -Value "# ps1 payload"

New-ReleaseStagingPayload -RepoRoot $fakeRepoRoot -SkillName "req-discovery" -SkillDir $fakeSkillDir -StagingDir $stagingDir

Assert-True "staged skill SKILL.md exists under skills/<name>" `
    (Test-Path (Join-Path $stagingDir "skills\req-discovery\SKILL.md"))
Assert-Eq "staged skill SKILL.md content matches source" `
    (Get-Content (Join-Path $fakeSkillDir "SKILL.md") -Raw) (Get-Content (Join-Path $stagingDir "skills\req-discovery\SKILL.md") -Raw)
Assert-True "staged skill nested asset preserved (not flattened)" `
    (Test-Path (Join-Path $stagingDir "skills\req-discovery\assets\example.txt"))
Assert-True "cli/lib/skill-payload.sh staged" (Test-Path (Join-Path $stagingDir "cli\lib\skill-payload.sh"))
Assert-True "cli/lib/skill-payload.ps1 staged" (Test-Path (Join-Path $stagingDir "cli\lib\skill-payload.ps1"))
Assert-Eq "staged skill-payload.sh content matches source" `
    (Get-Content (Join-Path $fakeRepoRoot "cli\lib\skill-payload.sh") -Raw) (Get-Content (Join-Path $stagingDir "cli\lib\skill-payload.sh") -Raw)
Assert-True "no flat top-level SKILL.md (legacy flat-zip regression not present)" `
    (-not (Test-Path (Join-Path $stagingDir "SKILL.md")))

# Triangulation: a second, differently-named skill with different content
# stages correctly too, and New-ReleaseStagingPayload leaves no
# cross-contamination from the first call.
$fakeSkillDir2 = Join-Path $fakeRepoRoot "skills\tc-generator"
New-Item -ItemType Directory -Path $fakeSkillDir2 -Force | Out-Null
Set-Content -Path (Join-Path $fakeSkillDir2 "SKILL.md") -Value "# tc-generator SKILL.md"

New-ReleaseStagingPayload -RepoRoot $fakeRepoRoot -SkillName "tc-generator" -SkillDir $fakeSkillDir2 -StagingDir $stagingDir

Assert-True "second staging call: staged under the NEW skill name" `
    (Test-Path (Join-Path $stagingDir "skills\tc-generator\SKILL.md"))
Assert-True "second staging call: previous skill's directory is gone (no cross-contamination)" `
    (-not (Test-Path (Join-Path $stagingDir "skills\req-discovery")))

# --- Compress-ReleasePayload (US-17 D4) -------------------------------------

$zipPath = Join-Path $stageTmp "build\tc-generator.zip"
Compress-ReleasePayload -StagingDir $stagingDir -ZipPath $zipPath

Assert-True "Compress-ReleasePayload created the zip file" (Test-Path $zipPath)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
$entries = $zip.Entries | ForEach-Object { $_.FullName }
$zip.Dispose()

Assert-True "zip contains skills/<name>/SKILL.md" ($entries -contains "skills/tc-generator/SKILL.md")
Assert-True "zip contains cli/lib/skill-payload.sh" ($entries -contains "cli/lib/skill-payload.sh")
Assert-True "zip contains cli/lib/skill-payload.ps1" ($entries -contains "cli/lib/skill-payload.ps1")
Assert-True "no bare top-level SKILL.md entry (legacy flat-zip regression prevented)" `
    (-not ($entries -contains "SKILL.md"))

Remove-Item $stageTmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "release-repo-unit (ps1): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

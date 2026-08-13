# Unit tests (Phase 1.5 / 2.1 / 2.2 / 2.6) for install.ps1's pure functions.
# Dot-sourcing install.ps1 is safe because it is guarded
# (`if ($MyInvocation.InvocationName -ne '.') { Main }`) — no installation
# side effects run.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallPs1 = Join-Path $ScriptDir "..\install.ps1"

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

# Dot-source with bound params so $Local/$Skill/$Path exist but Main() never runs.
. $InstallPs1 -Local -Path $ScriptDir

# --- Test-SkillName ---------------------------------------------------------

Assert-True "valid skill name accepted" (Test-SkillName "req-discovery")
Assert-True "valid skill name (us-refinement) accepted" (Test-SkillName "us-refinement")
Assert-True "space in skill name rejected" (-not (Test-SkillName "a b"))
Assert-True "path traversal skill name rejected" (-not (Test-SkillName "../x"))
Assert-True "command substitution skill name rejected" (-not (Test-SkillName '$(id)'))
Assert-True "leading-dash skill name rejected" (-not (Test-SkillName "-leading-dash"))

# --- Select-HighestTag (pure — prefix boundary + 2-digit-safe semver) ------

$tags1 = @(
    "req-discovery-v1.0.0", "req-discovery-v1.10.0", "req-discovery-v1.9.0",
    "us-refinement-v2.0.0", "us-refinement-x-v9.9.9"
)

$result = Select-HighestTag -SkillName "req-discovery" -Tags $tags1
Assert-Eq "2-digit-safe semver ordering: v1.10.0 beats v1.9.0" "req-discovery-v1.10.0" $result

$result = Select-HighestTag -SkillName "us-refinement" -Tags $tags1
Assert-Eq "prefix boundary excludes lookalike skill" "us-refinement-v2.0.0" $result

$result = Select-HighestTag -SkillName "res-onboarding" -Tags $tags1
Assert-Eq "no matching tag returns null" $null $result

$tags2 = @("req-discovery-v0.1.0", "req-discovery-v0.2.0", "req-discovery-v0.10.0")
$result = Select-HighestTag -SkillName "req-discovery" -Tags $tags2
Assert-Eq "triangulation: another version set still 2-digit-safe" "req-discovery-v0.10.0" $result

# --- Get-SkillNamesFromTags (pure, US-17 D8 discover-all) ------------------

$discoveryTags = @(
    "us-refinement-v1.0.0", "req-discovery-v1.0.0", "req-discovery-v1.10.0",
    "tc-generator-v2.0.0", "us-refinement-x-v9.9.9"
)
$discovered = Get-SkillNamesFromTags -Tags $discoveryTags
Assert-Eq "discover-all extracts distinct skill names, deduped and sorted" `
    "req-discovery,tc-generator,us-refinement,us-refinement-x" ($discovered -join ',')

$discoveredEmpty = Get-SkillNamesFromTags -Tags @()
Assert-Eq "discover-all on empty tag list returns empty" 0 $discoveredEmpty.Count

$discoveredNoMatch = Get-SkillNamesFromTags -Tags @("not-a-tag", "random-text")
Assert-Eq "discover-all ignores tags not matching <skill>-vMAJOR.MINOR.PATCH" 0 $discoveredNoMatch.Count

# --- New-KiroSteeringFile (US-23 — EOL-preserving frontmatter injection) ---

$payloadLib = Join-Path $ScriptDir "..\lib\skill-payload.ps1"
. $payloadLib

$kiroSrc = Join-Path $env:TEMP ("install-unit-kiro-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $kiroSrc -Force | Out-Null
$HomeDir = Join-Path $env:TEMP ("install-unit-kiro-home-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $HomeDir -Force | Out-Null

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $kiroSrc "SKILL.md"), "---`nname: req-discovery`n---`nbody`n", $utf8NoBom)
New-KiroSteeringFile $kiroSrc "req-discovery"
$lfOut = [System.IO.File]::ReadAllText((Join-Path $HomeDir ".kiro\steering\req-discovery.md"), $utf8NoBom)
$lfLines = $lfOut -split "`n"
Assert-Eq "LF source: 'inclusion: always' injected as line 2" "inclusion: always" $lfLines[1]
Assert-True "LF source: injected line keeps LF terminator (no stray CR)" (-not ($lfOut -match "inclusion: always`r"))

[System.IO.File]::WriteAllText((Join-Path $kiroSrc "SKILL.md"), "---`r`nname: req-discovery`r`n---`r`nbody`r`n", $utf8NoBom)
New-KiroSteeringFile $kiroSrc "req-discovery"
$crlfOut = [System.IO.File]::ReadAllText((Join-Path $HomeDir ".kiro\steering\req-discovery.md"), $utf8NoBom)
Assert-True "CRLF source: injected 'inclusion: always' line keeps CRLF terminator" `
    ($crlfOut -match "inclusion: always`r`n")

Remove-Item -Path $kiroSrc -Recurse -Force
Remove-Item -Path $HomeDir -Recurse -Force

# --- Get-AgentPaths (US-24 — manifest-driven agent path list) --------------

$bapHome = Join-Path $env:TEMP ("install-unit-bap-home-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $bapHome -Force | Out-Null
$HomeDir = $bapHome

$bapResult = @(Get-AgentPaths "req-discovery") | Sort-Object
$bapExpected = @(
    (Join-Path $bapHome ".gemini\skills\req-discovery"),
    (Join-Path $bapHome ".claude\skills\req-discovery"),
    (Join-Path $bapHome ".config\opencode\skills\req-discovery"),
    (Join-Path $bapHome ".copilot\skills\req-discovery"),
    (Join-Path $bapHome ".agents\skills\req-discovery"),
    (Join-Path $bapHome ".cursor\skills\req-discovery")
) | Sort-Object
Assert-Eq "Get-AgentPaths produces every manifest-listed directory" ($bapExpected -join '|') ($bapResult -join '|')

$bapKiroMatch = @($bapResult | Where-Object { $_ -match "kiro" })
Assert-Eq "Get-AgentPaths excludes the Kiro transform entry (handled separately)" 0 $bapKiroMatch.Count
Assert-Eq "Get-AgentPaths emits exactly the 6 non-transform manifest entries" 6 $bapResult.Count
Remove-Item -Path $bapHome -Recurse -Force

# US-24 acceptance scenario 2: "new agent added" — appending one manifest
# entry (no script edits) must make it appear in the returned path list, with
# no other entry affected.
$bapManifestTmp = Join-Path $env:TEMP ("install-unit-bap-manifest-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $bapManifestTmp "lib") -Force | Out-Null

$origManifestPath = Join-Path $ScriptDir "..\agent-targets.json"
$origManifest = Get-Content -Path $origManifestPath -Raw | ConvertFrom-Json
$origManifest.targets += [PSCustomObject]@{ id = "newagent"; path_template = ".newagent/skills/{skill_name}" }
$origManifest | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $bapManifestTmp "agent-targets.json")
Copy-Item -Path $payloadLib -Destination (Join-Path $bapManifestTmp "lib\skill-payload.ps1") -Force

$bapNewHome = Join-Path $env:TEMP ("install-unit-bap-newhome-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $bapNewHome -Force | Out-Null
$bapManifestTmpWin = $bapManifestTmp
$bapNewHomeWin = $bapNewHome
$newAgentOutput = pwsh -NoProfile -Command "
    . '$bapManifestTmpWin\lib\skill-payload.ps1' | Out-Null
    `$HomeDir = '$bapNewHomeWin'
    (Get-AgentPaths 'req-discovery') -join [Environment]::NewLine
" 2>&1 | Out-String
$newAgentLines = @($newAgentOutput -split "`r?`n" | Where-Object { $_ -ne '' })
$newAgentMatch = @($newAgentLines | Where-Object { $_ -match [regex]::Escape("newagent\skills\req-discovery") })
Assert-Eq "new agent added via one manifest line appears with no script edits" 1 $newAgentMatch.Count
Assert-Eq "existing 6 entries are untouched (7 total after the new line)" 7 $newAgentLines.Count

Remove-Item -Path $bapManifestTmp -Recurse -Force
Remove-Item -Path $bapNewHome -Recurse -Force

Write-Host ""
Write-Host "install-unit (ps1): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

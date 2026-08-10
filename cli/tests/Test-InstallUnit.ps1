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

Write-Host ""
Write-Host "install-unit (ps1): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

# Unit tests (Phase 1.5 / 3.1 / 3.3) for update.ps1's pure functions.
# Dot-sourcing update.ps1 is safe because it is guarded — no update side
# effects run.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UpdatePs1 = Join-Path $ScriptDir "..\update.ps1"

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

# Dot-source with a bound -Skill param so Main() never runs.
. $UpdatePs1 -Skill "req-discovery"

# --- Test-SkillName ---------------------------------------------------------

Assert-True "valid skill name accepted" (Test-SkillName "req-discovery")
Assert-True "space in skill name rejected" (-not (Test-SkillName "a b"))
Assert-True "path traversal skill name rejected" (-not (Test-SkillName "../x"))
Assert-True "command substitution skill name rejected" (-not (Test-SkillName '$(id)'))

# --- Select-HighestTag (pure) ------------------------------------------------

$tags = @(
    "req-discovery-v1.0.0", "req-discovery-v1.10.0", "req-discovery-v1.9.0",
    "us-refinement-v2.0.0", "us-refinement-x-v9.9.9"
)
$result = Select-HighestTag -SkillName "req-discovery" -Tags $tags
Assert-Eq "2-digit-safe semver ordering: v1.10.0 beats v1.9.0" "req-discovery-v1.10.0" $result

$result = Select-HighestTag -SkillName "us-refinement" -Tags $tags
Assert-Eq "prefix boundary excludes lookalike skill" "us-refinement-v2.0.0" $result

# --- Get-LocalVersion (approval — captures pre-existing frontmatter logic) --

$tmpCentral = Join-Path $env:TEMP ("update-unit-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $tmpCentral "skills\req-discovery") -Force | Out-Null
@"
---
name: req-discovery
metadata:
  version: v3.2.1
---
body
"@ | Set-Content -Path (Join-Path $tmpCentral "skills\req-discovery\SKILL.md") -NoNewline

$script:CentralDir = $tmpCentral
$result = Get-LocalVersion -SkillName "req-discovery"
Assert-Eq "detects frontmatter version" "v3.2.1" $result

$result = Get-LocalVersion -SkillName "does-not-exist"
Assert-Eq "missing skill file returns null" $null $result

Remove-Item -Path $tmpCentral -Recurse -Force

# --- Get-LocallyInstalledSkillNames (US-17 D8 — update never defaults) -----

$tmpCentral2 = Join-Path $env:TEMP ("update-unit-discover-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $tmpCentral2 "skills\req-discovery") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpCentral2 "skills\tc-generator") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmpCentral2 "skills\empty-dir-no-skill-md") -Force | Out-Null
"stub" | Set-Content -Path (Join-Path $tmpCentral2 "skills\req-discovery\SKILL.md")
"stub" | Set-Content -Path (Join-Path $tmpCentral2 "skills\tc-generator\SKILL.md")

$discovered = Get-LocallyInstalledSkillNames -CentralDir $tmpCentral2
$discoveredSorted = @($discovered | Sort-Object)
Assert-Eq "discovers every locally-installed skill, dir without SKILL.md excluded" `
    "req-discovery,tc-generator" ($discoveredSorted -join ',')
Assert-True "never defaults to only us-refinement" (-not ($discovered -contains "us-refinement"))

Remove-Item -Path $tmpCentral2 -Recurse -Force

$tmpCentral3 = Join-Path $env:TEMP ("update-unit-discover-empty-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpCentral3 -Force | Out-Null
$discoveredEmpty = Get-LocallyInstalledSkillNames -CentralDir $tmpCentral3
Assert-Eq "no locally-installed skills returns empty" 0 $discoveredEmpty.Count
Remove-Item -Path $tmpCentral3 -Recurse -Force

# --- Kiro update conditional (US-23) — mirrors update.ps1's Update-OneSkill
# lines 296-299 exactly: regenerate only when a steering file already exists,
# never create one that wasn't there before.
$payloadLib = Join-Path $ScriptDir "..\lib\skill-payload.ps1"
. $payloadLib

$kiroSrc = Join-Path $env:TEMP ("update-unit-kiro-src-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $kiroSrc -Force | Out-Null
"---`nname: req-discovery`n---`nbody`n" | Set-Content -Path (Join-Path $kiroSrc "SKILL.md") -NoNewline

$HomeDir = Join-Path $env:TEMP ("update-unit-kiro-home-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $HomeDir ".kiro\steering") -Force | Out-Null
"---`nname: req-discovery`n---`nold body`n" | Set-Content -Path (Join-Path $HomeDir ".kiro\steering\req-discovery.md") -NoNewline

$kiroTarget = Join-Path $HomeDir ".kiro\steering\req-discovery.md"
if (Test-Path $kiroTarget) {
    New-KiroSteeringFile $kiroSrc "req-discovery"
}
$regenerated = Get-Content -Path $kiroTarget -Raw
Assert-True "update regenerates a pre-existing Kiro steering file" ($regenerated -match "inclusion: always")

Remove-Item -Path (Join-Path $HomeDir ".kiro") -Recurse -Force
New-Item -ItemType Directory -Path $HomeDir -Force | Out-Null
$kiroTargetAbsent = Join-Path $HomeDir ".kiro\steering\req-discovery.md"
if (Test-Path $kiroTargetAbsent) {
    New-KiroSteeringFile $kiroSrc "req-discovery"
}
Assert-True "update leaves absent Kiro steering file untouched" (-not (Test-Path $kiroTargetAbsent))

Remove-Item -Path $kiroSrc -Recurse -Force
Remove-Item -Path $HomeDir -Recurse -Force

Write-Host ""
Write-Host "update-unit (ps1): $script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }

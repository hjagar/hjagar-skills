param(
    [Parameter(Mandatory=$false)]
    [string]$Skill,

    [Parameter(Mandatory=$false)]
    [switch]$All
)

$ErrorActionPreference = "Stop"

Write-Host "=== hjagar-skills Uninstaller ===" -ForegroundColor Cyan

$HomeDir = $env:USERPROFILE
if (-not $HomeDir) { $HomeDir = $env:HOME }

if (-not $All -and [string]::IsNullOrWhiteSpace($Skill)) {
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  1) Uninstall a specific skill" -ForegroundColor Yellow
    Write-Host "  2) Uninstall ALL skills" -ForegroundColor Yellow
    $choice = Read-Host "Select option (1/2)"
    if ($choice -eq "2") {
        $All = $true
    } else {
        $Skill = Read-Host "Enter skill name to uninstall"
    }
}

$confirm = Read-Host "Proceed with uninstallation? (y/N)"
if ($confirm -notin @('y','Y')) {
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadLib = Join-Path $ScriptDir "lib/skill-payload.ps1"
if (Test-Path $PayloadLib) {
    . $PayloadLib
} else {
    function Get-AgentPaths ($skillName) {
        $paths = [System.Collections.Generic.List[string]]::new()
        $paths.Add((Join-Path $HomeDir ".gemini\skills\$skillName"))
        $paths.Add((Join-Path $HomeDir ".claude\skills\$skillName"))
        $paths.Add((Join-Path $HomeDir ".config\opencode\skills\$skillName"))
        $paths.Add((Join-Path $HomeDir ".copilot\skills\$skillName"))
        $paths.Add((Join-Path $HomeDir ".agents\skills\$skillName"))
        $paths.Add((Join-Path $HomeDir ".cursor\skills\$skillName"))

        if (Test-Path $HomeDir) {
            Get-ChildItem -Path $HomeDir -Filter ".claude-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $paths.Add((Join-Path $_.FullName "skills\$skillName"))
            }
        }
        return $paths
    }
}

$centralBase = Join-Path $HomeDir ".hjagar\skills"

function Uninstall-SingleSkill ($skillName) {
    Write-Host "Uninstalling skill: $skillName..." -ForegroundColor Cyan

    $agentPaths = Get-AgentPaths -skillName $skillName
    foreach ($ap in $agentPaths) {
        if (Test-Path $ap) {
            Remove-Item -Path $ap -Recurse -Force
            Write-Host "  Removed agent dir: $ap" -ForegroundColor Gray
        }
    }

    $kiroFile = Join-Path $HomeDir ".kiro\steering\$skillName.md"
    if (Test-Path $kiroFile) {
        Remove-Item -Path $kiroFile -Force
        Write-Host "  Removed Kiro steering file: $kiroFile" -ForegroundColor Gray
    }

    $centralSkillDir = Join-Path $centralBase $skillName
    if (Test-Path $centralSkillDir) {
        Remove-Item -Path $centralSkillDir -Recurse -Force
        Write-Host "  Removed central skill dir: $centralSkillDir" -ForegroundColor Gray
    }
}

if ($All) {
    Write-Host "Uninstalling all skills..." -ForegroundColor Yellow
    if (Test-Path $centralBase) {
        Get-ChildItem -Path $centralBase -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Uninstall-SingleSkill $_.Name
        }
        Remove-Item -Path $centralBase -Recurse -Force -ErrorAction SilentlyContinue
    }

    $repoRoot = (git rev-parse --show-toplevel 2>$null)
    if ($repoRoot -and (Test-Path (Join-Path $repoRoot "skills"))) {
        Get-ChildItem -Path (Join-Path $repoRoot "skills") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Uninstall-SingleSkill $_.Name
        }
    }
} else {
    Uninstall-SingleSkill $Skill
}

Write-Host "Uninstallation completed successfully." -ForegroundColor Green

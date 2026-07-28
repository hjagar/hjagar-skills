[CmdletBinding()]
param(
    [switch]$Local,
    [string]$Path,
    [string]$Skill
)

$ErrorActionPreference = "Stop"

# 1. Prerequisites Check
Write-Host "Checking prerequisites..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Error: git is required to use this skill."
    exit 1
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warning "Warning: gh CLI was not found. Issue refinement write-backs will fallback to copy/paste."
}

# 2. Path Setup
$HomeDir = $env:USERPROFILE
$CentralDir = Join-Path $HomeDir ".hjagar\skills"

$BaseDir = if ($Path) { Resolve-Path $Path } else {
    if (Test-Path (Join-Path $PSScriptRoot "..\skills")) {
        Resolve-Path (Join-Path $PSScriptRoot "..")
    } else {
        $PSScriptRoot
    }
}

function Install-Skills ($payloadLibDir, $baseSourceDir) {
    $payloadLib = Join-Path $payloadLibDir "lib\skill-payload.ps1"
    if (-not (Test-Path $payloadLib)) {
        $payloadLib = Join-Path $payloadLibDir "cli\lib\skill-payload.ps1"
    }
    if (-not (Test-Path $payloadLib)) {
        Write-Error "Error: lib\skill-payload.ps1 not found at $payloadLibDir"
        exit 1
    }
    . $payloadLib

    $skillsToInstall = @()
    $skillsDir = Join-Path $baseSourceDir "skills"

    if ($Skill) {
        $targetSkillDir = Join-Path $skillsDir $Skill
        if (Test-Path (Join-Path $targetSkillDir "SKILL.md")) {
            $skillsToInstall += @{ Name = $Skill; Source = $targetSkillDir }
        } elseif (Test-Path (Join-Path $baseSourceDir "SKILL.md")) {
            $skillsToInstall += @{ Name = $Skill; Source = $baseSourceDir }
        } else {
            Write-Error "Error: Skill '$Skill' not found at $targetSkillDir"
            exit 1
        }
    } else {
        if (Test-Path $skillsDir) {
            Get-ChildItem -Path $skillsDir -Directory | ForEach-Object {
                if (Test-Path (Join-Path $_.FullName "SKILL.md")) {
                    $skillsToInstall += @{ Name = $_.Name; Source = $_.FullName }
                }
            }
        } elseif (Test-Path (Join-Path $baseSourceDir "SKILL.md")) {
            $skillName = Split-Path -Leaf $baseSourceDir
            $skillsToInstall += @{ Name = $skillName; Source = $baseSourceDir }
        }
    }

    if ($skillsToInstall.Count -eq 0) {
        Write-Error "Error: No valid skills found to install."
        exit 1
    }

    foreach ($item in $skillsToInstall) {
        $sName = $item.Name
        $sSource = $item.Source
        Write-Host "Installing skill '$sName'..." -ForegroundColor Cyan

        $agentPaths = Get-AgentPaths $sName
        foreach ($agent in $agentPaths) {
            Copy-SkillFile $agent $sSource
        }
        New-KiroSteeringFile $sSource $sName
    }
}

# 3. Installation Logic
if ($Local) {
    Write-Host "Installing in LOCAL Mode..."
    Install-Skills $BaseDir $BaseDir
} else {
    Write-Host "Installing in GLOBAL Mode..."
    if (Test-Path $CentralDir) {
        Remove-Item -Path $CentralDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $CentralDir -Force | Out-Null
    
    $zipUrl = "https://github.com/hjagar/us-refinement/releases/latest/download/us-refinement.zip"
    $tempZip = Join-Path $env:TEMP ("us-refinement-" + [System.Guid]::NewGuid().ToString() + ".zip")
    $downloadSuccess = $false
    
    # Try downloading via gh CLI first (useful for private repos)
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Downloading latest release ZIP using GitHub CLI..."
            & gh release download --repo hjagar/us-refinement --pattern "us-refinement.zip" --output $tempZip --clobber 2>$null
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempZip)) {
                $downloadSuccess = $true
            }
        } catch {
            # Ignore and fallback
        }
    }
    
    # Fallback to Invoke-WebRequest
    if (-not $downloadSuccess) {
        try {
            Write-Host "Downloading latest release ZIP from public GitHub URL..."
            Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
            $downloadSuccess = $true
        } catch {
            Write-Error "Failed to download release ZIP: $_"
            if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
            exit 1
        }
    }
    
    try {
        Write-Host "Extracting release ZIP..."
        Expand-Archive -Path $tempZip -DestinationPath $CentralDir -Force
    } catch {
        Write-Error "Failed to extract release ZIP: $_"
        if (Test-Path $CentralDir) { Remove-Item $CentralDir -Recurse -Force }
        exit 1
    } finally {
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
    }
    
    Install-Skills $CentralDir $CentralDir
}

Write-Host "Installation completed successfully!"

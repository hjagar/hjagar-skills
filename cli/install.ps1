[CmdletBinding()]
param(
    [switch]$Local,
    [string]$Path
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
$CentralDir = Join-Path $HomeDir ".hjagar\skills\us-refinement"
$SrcDir = if ($Path) { Resolve-Path $Path } else { $PSScriptRoot }

# 3. Installation Logic
# Copy-SkillFile, New-KiroSteeringFile, and Get-AgentPaths live in lib/skill-payload.ps1
# (shared with update.ps1). Local mode dot-sources it straight from $SrcDir - a real
# checkout, always present on disk. Global mode can only dot-source it from $CentralDir
# AFTER the release ZIP has been downloaded and extracted there below, since install.ps1
# ships as a single self-contained file for the `irm <url> | iex` distribution path and
# has no sibling files available before that point.
if ($Local) {
    Write-Host "Installing us-refinement in LOCAL Mode..."
    . (Join-Path $SrcDir "lib\skill-payload.ps1")
    $AgentPaths = Get-AgentPaths
    foreach ($agent in $AgentPaths) {
        Copy-SkillFile $agent $SrcDir
    }
    New-KiroSteeringFile $SrcDir
} else {
    Write-Host "Installing us-refinement in GLOBAL Mode..."
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
    
    # Only now does $CentralDir physically contain lib/skill-payload.ps1 - dot-source it
    # from there, never before the extraction above.
    . (Join-Path $CentralDir "lib\skill-payload.ps1")
    $AgentPaths = Get-AgentPaths
    foreach ($agent in $AgentPaths) {
        Copy-SkillFile $agent $CentralDir
    }
    New-KiroSteeringFile $CentralDir
}

Write-Host "Installation completed successfully!"

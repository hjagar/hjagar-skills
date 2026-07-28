# hjagar-skills Auto-Updater for Windows
[CmdletBinding()]
param(
    [string]$Skill
)

$ErrorActionPreference = "Stop"

$HomeDir = $env:USERPROFILE
$CentralDir = Join-Path $HomeDir ".hjagar\skills"

Write-Host "Checking for updates..." -ForegroundColor Cyan

# 1. Locate reference SKILL.md to check local version
$checkSkillFile = $null
if ($Skill) {
    $targetFile = Join-Path $CentralDir "skills\$Skill\SKILL.md"
    if (Test-Path $targetFile) {
        $checkSkillFile = $targetFile
    } elseif (Test-Path (Join-Path $CentralDir "SKILL.md")) {
        $checkSkillFile = Join-Path $CentralDir "SKILL.md"
    }
} else {
    $targetFile = Join-Path $CentralDir "skills\us-refinement\SKILL.md"
    if (Test-Path $targetFile) {
        $checkSkillFile = $targetFile
    } elseif (Test-Path (Join-Path $CentralDir "SKILL.md")) {
        $checkSkillFile = Join-Path $CentralDir "SKILL.md"
    }
}

if (-not $checkSkillFile -or -not (Test-Path $checkSkillFile)) {
    Write-Error "Error: skills are not installed globally at $CentralDir. Run install.ps1 first."
    exit 1
}

$localContent = Get-Content $checkSkillFile -Raw
$localVersion = "v0.0.0"
$fm = [regex]::Match($localContent, '(?s)\A---\r?\n(.*?)\r?\n---')
if ($fm.Success -and $fm.Groups[1].Value -match '(?m)^\s*version:\s*(v[\d\.]+)\s*$') {
    $localVersion = $Matches[1]
} elseif ($localContent -match '<!-- version: (v[\d\.]+) -->') {
    $localVersion = $Matches[1]
}

Write-Host "Local version: $localVersion" -ForegroundColor Gray

# 2. Fetch latest remote version from GitHub
$repo = "hjagar/us-refinement"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"
$latestVersion = $null

try {
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $latestVersion = $release.tag_name
} catch {
    Write-Warning "Failed to query GitHub API. Check connection."
    exit 1
}

if (-not $latestVersion) {
    Write-Warning "No release version info found."
    exit 1
}

Write-Host "Latest remote version: $latestVersion" -ForegroundColor Gray

# 3. Compare versions
if ($localVersion -eq $latestVersion) {
    Write-Host "You are already on the latest version: $localVersion" -ForegroundColor Green
    exit 0
}

Write-Host "New version $latestVersion is available! Updating..." -ForegroundColor Cyan

# 4. Perform download and safe update
$zipUrl = "https://github.com/$repo/releases/latest/download/us-refinement.zip"
$tempZip = Join-Path $env:TEMP "us-refinement-update-$latestVersion.zip"
$tempExtractDir = Join-Path $env:TEMP "us-refinement-update-extract"

try {
    Write-Host "Downloading release archive..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing | Out-Null
    
    if (Test-Path $tempExtractDir) { Remove-Item $tempExtractDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tempExtractDir | Out-Null
    
    Write-Host "Extracting archive..." -ForegroundColor Gray
    Expand-Archive -Path $tempZip -DestinationPath $tempExtractDir -Force

    Write-Host "Updating central files..." -ForegroundColor Gray
    Get-ChildItem -Path $tempExtractDir -Force | ForEach-Object {
        $destPath = Join-Path $CentralDir $_.Name
        Copy-Item -Path $_.FullName -Destination $destPath -Force -Recurse
    }

    $payloadLib = Join-Path $CentralDir "lib\skill-payload.ps1"
    if (-not (Test-Path $payloadLib)) {
        $payloadLib = Join-Path $CentralDir "cli\lib\skill-payload.ps1"
    }
    if (Test-Path $payloadLib) {
        . $payloadLib
    } else {
        Write-Error "Error: lib\skill-payload.ps1 not found in $CentralDir"
        exit 1
    }

    # 5. Propagate skills to agents
    $skillsToUpdate = @()
    if ($Skill) {
        $skillsToUpdate += $Skill
    } else {
        $skillsDir = Join-Path $CentralDir "skills"
        if (Test-Path $skillsDir) {
            Get-ChildItem -Path $skillsDir -Directory | ForEach-Object {
                if (Test-Path (Join-Path $_.FullName "SKILL.md")) {
                    $skillsToUpdate += $_.Name
                }
            }
        } elseif (Test-Path (Join-Path $CentralDir "SKILL.md")) {
            $skillsToUpdate += "us-refinement"
        }
    }

    foreach ($sk in $skillsToUpdate) {
        $skSource = Join-Path $CentralDir "skills\$sk"
        if (-not (Test-Path $skSource) -and (Test-Path (Join-Path $CentralDir "SKILL.md"))) {
            $skSource = $CentralDir
        }

        Write-Host "Updating agent paths for skill '$sk'..." -ForegroundColor Gray
        $agentPaths = Get-AgentPaths $sk

        foreach ($agent in $agentPaths) {
            if (Test-Path $agent) {
                Copy-SkillFile $agent $skSource
                Write-Host "Updated agent skill path: $agent" -ForegroundColor Green
            }
        }

        $kiroTarget = Join-Path $HomeDir ".kiro\steering\$sk.md"
        if (Test-Path $kiroTarget) {
            New-KiroSteeringFile $skSource $sk
            Write-Host "Updated agent skill path: $kiroTarget" -ForegroundColor Green
        }
    }

    Write-Host "Update completed successfully to version $latestVersion!" -ForegroundColor Green
}
catch {
    Write-Error "Error during update: $_"
    exit 1
}
finally {
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
    if (Test-Path $tempExtractDir) { Remove-Item $tempExtractDir -Recurse -Force }
}

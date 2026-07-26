# us-refinement Auto-Updater for Windows
$ErrorActionPreference = "Stop"

$HomeDir = $env:USERPROFILE
$CentralDir = Join-Path $HomeDir ".hjagar\skills\us-refinement"
$LocalSkill = Join-Path $CentralDir "SKILL.md"

Write-Host "Checking for updates..." -ForegroundColor Cyan

# 1. Read local version
if (-not (Test-Path $LocalSkill)) {
    Write-Error "Error: us-refinement is not installed globally at $CentralDir. Run install.ps1 first."
    exit 1
}

$localContent = Get-Content $LocalSkill -Raw
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
    # Skip basic parsing issues
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

    # Validate the extracted archive is complete BEFORE clearing any existing central-store
    # content below - update.ps1 now depends on lib/ to even finish (it dot-sources
    # lib/skill-payload.ps1 from the central store further down), so a truncated/incomplete
    # archive must abort here instead of wiping a working install with no way back.
    foreach ($required in @("SKILL.md", "scripts", "tests", "lib")) {
        $requiredPath = Join-Path $tempExtractDir $required
        if (-not (Test-Path $requiredPath)) {
            Write-Error "Error: downloaded release archive is missing '$required' - aborting before touching the existing installation at $CentralDir."
            exit 1
        }
    }

    # Safely overwrite central files (pisin' individual files to prevent locking on script itself)
    Write-Host "Updating central files..." -ForegroundColor Gray
    foreach ($dir in @("scripts", "tests", "lib")) {
        # Clear stale central-store dirs first: a plain merge-copy below would leave behind
        # files removed/renamed in the new release, and those orphans would then be
        # re-propagated to every agent path.
        $centralSubdir = Join-Path $CentralDir $dir
        if (Test-Path $centralSubdir) { Remove-Item -Path $centralSubdir -Force -Recurse }
    }
    Get-ChildItem -Path $tempExtractDir -Force | ForEach-Object {
        $destPath = Join-Path $CentralDir $_.Name
        Copy-Item -Path $_.FullName -Destination $destPath -Force -Recurse
    }

    # Copy-SkillFile, New-KiroSteeringFile, and Get-AgentPaths live in
    # lib/skill-payload.ps1 (shared with install.ps1). It was just refreshed into
    # $CentralDir above alongside scripts/ and tests/, so dot-source the refreshed copy.
    . (Join-Path $CentralDir "lib\skill-payload.ps1")

    # 5. Propagate SKILL.md + scripts/ + tests/ to all agents
    Write-Host "Updating agents..." -ForegroundColor Gray
    $AgentPaths = Get-AgentPaths

    foreach ($agent in $AgentPaths) {
        if (Test-Path $agent) {
            Copy-SkillFile $agent $CentralDir
            Write-Host "Updated agent skill path: $agent" -ForegroundColor Green
        }
    }

    # Kiro is a special case: a single generated steering file at
    # ~/.kiro/steering/us-refinement.md (SKILL.md's frontmatter with `inclusion: always`
    # injected), not a folder+SKILL.md copy - no scripts/ or tests/ payload. Only
    # regenerate it if it already exists - update.ps1 never opts a machine into a new
    # agent, only refreshes agents already installed.
    $kiroTarget = Join-Path $HomeDir ".kiro\steering\us-refinement.md"
    if (Test-Path $kiroTarget) {
        New-KiroSteeringFile $CentralDir
        Write-Host "Updated agent skill path: $kiroTarget" -ForegroundColor Green
    }

    Write-Host "Update completed successfully to version $latestVersion!" -ForegroundColor Green
}
catch {
    Write-Error "Error during update: $_"
    exit 1
}
finally {
    # Cleanup temp resources
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
    if (Test-Path $tempExtractDir) { Remove-Item $tempExtractDir -Recurse -Force }
}

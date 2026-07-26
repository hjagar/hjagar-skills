# Target setup
$HomeDir = $env:USERPROFILE
$CentralDir = Join-Path $HomeDir ".hjagar\skills\us-refinement"
$AgentPaths = [System.Collections.Generic.List[string]]::new()
$AgentPaths.Add((Join-Path $HomeDir ".gemini\skills\us-refinement"))
$AgentPaths.Add((Join-Path $HomeDir ".claude\skills\us-refinement"))
$AgentPaths.Add((Join-Path $HomeDir ".config\opencode\skills\us-refinement"))
$AgentPaths.Add((Join-Path $HomeDir ".copilot\skills\us-refinement"))
$AgentPaths.Add((Join-Path $HomeDir ".agents\skills\us-refinement"))
$AgentPaths.Add((Join-Path $HomeDir ".cursor\skills\us-refinement"))

if (Test-Path $HomeDir) {
    Get-ChildItem -Path $HomeDir -Filter ".claude-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $AgentPaths.Add((Join-Path $_.FullName "skills\us-refinement"))
    }
}

Write-Host "Remove us-refinement? This will delete files and remove agent configurations." -ForegroundColor Cyan
$confirm = Read-Host "(y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

# Remove agent links
foreach ($agent in $AgentPaths) {
    if (Test-Path $agent) {
        Remove-Item $agent -Recurse -Force
        Write-Host "Removed: $agent" -ForegroundColor Green
    }
}

# Kiro is a special case: a single generated steering file, not a folder - remove only that
# file, never the parent ~/.kiro/steering/ directory (other unrelated Kiro skills may live there).
$kiroSteeringFile = Join-Path $HomeDir ".kiro\steering\us-refinement.md"
if (Test-Path $kiroSteeringFile) {
    Remove-Item $kiroSteeringFile -Force
    Write-Host "Removed: $kiroSteeringFile" -ForegroundColor Green
}

# Determine script execution context
$executionDir = $PSScriptRoot
$runningFromCentral = $false
if (Test-Path $CentralDir) {
    $resolvedCentral = (Resolve-Path $CentralDir).Path
    $resolvedExec = (Resolve-Path $executionDir).Path
    $runningFromCentral = $resolvedExec -eq $resolvedCentral
}

# Remove central directory
if ($runningFromCentral) {
    # Delete files in CentralDir first, except our own script
    Get-ChildItem $CentralDir -Recurse -File | Where-Object { $_.FullName -ne $PSCommandPath } | Remove-Item -Force
    Get-ChildItem $CentralDir -Recurse -Directory | Remove-Item -Recurse -Force
    Write-Host "Central files cleaned up." -ForegroundColor Green
} else {
    if (Test-Path $CentralDir) {
        Remove-Item $CentralDir -Recurse -Force
        Write-Host "Removed central directory: $CentralDir" -ForegroundColor Green
    }
}

# Clean empty parent directories
$skillsDir = Split-Path $CentralDir
if ((Test-Path $skillsDir) -and -not (Get-ChildItem $skillsDir -Force)) {
    Remove-Item $skillsDir -Force
    Write-Host "Removed empty parent: $skillsDir" -ForegroundColor Green
}
$hjagarDir = Split-Path $skillsDir
if ((Test-Path $hjagarDir) -and -not (Get-ChildItem $hjagarDir -Force)) {
    Remove-Item $hjagarDir -Force
    Write-Host "Removed empty parent: $hjagarDir" -ForegroundColor Green
}

# Self deletion
if ($runningFromCentral -and $PSCommandPath -and (Test-Path $PSCommandPath)) {
    Remove-Item $PSCommandPath -Force
} else {
    Write-Host "Running from clone - remove us-refinement-uninstall.ps1 manually if needed." -ForegroundColor Gray
}

Write-Host "Uninstallation completed successfully." -ForegroundColor Cyan

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('patch','minor','major')]
    [string]$ReleaseType,

    [Parameter(Mandatory=$false)]
    [string]$Skill
)

$ErrorActionPreference = "Stop"

Write-Host "=== Release-Repo ===" -ForegroundColor Cyan

$repoRoot = git rev-parse --show-toplevel
if ($repoRoot) { $repoRoot = $repoRoot.Trim() }
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Skill)) {
    Write-Host "Available skills:" -ForegroundColor Yellow
    $skills = Get-ChildItem -Path (Join-Path $repoRoot "skills") -Directory
    foreach ($s in $skills) {
        Write-Host "  - $($s.Name)" -ForegroundColor Yellow
    }
    $Skill = Read-Host "Skill to release"
}

$skillDir = Join-Path $repoRoot "skills/$Skill"
$skillMd = Join-Path $skillDir "SKILL.md"

if (-not (Test-Path $skillDir)) {
    Write-Host "Error: Skill directory not found at $skillDir" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $skillMd)) {
    Write-Host "Error: SKILL.md not found at $skillMd" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ReleaseType)) {
    $ReleaseType = Read-Host "Release type (patch/minor/major)"
}
if ($ReleaseType -notin @('patch','minor','major')) {
    Write-Host "Error: Release type must be patch, minor, or major." -ForegroundColor Red
    exit 1
}

# [1/5] Quality gate
Write-Host "[1/5] Quality gate for skill: $Skill..." -ForegroundColor Cyan

# Safety pre-flight checks
$currentBranch = git branch --show-current
if ($currentBranch) { $currentBranch = $currentBranch.Trim() }
if ($currentBranch -ne "main") {
    Write-Host "Error: Releases must be created from the main branch. Current branch is: $currentBranch" -ForegroundColor Red
    exit 1
}
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "Error: Working tree is dirty. Commit or stash changes before releasing." -ForegroundColor Red
    exit 1
}

# Prerequisites checks
if (-not (Get-Command shellcheck -ErrorAction SilentlyContinue)) {
    Write-Host "shellcheck not found. Install: winget install koalaman.shellcheck" -ForegroundColor Red
    exit 1
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "python not found. Please install Python 3." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "gh CLI not found. Please install GitHub CLI." -ForegroundColor Red
    exit 1
}

# Shellcheck loop
$shFiles = @(Get-ChildItem -Path $repoRoot -Filter *.sh -File) +
           @(Get-ChildItem -Path (Join-Path $repoRoot "cli/lib") -Filter *.sh -File -ErrorAction SilentlyContinue) +
           @(Get-ChildItem -Path (Join-Path $skillDir "scripts") -Filter *.sh -File -ErrorAction SilentlyContinue) +
           @(Get-ChildItem -Path (Join-Path $skillDir "tests") -Filter *.sh -File -ErrorAction SilentlyContinue)

foreach ($file in $shFiles) {
    if (Test-Path $file.FullName) {
        Write-Host "  checking $($file.Name)..." -ForegroundColor Gray
        shellcheck -x $file.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "shellcheck failed on $($file.Name). Aborting." -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host "  All shell scripts passed shellcheck." -ForegroundColor Green

# Shared quality gate invocation for single skill
. (Join-Path $repoRoot "cli/lib/quality-gate.ps1")
$gateResult = Invoke-QualityGate -RepoRoot $repoRoot -TargetSkill $Skill
if (-not $gateResult) {
    Write-Host "Quality gate failed for $Skill. Aborting." -ForegroundColor Red
    exit 1
}
Write-Host "  All quality gate checks passed." -ForegroundColor Green

# [2/5] Version bump
Write-Host "[2/5] Version bump..." -ForegroundColor Cyan

$content = Get-Content $skillMd -Raw
$fmMatch = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---')
$currentVer = "1.0.0"
if ($fmMatch.Success) {
    $verMatch = [regex]::Match($fmMatch.Groups[1].Value, 'version:\s*"?(?:v)?([0-9\.]+)"?')
    if ($verMatch.Success) {
        $currentVer = $verMatch.Groups[1].Value
    }
}

$parts = $currentVer.Split('.')
$major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
switch ($ReleaseType) {
    'major' { $major++; $minor = 0; $patch = 0 }
    'minor' { $minor++; $patch = 0 }
    'patch' { $patch++ }
}
$nextVersion = "v$major.$minor.$patch"
$tagName = "$Skill-$nextVersion"

Write-Host "  $Skill: v$currentVer -> $nextVersion ($ReleaseType)" -ForegroundColor Green

$confirm = Read-Host "Create release $tagName? (y/N)"
if ($confirm -notin @('y','Y')) {
    Write-Host "Cancelled. Nothing was created." -ForegroundColor Gray
    exit 0
}

# [3/5] Package
Write-Host "[3/5] Packaging..." -ForegroundColor Cyan

$plainVersion = $nextVersion.TrimStart('v')
$frontmatter = $fmMatch.Groups[1].Value
if ($frontmatter -match '(?m)^(\s*version:\s*)"?v?[\d\.]+"?(\s*)$') {
    $newFrontmatter = [regex]::Replace($frontmatter, '(?m)^(\s*version:\s*)"?v?[\d\.]+"?(\s*)$', { param($m) $m.Groups[1].Value + '"' + $plainVersion + '"' + $m.Groups[2].Value })
} else {
    $newFrontmatter = $frontmatter + "`r`nmetadata:`r`n  version: `"$plainVersion`""
}
$content = $content.Substring(0, $fmMatch.Groups[1].Index) + $newFrontmatter + $content.Substring($fmMatch.Groups[1].Index + $fmMatch.Groups[1].Length)
$content = $content -replace '\r?\n<!-- version: v[\d\.]+ -->\r?\n', "`r`n"
Set-Content -Path $skillMd -Value $content -NoNewline

Write-Host "  Creating version bump commit..." -ForegroundColor Gray
git add $skillMd
git commit -m "chore(release): bump $Skill version to $nextVersion" | Out-Null

$buildDir = Join-Path $repoRoot 'build'
$zipPath  = Join-Path $buildDir "$Skill.zip"
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Path $buildDir | Out-Null

$skillItems = Get-ChildItem -Path $skillDir
Compress-Archive -Path $skillItems.FullName -DestinationPath $zipPath -Force
Write-Host "  Created build/$Skill.zip" -ForegroundColor Green

# [4/5] Tag + push
Write-Host "[4/5] Tag + push..." -ForegroundColor Cyan
git tag -a $tagName -m "Release $Skill $nextVersion"
if ($LASTEXITCODE -ne 0) { Write-Host "git tag failed." -ForegroundColor Red; exit 1 }
git push origin main --follow-tags
if ($LASTEXITCODE -ne 0) { Write-Host "git push failed." -ForegroundColor Red; exit 1 }
Write-Host "  Tagged and pushed $tagName." -ForegroundColor Green

# [5/5] Publish + cleanup
Write-Host "[5/5] Publishing GitHub release..." -ForegroundColor Cyan
gh release create $tagName $zipPath --title "$Skill $nextVersion" --generate-notes
if ($LASTEXITCODE -ne 0) {
    Write-Host "gh release create failed (check 'gh auth status'). Tag $tagName is already pushed - re-run after auth to reuse it." -ForegroundColor Red
    exit 1
}
Remove-Item $buildDir -Recurse -Force
Write-Host "`nDone. Release $tagName published." -ForegroundColor Green

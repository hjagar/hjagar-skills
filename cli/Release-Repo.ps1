param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('patch','minor','major')]
    [string]$ReleaseType
)

$ErrorActionPreference = "Stop"

Write-Host "=== Release-Repo ===" -ForegroundColor Cyan

$repoRoot = git rev-parse --show-toplevel
if ($repoRoot) { $repoRoot = $repoRoot.Trim() }
Set-Location $repoRoot

# [1/5] Quality gate
Write-Host "[1/5] Quality gate..." -ForegroundColor Cyan

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

# Shellcheck loop (repo-root scripts + lib/, which now ships shared shell logic)
$shFiles = @(Get-ChildItem -Path $repoRoot -Filter *.sh -File) + @(Get-ChildItem -Path (Join-Path $repoRoot "lib") -Filter *.sh -File -ErrorAction SilentlyContinue)
foreach ($file in $shFiles) {
    Write-Host "  checking $($file.Name)..." -ForegroundColor Gray
    shellcheck -x $file.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "shellcheck failed on $($file.Name). Aborting." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  All shell scripts passed shellcheck." -ForegroundColor Green

# Python validation tests
Write-Host "  Running Python validation on mock_valid_us.md (expecting success)..." -ForegroundColor Gray
python scripts/validate_refinement.py tests/mock_valid_us.md
if ($LASTEXITCODE -ne 0) {
    Write-Host "Validation failed on mock_valid_us.md. Aborting." -ForegroundColor Red
    exit 1
}
Write-Host "  Running Python validation on mock_invalid_us.md (expecting failure)..." -ForegroundColor Gray
python scripts/validate_refinement.py tests/mock_invalid_us.md 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Validation unexpectedly succeeded on mock_invalid_us.md. Aborting." -ForegroundColor Red
    exit 1
}
Write-Host "  All quality gate checks passed." -ForegroundColor Green

# [2/5] Version bump
Write-Host "[2/5] Version bump..." -ForegroundColor Cyan
$lastTag = $null
try {
    $lastTag = git describe --tags --abbrev=0 2>$null
    if ($lastTag) { $lastTag = $lastTag.Trim() }
} catch {
    $lastTag = $null
}
if ([string]::IsNullOrWhiteSpace($lastTag)) {
    $nextVersion = "v1.0.0"
    Write-Host "  No existing tags. Proposing first release $nextVersion." -ForegroundColor Yellow
} else {
    $parts = $lastTag.TrimStart('v').Split('.')
    $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
    switch ($ReleaseType) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
    }
    $nextVersion = "v$major.$minor.$patch"
    Write-Host "  $lastTag -> $nextVersion ($ReleaseType)" -ForegroundColor Green
}

$confirm = Read-Host "Create release $nextVersion? (y/N)"
if ($confirm -notin @('y','Y')) {
    Write-Host "Cancelled. Nothing was created." -ForegroundColor Gray
    exit 0
}

# [3/5] Package
Write-Host "[3/5] Packaging..." -ForegroundColor Cyan

# Bump metadata.version in the SKILL.md frontmatter, scoped to the
# frontmatter block only (migrates the legacy <!-- version: vX.Y.Z -->
# comment format the first time it encounters it)
$workspaceSkill = Join-Path $repoRoot "SKILL.md"
$content = Get-Content $workspaceSkill -Raw
$fm = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---')
if (-not $fm.Success) {
    Write-Error "SKILL.md is missing a valid YAML frontmatter block."
    exit 1
}
$frontmatter = $fm.Groups[1].Value
$plainVersion = $nextVersion.TrimStart('v')
if ($frontmatter -match '(?m)^(\s*version:\s*)"?v?[\d\.]+"?(\s*)$') {
    $newFrontmatter = [regex]::Replace($frontmatter, '(?m)^(\s*version:\s*)"?v?[\d\.]+"?(\s*)$', { param($m) $m.Groups[1].Value + '"' + $plainVersion + '"' + $m.Groups[2].Value })
} else {
    $newFrontmatter = $frontmatter + "`r`nmetadata:`r`n  version: `"$plainVersion`""
}
$content = $content.Substring(0, $fm.Groups[1].Index) + $newFrontmatter + $content.Substring($fm.Groups[1].Index + $fm.Groups[1].Length)
$content = $content -replace '\r?\n<!-- version: v[\d\.]+ -->\r?\n', "`r`n"
Set-Content -Path $workspaceSkill -Value $content -NoNewline

# Commit version bump to workspace git history
Write-Host "  Creating version bump commit..." -ForegroundColor Gray
git add SKILL.md
git commit -m "chore(release): bump version to $nextVersion" | Out-Null

$buildDir = Join-Path $repoRoot 'build'
$zipPath  = Join-Path $buildDir 'us-refinement.zip'
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Path $buildDir | Out-Null

# Copy source files to build directory
Copy-Item -Path $workspaceSkill -Destination $buildDir
Copy-Item -Path (Join-Path $repoRoot "us-refinement-uninstall.ps1") -Destination $buildDir
Copy-Item -Path (Join-Path $repoRoot "us-refinement-uninstall.sh") -Destination $buildDir
Copy-Item -Path (Join-Path $repoRoot "update.ps1") -Destination $buildDir
Copy-Item -Path (Join-Path $repoRoot "update.sh") -Destination $buildDir
Copy-Item -Path (Join-Path $repoRoot "scripts") -Destination $buildDir -Recurse
Copy-Item -Path (Join-Path $repoRoot "tests") -Destination $buildDir -Recurse
Copy-Item -Path (Join-Path $repoRoot "lib") -Destination $buildDir -Recurse

$items = @(
    (Join-Path $buildDir "SKILL.md"),
    (Join-Path $buildDir "us-refinement-uninstall.ps1"),
    (Join-Path $buildDir "us-refinement-uninstall.sh"),
    (Join-Path $buildDir "update.ps1"),
    (Join-Path $buildDir "update.sh"),
    (Join-Path $buildDir "scripts"),
    (Join-Path $buildDir "tests"),
    (Join-Path $buildDir "lib")
)
Compress-Archive -Path $items -DestinationPath $zipPath -Force
Write-Host "  Created build/us-refinement.zip" -ForegroundColor Green

# [4/5] Tag + push
Write-Host "[4/5] Tag + push..." -ForegroundColor Cyan
git tag -a $nextVersion -m "Release $nextVersion"
if ($LASTEXITCODE -ne 0) { Write-Host "git tag failed." -ForegroundColor Red; exit 1 }
git push origin main --follow-tags
if ($LASTEXITCODE -ne 0) { Write-Host "git push failed." -ForegroundColor Red; exit 1 }
Write-Host "  Tagged and pushed $nextVersion." -ForegroundColor Green

# [5/5] Publish + cleanup
Write-Host "[5/5] Publishing GitHub release..." -ForegroundColor Cyan
gh release create $nextVersion $zipPath --generate-notes
if ($LASTEXITCODE -ne 0) {
    Write-Host "gh release create failed (check 'gh auth status'). Tag $nextVersion is already pushed - re-run after auth to reuse it." -ForegroundColor Red
    exit 1
}
Remove-Item $buildDir -Recurse -Force
Write-Host "`nDone. Release $nextVersion published." -ForegroundColor Green

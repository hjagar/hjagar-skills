param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('patch','minor','major')]
    [string]$ReleaseType,

    [Parameter(Mandatory=$false)]
    [string]$Skill
)

$ErrorActionPreference = "Stop"

# Monorepo publish target (US-17 D6). Release-Repo keeps publishing to
# `origin` using the existing <skill>-v* tag scheme (no --repo flag is added
# to `gh release create` - D2). This constant is only used to verify that
# `gh` actually resolved that same repo before any tag or push happens.
$REPO = "hjagar/hjagar-skills"

# ---------------------------------------------------------------------------
# Pure / testable helper functions
# ---------------------------------------------------------------------------

# Writes raw text to stderr with no PowerShell error-record decoration, so
# the preflight guard's message is capturable via plain `2>&1` redirection
# (matching bash's `echo "..." >&2` convention and cli/tests/test-parity.sh's
# existing Write-NoReleaseError pattern in install.ps1/update.ps1).
function Write-Stderr {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

# Pure (US-17 D6 preflight guard): compares the repo `gh` actually resolved
# against the expected monorepo publish target. Returns $true on an exact
# match. On mismatch, or when $Actual is empty (gh failed to resolve
# anything), writes an error to stderr and returns $false - callers MUST
# abort (create no tag, push nothing) on $false. Never touches the network
# itself - safe to unit test with canned strings.
function Test-PublishTarget {
    param(
        [string]$Expected,
        [string]$Actual
    )
    if ([string]::IsNullOrEmpty($Actual)) {
        Write-Stderr "Error: could not resolve the publish target repo via 'gh repo view'. Ensure gh is authenticated and a GitHub remote is configured. Aborting before any tag or push - nothing was created."
        return $false
    }
    if ($Actual -ne $Expected) {
        Write-Stderr "Error: publish target mismatch. 'gh repo view' resolved '$Actual', expected '$Expected'. Aborting before any tag or push - nothing was created. Check for an extra remote (e.g. an 'upstream' remote) confusing gh's default repo resolution."
        return $false
    }
    return $true
}

# Network (US-17 D6): resolves the base repo `gh` would target for release
# operations in the current directory. Returns "owner/name" on success, an
# empty string on failure (gh not authenticated, no remote configured,
# ambiguous resolution, etc.) - callers must treat empty output as failure
# via Test-PublishTarget, never as a legitimate empty target.
function Resolve-PublishTargetRepo {
    $result = gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($result)) {
        return ""
    }
    return ($result | Out-String).Trim()
}

# Stages a skill's release payload into a scratch staging directory as:
#   skills/<name>/**              (the skill's own contents, nested - not flat)
#   cli/lib/skill-payload.sh
#   cli/lib/skill-payload.ps1
#   cli/agent-targets.json        (US-24 - manifest read by skill-payload.{sh,ps1})
# Pure filesystem staging - no zip/Compress-Archive step here, safe to unit
# test in isolation. Mirrors the monorepo's own layout (US-17 D4) so
# `install_skills`'s `skills/<name>` resolution branch succeeds after
# extraction - replaces the old flat archive built directly from $skillDir,
# which omitted cli/lib entirely.
function New-ReleaseStagingPayload {
    param(
        [string]$RepoRoot,
        [string]$SkillName,
        [string]$SkillDir,
        [string]$StagingDir
    )
    if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $StagingDir "skills") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $StagingDir "cli\lib") -Force | Out-Null

    Copy-Item -Path $SkillDir -Destination (Join-Path $StagingDir "skills\$SkillName") -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot "cli\lib\skill-payload.sh") -Destination (Join-Path $StagingDir "cli\lib\skill-payload.sh") -Force
    Copy-Item -Path (Join-Path $RepoRoot "cli\lib\skill-payload.ps1") -Destination (Join-Path $StagingDir "cli\lib\skill-payload.ps1") -Force
    Copy-Item -Path (Join-Path $RepoRoot "cli\agent-targets.json") -Destination (Join-Path $StagingDir "cli\agent-targets.json") -Force
}

# Compresses an already-staged release payload (see New-ReleaseStagingPayload)
# into $ZipPath, with `skills/` and `cli/` as the archive's top-level
# entries - kept as a separate step so staging logic stays independently
# testable.
function Compress-ReleasePayload {
    param(
        [string]$StagingDir,
        [string]$ZipPath
    )
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    $zipDir = Split-Path -Parent $ZipPath
    if ($zipDir -and -not (Test-Path $zipDir)) { New-Item -ItemType Directory -Path $zipDir -Force | Out-Null }
    $items = @((Join-Path $StagingDir "skills"), (Join-Path $StagingDir "cli"))
    Compress-Archive -Path $items -DestinationPath $ZipPath -Force
}

# ---------------------------------------------------------------------------
# Entry point (guarded - see bottom of file)
# ---------------------------------------------------------------------------

function Main {
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

    # [1/6] Quality gate
    Write-Host "[1/6] Quality gate for skill: $Skill..." -ForegroundColor Cyan

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

    # [2/6] Version bump
    Write-Host "[2/6] Version bump..." -ForegroundColor Cyan

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

    Write-Host "  ${Skill}: v$currentVer -> $nextVersion ($ReleaseType)" -ForegroundColor Green

    $confirm = Read-Host "Create release $tagName? (y/N)"
    if ($confirm -notin @('y','Y')) {
        Write-Host "Cancelled. Nothing was created." -ForegroundColor Gray
        exit 0
    }

    # [3/6] Package
    Write-Host "[3/6] Packaging..." -ForegroundColor Cyan

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
    $stagingDir = Join-Path $buildDir '.staging'
    $zipPath  = Join-Path $buildDir "$Skill.zip"
    if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
    New-Item -ItemType Directory -Path $buildDir | Out-Null

    New-ReleaseStagingPayload -RepoRoot $repoRoot -SkillName $Skill -SkillDir $skillDir -StagingDir $stagingDir
    Compress-ReleasePayload -StagingDir $stagingDir -ZipPath $zipPath
    Remove-Item $stagingDir -Recurse -Force
    Write-Host "  Created build/$Skill.zip" -ForegroundColor Green

    # [4/6] Verify publish target
    Write-Host "[4/6] Verifying publish target..." -ForegroundColor Cyan
    $actualRepo = Resolve-PublishTargetRepo
    if (-not (Test-PublishTarget -Expected $REPO -Actual $actualRepo)) {
        exit 1
    }
    Write-Host "  Publish target confirmed: $REPO" -ForegroundColor Green

    # [5/6] Tag + push
    Write-Host "[5/6] Tag + push..." -ForegroundColor Cyan
    git tag -a $tagName -m "Release $Skill $nextVersion"
    if ($LASTEXITCODE -ne 0) { Write-Host "git tag failed." -ForegroundColor Red; exit 1 }
    git push origin main --follow-tags
    if ($LASTEXITCODE -ne 0) { Write-Host "git push failed." -ForegroundColor Red; exit 1 }
    Write-Host "  Tagged and pushed $tagName." -ForegroundColor Green

    # [6/6] Publish + cleanup
    Write-Host "[6/6] Publishing GitHub release..." -ForegroundColor Cyan
    gh release create $tagName $zipPath --title "$Skill $nextVersion" --generate-notes
    if ($LASTEXITCODE -ne 0) {
        Write-Host "gh release create failed (check 'gh auth status'). Tag $tagName is already pushed - re-run after auth to reuse it." -ForegroundColor Red
        exit 1
    }
    Remove-Item $buildDir -Recurse -Force
    Write-Host "`nDone. Release $tagName published." -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}

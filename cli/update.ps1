# hjagar-skills Auto-Updater for Windows
[CmdletBinding()]
param(
    [string]$Skill
)

$ErrorActionPreference = "Stop"

# Monorepo release source (US-17). All releases for every skill are published as
# `<skill>-v*` tags against this single repo - never a per-skill mirror.
$REPO = "hjagar/hjagar-skills"
$HomeDir = $env:USERPROFILE
$CentralDir = Join-Path $HomeDir ".hjagar\skills"

# ---------------------------------------------------------------------------
# Pure / testable helper functions (identical contract to install.ps1)
# ---------------------------------------------------------------------------

function Write-Stderr {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

function Test-SkillName {
    param([string]$RawName)
    if ($RawName -match '^[a-z0-9][a-z0-9-]*$') {
        return $true
    }
    Write-Stderr "Error: invalid skill name '$RawName'."
    return $false
}

function Select-HighestTag {
    param(
        [string]$SkillName,
        [string[]]$Tags
    )
    $prefix = "$SkillName-v"
    $escapedPrefix = [regex]::Escape($prefix)
    $matched = @($Tags | Where-Object { $_ -match "^$escapedPrefix\d" })
    if ($matched.Count -eq 0) {
        return $null
    }
    $best = $matched | ForEach-Object {
        [PSCustomObject]@{
            Tag     = $_
            Version = [version]($_.Substring($prefix.Length))
        }
    } | Sort-Object Version | Select-Object -Last 1
    return $best.Tag
}

function Invoke-GhApi {
    # Thin wrapper around the external `gh` process — kept as its own function
    # (rather than calling `& gh ...` inline) so it is a real PowerShell
    # function Pester can reliably Mock. Mocking the bare `gh` Application
    # directly is not reliable across hosts/PATH states.
    param([string]$Repo)
    & gh api --paginate "repos/$Repo/releases" --jq '.[].tag_name' 2>$null
}

function Get-ReleaseTags {
    param([string]$Repo)

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            # Force array context AT THE ASSIGNMENT — otherwise a genuinely
            # empty/zero-line result collapses to $null (PowerShell unwraps a
            # zero-object pipeline into $null, not an empty array), which
            # would be indistinguishable from a real gh failure below.
            $ghOutput = @(Invoke-GhApi -Repo $Repo)
            if ($LASTEXITCODE -eq 0) {
                # Lines are normally already-split array elements (external
                # process output auto-splits), but defensively re-split every
                # element on newlines too, in case a single multi-line string
                # comes back instead.
                #
                # The leading `,` (unary comma operator) is REQUIRED: without
                # it, a genuinely empty result unrolls to zero pipeline
                # objects and the CALLER's `$tags = Get-ReleaseTags ...`
                # collapses to $null — indistinguishable from a real failure.
                # `,@(...)` forces the (possibly empty) array to cross the
                # function-return boundary as one array object.
                return ,@($ghOutput | ForEach-Object { $_ -split "`r?`n" } | Where-Object { $_ })
            }
        } catch {
            # fall through to REST fallback
        }
    }

    try {
        $releases = @(Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -UseBasicParsing)
        return ,@($releases | Where-Object { $_ } | ForEach-Object { $_.tag_name })
    } catch {
        return $null
    }
}

function Resolve-ReleaseTag {
    param([string]$Repo, [string]$SkillName)
    $tags = Get-ReleaseTags -Repo $Repo
    if ($null -eq $tags) {
        throw "release-list-failed"
    }
    return Select-HighestTag -SkillName $SkillName -Tags $tags
}

# Filesystem-only (US-17 D8): lists the skill names already installed under
# $CentralDir\skills\*. Never touches the network - safe to unit test against
# a scratch $CentralDir. This is what an omitted -Skill updates (every
# LOCALLY installed skill, each via its own resolved tag) - never a
# hardcoded default skill.
function Get-LocallyInstalledSkillNames {
    param([string]$CentralDir)

    $names = @()
    $skillsDir = Join-Path $CentralDir "skills"
    if (Test-Path $skillsDir) {
        Get-ChildItem -Path $skillsDir -Directory | ForEach-Object {
            if (Test-Path (Join-Path $_.FullName "SKILL.md")) {
                $names += $_.Name
            }
        }
    } elseif (Test-Path (Join-Path $CentralDir "SKILL.md")) {
        # Legacy flat central install (no skills\<name>\ subfolder) - same
        # limitation as pre-US-17 update.ps1: the actual skill name isn't
        # recoverable from a flat layout, so this falls back to the central
        # dir's own basename.
        $names += (Split-Path -Leaf $CentralDir)
    }
    return ,@($names)
}

function Write-NoReleaseError {
    param([string]$SkillName, [string]$Repo)
    Write-Stderr "Error: no released version found for skill '$SkillName' in $Repo."
    Write-Stderr "Install from a local checkout instead: install.sh -l -p <path>  /  install.ps1 -Local -Path <path>"
}

function Invoke-GhReleaseDownload {
    # Thin wrapper around the external `gh` process — see Invoke-GhApi for why
    # this seam exists (reliable Pester mocking).
    param([string]$Tag, [string]$Repo, [string]$SkillName, [string]$OutZip)
    & gh release download $Tag --repo $Repo --pattern "$SkillName.zip" --output $OutZip --clobber 2>$null
}

function Get-ReleaseZip {
    param([string]$Repo, [string]$Tag, [string]$SkillName, [string]$OutZip)

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            Invoke-GhReleaseDownload -Tag $Tag -Repo $Repo -SkillName $SkillName -OutZip $OutZip
            if ($LASTEXITCODE -eq 0 -and (Test-Path $OutZip)) {
                return $true
            }
        } catch {
            # fall through to HTTP fallback
        }
    }

    $url = "https://github.com/$Repo/releases/download/$Tag/$SkillName.zip"
    try {
        Invoke-WebRequest -Uri $url -OutFile $OutZip -UseBasicParsing
        return $true
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Local-version detection (unchanged logic, extracted into a function so it
# can run as an approval test without triggering any network/copy side
# effects).
# ---------------------------------------------------------------------------

function Get-LocalVersion {
    param([string]$SkillName)

    $checkSkillFile = $null
    $targetFile = Join-Path $CentralDir "skills\$SkillName\SKILL.md"
    if (Test-Path $targetFile) {
        $checkSkillFile = $targetFile
    } elseif (Test-Path (Join-Path $CentralDir "SKILL.md")) {
        $checkSkillFile = Join-Path $CentralDir "SKILL.md"
    }

    if (-not $checkSkillFile -or -not (Test-Path $checkSkillFile)) {
        return $null
    }

    $localContent = Get-Content $checkSkillFile -Raw
    $localVersion = "v0.0.0"
    $fm = [regex]::Match($localContent, '(?s)\A---\r?\n(.*?)\r?\n---')
    if ($fm.Success -and $fm.Groups[1].Value -match '(?m)^\s*version:\s*(v[\d\.]+)\s*$') {
        $localVersion = $Matches[1]
    } elseif ($localContent -match '<!-- version: (v[\d\.]+) -->') {
        $localVersion = $Matches[1]
    }
    return $localVersion
}

# ---------------------------------------------------------------------------
# Update-OneSkill - resolves, compares, downloads, and propagates the update
# for ONE skill. Used both for `-Skill <name>` (single invocation) and the
# discover-locally-installed loop (US-17 D8, one invocation per
# already-installed skill, since each has its own independently-tagged
# release). Exits 1 on any resolution/download/extraction failure; returns
# (without downloading) when already on the latest version.
# ---------------------------------------------------------------------------

function Update-OneSkill {
    param([string]$SkillName)

    # 1. Locate reference SKILL.md to check local version
    $localVersion = Get-LocalVersion -SkillName $SkillName
    if (-not $localVersion) {
        Write-Error "Error: skills are not installed globally at $CentralDir. Run install.ps1 first."
        exit 1
    }
    Write-Host "Local version: $localVersion" -ForegroundColor Gray

    # 2. Resolve latest matching `<skill>-v*` tag from the monorepo
    Write-Host "Resolving release for skill '$SkillName' in $REPO..." -ForegroundColor Gray
    try {
        $tag = Resolve-ReleaseTag -Repo $REPO -SkillName $SkillName
    } catch {
        Write-Warning "Failed to query GitHub API. Check connection."
        exit 1
    }
    if (-not $tag) {
        Write-NoReleaseError -SkillName $SkillName -Repo $REPO
        exit 1
    }

    $latestVersion = $tag.Substring("$SkillName-".Length)
    Write-Host "Latest remote version: $latestVersion" -ForegroundColor Gray

    # 3. Compare versions
    if ($localVersion -eq $latestVersion) {
        Write-Host "You are already on the latest version: $localVersion" -ForegroundColor Green
        return
    }

    Write-Host "New version $latestVersion is available! Updating..." -ForegroundColor Cyan

    # 4. Perform download and safe update
    $tempZip = Join-Path $env:TEMP "$SkillName-update-$latestVersion.zip"
    $tempExtractDir = Join-Path $env:TEMP "$SkillName-update-extract"

    try {
        Write-Host "Downloading release archive..." -ForegroundColor Gray
        if (-not (Get-ReleaseZip -Repo $REPO -Tag $tag -SkillName $SkillName -OutZip $tempZip)) {
            Write-Error "Error: Failed to download release ZIP from GitHub."
            exit 1
        }

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

        # 5. Propagate to agents
        $skSource = Join-Path $CentralDir "skills\$SkillName"
        if (-not (Test-Path $skSource) -and (Test-Path (Join-Path $CentralDir "SKILL.md"))) {
            $skSource = $CentralDir
        }

        Write-Host "Updating agent paths for skill '$SkillName'..." -ForegroundColor Gray
        $agentPaths = Get-AgentPaths $SkillName

        foreach ($agent in $agentPaths) {
            if (Test-Path $agent) {
                Copy-SkillFile $agent $skSource
                Write-Host "Updated agent skill path: $agent" -ForegroundColor Green
            }
        }

        $kiroTarget = Join-Path $HomeDir ".kiro\steering\$SkillName.md"
        if (Test-Path $kiroTarget) {
            New-KiroSteeringFile $skSource $SkillName
            Write-Host "Updated agent skill path: $kiroTarget" -ForegroundColor Green
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
}

# ---------------------------------------------------------------------------
# Main - guarded so this file can be dot-sourced (for unit tests) without
# running any update side effects.
# ---------------------------------------------------------------------------

function Main {
    # Skill-name validation - BEFORE any interpolation into a URL, jq filter,
    # regex, or filesystem path.
    if ($Skill) {
        if (-not (Test-SkillName $Skill)) {
            exit 1
        }
    }

    Write-Host "Checking for updates..." -ForegroundColor Cyan

    if ($Skill) {
        Update-OneSkill -SkillName $Skill
    } else {
        # US-17 D8: no -Skill given -> update EVERY skill already found
        # locally under $CentralDir\skills\*, each via its own resolved tag.
        # Never defaults to a single hardcoded skill (D5 superseded).
        $skillsToUpdate = Get-LocallyInstalledSkillNames -CentralDir $CentralDir

        if ($skillsToUpdate.Count -eq 0) {
            Write-Error "Error: skills are not installed globally at $CentralDir. Run install.ps1 first."
            exit 1
        }

        foreach ($sk in $skillsToUpdate) {
            Update-OneSkill -SkillName $sk
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}

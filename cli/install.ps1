[CmdletBinding()]
param(
    [switch]$Local,
    [string]$Path,
    [string]$Skill
)

$ErrorActionPreference = "Stop"

# Monorepo release source (US-17). All releases for every skill are published as
# `<skill>-v*` tags against this single repo - never a per-skill mirror.
$REPO = "hjagar/hjagar-skills"

# ---------------------------------------------------------------------------
# Pure / testable helper functions
# ---------------------------------------------------------------------------

# Writes raw text to stderr with no PowerShell error-record decoration, so the
# emitted bytes match bash's `echo "..." >&2` exactly (required for install.sh
# / install.ps1 parity on the US-17 unhappy-path messages).
function Write-Stderr {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

# Validates a skill name BEFORE it is interpolated into any URL, jq filter,
# regex, or filesystem path. Writes an error to stderr and returns $false when
# the name doesn't match ^[a-z0-9][a-z0-9-]*$.
function Test-SkillName {
    param([string]$RawName)
    if ($RawName -match '^[a-z0-9][a-z0-9-]*$') {
        return $true
    }
    Write-Stderr "Error: invalid skill name '$RawName'."
    return $false
}

# Pure: given a skill name and a list of tag names, returns the highest
# matching `<skill>-v*` tag via [version] ordering (v1.10.0 > v1.9.0), or
# $null if no tag matches. Never touches the network - safe to unit test.
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

# Network: lists release tag_names for $Repo via `gh` (preferred) or
# Invoke-RestMethod (unauthenticated fallback). Returns $null only when
# release listing failed entirely (infrastructure failure) - an empty-but-
# successful list returns an empty array, which is NOT the same as $null.
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

# Resolves the exact release tag for $SkillName against $Repo. Returns the tag
# string (or $null, if the list was fetched successfully but nothing matched)
# on success, OR throws when tags could not be listed at all.
function Resolve-ReleaseTag {
    param([string]$Repo, [string]$SkillName)
    $tags = Get-ReleaseTags -Repo $Repo
    if ($null -eq $tags) {
        throw "release-list-failed"
    }
    return Select-HighestTag -SkillName $SkillName -Tags $tags
}

# Pure (US-17 D8): given a list of tag names, returns the distinct skill
# names by matching the exact `<skill>-vMAJOR.MINOR.PATCH` shape and
# stripping the trailing version suffix. Deduped and sorted for a
# deterministic install order. Never touches the network - safe to unit test.
function Get-SkillNamesFromTags {
    param([string[]]$Tags)
    $names = @($Tags | Where-Object { $_ -match '^[a-z0-9][a-z0-9-]*-v[0-9]+\.[0-9]+\.[0-9]+$' } | ForEach-Object {
        $_ -replace '-v[0-9]+\.[0-9]+\.[0-9]+$', ''
    })
    # See Get-ReleaseTags above for why the unary comma is required: without
    # it, a genuinely empty result unrolls to zero pipeline objects and the
    # caller's assignment collapses to $null instead of a real empty array.
    return ,@($names | Sort-Object -Unique)
}

# Identical error text is required across install.sh/install.ps1/update.sh/update.ps1.
function Write-NoReleaseError {
    param([string]$SkillName, [string]$Repo)
    Write-Stderr "Error: no released version found for skill '$SkillName' in $Repo."
    Write-Stderr "Install from a local checkout instead: install.sh -l -p <path>  /  install.ps1 -Local -Path <path>"
}

# Downloads the exact tag's `<skill>.zip` via `gh release download` (preferred)
# or a tag-scoped Invoke-WebRequest URL (unauthenticated fallback - no
# server-side tag glob exists, the tag must already be resolved to an exact
# value).
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
# Install-OneSkillGlobal - resolves, downloads, extracts, and installs ONE
# skill's release into $CentralDir. Used both for `-Skill <name>` (single
# invocation) and the discover-all loop (US-17 D8, one invocation per
# discovered name, since each skill has its own independently-tagged
# release). Exits 1 on any resolution/download/extraction failure.
# ---------------------------------------------------------------------------

function Install-OneSkillGlobal {
    param([string]$SkillName, [string]$CentralDir)

    if (Test-Path $CentralDir) {
        Remove-Item -Path $CentralDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $CentralDir -Force | Out-Null

    Write-Host "Resolving release for skill '$SkillName' in $REPO..."
    try {
        $tag = Resolve-ReleaseTag -Repo $REPO -SkillName $SkillName
    } catch {
        Write-Stderr "Error: Failed to query releases for $REPO. Ensure gh CLI is authenticated or curl/wget is installed and has internet access."
        Remove-Item -Path $CentralDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
    if (-not $tag) {
        Write-NoReleaseError -SkillName $SkillName -Repo $REPO
        Remove-Item -Path $CentralDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Host "Resolved release: $tag"

    $tempZip = Join-Path $env:TEMP ("$SkillName-" + [System.Guid]::NewGuid().ToString() + ".zip")

    Write-Host "Downloading release ZIP..."
    if (-not (Get-ReleaseZip -Repo $REPO -Tag $tag -SkillName $SkillName -OutZip $tempZip)) {
        Write-Stderr "Error: Failed to download release ZIP. Ensure gh CLI is authenticated or curl/wget is installed and has internet access."
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
        Remove-Item -Path $CentralDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
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

    $script:Skill = $SkillName
    Install-Skills $CentralDir $CentralDir
}

# ---------------------------------------------------------------------------
# Install-Skills - shared by LOCAL and GLOBAL mode
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Main - guarded so this file can be dot-sourced (for unit tests) without
# running any installation side effects; only executes when run directly
# (`.\install.ps1` / `pwsh -File install.ps1`), matching install.sh's
# `curl | bash` equivalent contract.
# ---------------------------------------------------------------------------

function Main {
    # No default skill when omitted in GLOBAL mode (US-17 D5 superseded by
    # D8) - an omitted `-Skill` discovers and installs EVERY skill that has a
    # release, see the GLOBAL-mode branch below. LOCAL mode keeps its
    # existing auto-detect-all-skills behavior.

    # Skill-name validation - BEFORE any interpolation into a URL, jq filter,
    # regex, or filesystem path.
    if ($Skill) {
        if (-not (Test-SkillName $Skill)) {
            exit 1
        }
    }

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

    # 3. Installation Logic
    if ($Local) {
        Write-Host "Installing in LOCAL Mode..."
        Install-Skills $BaseDir $BaseDir
    } else {
        Write-Host "Installing in GLOBAL Mode..."
        if ($Skill) {
            Install-OneSkillGlobal -SkillName $Skill -CentralDir $CentralDir
        } else {
            # US-17 D8: no -Skill given -> discover every distinct skill name
            # that has at least one <skill>-v* release in $REPO, then install
            # each one via the same single-skill flow. Never silently no-ops
            # and never defaults to a single skill.
            Write-Host "No -Skill specified; discovering all released skills in $REPO..."
            $tags = Get-ReleaseTags -Repo $REPO
            if ($null -eq $tags) {
                Write-Stderr "Error: Failed to query releases for $REPO. Ensure gh CLI is authenticated or curl/wget is installed and has internet access."
                exit 1
            }

            $discoveredNames = Get-SkillNamesFromTags -Tags $tags
            if ($discoveredNames.Count -eq 0) {
                Write-Stderr "Error: no releases found in $REPO."
                exit 1
            }

            Write-Host "Discovered skills: $($discoveredNames -join ', ')"
            foreach ($discoveredSkill in $discoveredNames) {
                Install-OneSkillGlobal -SkillName $discoveredSkill -CentralDir $CentralDir
            }
        }
    }

    Write-Host "Installation completed successfully!"
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}

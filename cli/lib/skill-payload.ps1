# lib/skill-payload.ps1
# Canonical PowerShell implementations shared by install.ps1 and update.ps1:
#   - Get-AgentPaths       : the supported agent-path list (static entries + dynamic
#                            .claude-* multi-account discovery)
#   - Copy-SkillFile       : SKILL.md + scripts/ + tests/ staged copy/swap
#   - New-KiroSteeringFile : Kiro steering-file frontmatter-injection transform
#
# Dot-sourcing scope note: dot-sourcing this file (". path\to\skill-payload.ps1") runs
# its top-level statements - and defines the functions below - directly in the
# *caller's* current scope rather than a new child scope. A PowerShell function's parent
# scope for variable lookups is fixed to the scope in which it was *defined*; because
# dot-sourcing defines these functions directly in the caller's scope, Get-AgentPaths and
# New-KiroSteeringFile can keep referencing $HomeDir exactly like the pre-unification
# inline code did, with no need to pass it as an explicit parameter. Variable lookup
# happens when the function is *called*, not when it is defined, so the caller only needs
# $HomeDir assigned before calling - not before dot-sourcing.
#
# Distribution timing (see CLAUDE.md "Installers" section for the full constraint):
# install.ps1 dot-sources this file from $SrcDir in local mode (a real checkout, always
# available on disk) or from $CentralDir in global mode - but only AFTER the release ZIP
# has been downloaded and extracted there. install.ps1 itself ships as a single
# self-contained file for the `irm <url> | iex` distribution path and cannot dot-source
# anything before that extraction happens, since no sibling files exist yet at that point.
# update.ps1 always runs from a real central-store checkout; it refreshes this file from
# the newly-downloaded release ZIP alongside scripts/ and tests/, then dot-sources the
# refreshed copy.

# Builds the agent path list from cli/agent-targets.json (static entries,
# parsed via ConvertFrom-Json) + dynamic .claude-* multi-account discovery
# (still runtime logic - a manifest can't enumerate accounts it can't see
# ahead of time). $PSScriptRoot resolves to THIS file's own directory
# regardless of caller scope (dot-sourcing runs this file's statements in the
# caller's scope, but automatic variables like $PSScriptRoot stay bound to
# the file that defines the currently-executing code) - the manifest always
# lives one directory up from lib/, in both local mode (a real checkout:
# cli\lib\skill-payload.ps1 next to cli\agent-targets.json) and global mode
# (the release ZIP mirrors the same cli\lib + cli\ layout inside
# $CentralDir - see New-ReleaseStagingPayload in Release-Repo.ps1). Manifest
# entries carrying a "transform" property (currently only Kiro) are
# deliberately excluded - those are handled by their own dedicated writer
# function (New-KiroSteeringFile), not the generic folder+SKILL.md copy this
# list feeds into.
function Get-AgentPaths ($skillName = "us-refinement") {
    $paths = [System.Collections.Generic.List[string]]::new()

    $manifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) "agent-targets.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Error "Error: agent-targets.json manifest not found at $manifestPath"
        exit 1
    }
    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json

    foreach ($entry in $manifest.targets) {
        if ($entry.transform) {
            continue
        }
        $relPath = $entry.path_template -replace '\{skill_name\}', $skillName
        $relPath = $relPath -replace '/', [System.IO.Path]::DirectorySeparatorChar
        $paths.Add((Join-Path $HomeDir $relPath))
    }

    if (Test-Path $HomeDir) {
        Get-ChildItem -Path $HomeDir -Filter ".claude-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $paths.Add((Join-Path $_.FullName "skills\$skillName"))
        }
    }

    return $paths
}

# Payload Copy Helper (SKILL.md + scripts/ + tests/ + assets/ + references/ + examples/)
# Stages the payload in a sibling ".staging" dir and swaps it into place only after every
# copy succeeds, so a mid-copy failure leaves the existing installed payload untouched.
function Copy-SkillFile ($targetPath, $sourcePath) {
    $stagingPath = "$targetPath.staging"
    if (Test-Path $stagingPath) {
        Remove-Item -Path $stagingPath -Force -Recurse | Out-Null
    }
    New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null

    $srcFile = Join-Path $sourcePath "SKILL.md"
    if (Test-Path $srcFile) {
        Write-Host "Copying SKILL.md to: $targetPath"
        Copy-Item -Path $srcFile -Destination $stagingPath -Force
    } else {
        Write-Error "Error: SKILL.md not found at $sourcePath"
        Remove-Item -Path $stagingPath -Force -Recurse | Out-Null
        exit 1
    }

    foreach ($dir in @("scripts", "tests", "assets", "references", "examples")) {
        $srcDir = Join-Path $sourcePath $dir
        if (Test-Path $srcDir) {
            Write-Host "Copying $dir/ to: $targetPath"
            Copy-Item -Path $srcDir -Destination $stagingPath -Recurse -Force
        }
    }

    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Force -Recurse | Out-Null
    }
    Move-Item -Path $stagingPath -Destination $targetPath
}

# Kiro Steering File Helper
# Kiro does not use the folder+SKILL.md format other agents use: it reads a single flat
# steering file at ~/.kiro/steering/<skill-name>.md with `inclusion: always` injected as
# the first key inside SKILL.md's YAML frontmatter. No scripts/ or tests/ payload - steering
# files are plain markdown only. Stages then swaps into place for the same atomicity
# guarantee as Copy-SkillFile.
function New-KiroSteeringFile ($sourcePath, $skillName) {
    if (-not $skillName) {
        $skillName = Split-Path -Leaf $sourcePath
    }
    $steeringDir = Join-Path $HomeDir ".kiro\steering"
    $targetFile = Join-Path $steeringDir "$skillName.md"
    $stagingFile = "$targetFile.staging"

    $srcFile = Join-Path $sourcePath "SKILL.md"
    if (-not (Test-Path $srcFile)) {
        Write-Error "Error: SKILL.md not found at $sourcePath"
        exit 1
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $rawContent = [System.IO.File]::ReadAllText($srcFile, $utf8NoBom)
    $frontmatterStart = [regex]::Match($rawContent, "^---(\r?\n)")
    if (-not $frontmatterStart.Success) {
        Write-Error "Error: SKILL.md at $sourcePath does not start with a '---' YAML frontmatter delimiter - cannot generate Kiro steering file."
        exit 1
    }

    New-Item -ItemType Directory -Path $steeringDir -Force | Out-Null
    Write-Host "Generating Kiro steering file: $targetFile"

    $eol = $frontmatterStart.Groups[1].Value
    $insertPos = $frontmatterStart.Length
    $transformed = $rawContent.Substring(0, $insertPos) + "inclusion: always" + $eol + $rawContent.Substring($insertPos)
    [System.IO.File]::WriteAllText($stagingFile, $transformed, $utf8NoBom)

    if (Test-Path $targetFile) {
        Remove-Item -Path $targetFile -Force
    }
    Move-Item -Path $stagingFile -Destination $targetFile
}

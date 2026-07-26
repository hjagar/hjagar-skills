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

function Get-AgentPaths {
    $paths = [System.Collections.Generic.List[string]]::new()
    $paths.Add((Join-Path $HomeDir ".gemini\skills\us-refinement"))
    $paths.Add((Join-Path $HomeDir ".claude\skills\us-refinement"))
    $paths.Add((Join-Path $HomeDir ".config\opencode\skills\us-refinement"))
    $paths.Add((Join-Path $HomeDir ".copilot\skills\us-refinement"))
    $paths.Add((Join-Path $HomeDir ".agents\skills\us-refinement"))
    $paths.Add((Join-Path $HomeDir ".cursor\skills\us-refinement"))

    if (Test-Path $HomeDir) {
        Get-ChildItem -Path $HomeDir -Filter ".claude-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $paths.Add((Join-Path $_.FullName "skills\us-refinement"))
        }
    }

    return $paths
}

# Payload Copy Helper (SKILL.md + scripts/ + tests/ — docs/ excluded on purpose)
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

    foreach ($dir in @("scripts", "tests", "assets", "references")) {
        $srcDir = Join-Path $sourcePath $dir
        if (Test-Path $srcDir) {
            Write-Host "Copying $dir/ to: $targetPath"
            Copy-Item -Path $srcDir -Destination $stagingPath -Recurse -Force
        } else {
            Write-Warning "Warning: $dir/ not found at $sourcePath - skipping."
        }
    }

    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Force -Recurse | Out-Null
    }
    Move-Item -Path $stagingPath -Destination $targetPath
}

# Kiro Steering File Helper
# Kiro does not use the folder+SKILL.md format other agents use: it reads a single flat
# steering file at ~/.kiro/steering/us-refinement.md with `inclusion: always` injected as
# the first key inside SKILL.md's YAML frontmatter. No scripts/ or tests/ payload - steering
# files are plain markdown only. Stages then swaps into place for the same atomicity
# guarantee as Copy-SkillFile.
function New-KiroSteeringFile ($sourcePath) {
    $steeringDir = Join-Path $HomeDir ".kiro\steering"
    $targetFile = Join-Path $steeringDir "us-refinement.md"
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

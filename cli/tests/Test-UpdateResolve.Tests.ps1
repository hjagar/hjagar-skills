# Pester tests (Phase 3.1 / 3.3) for update.ps1's network resolution
# boundary — same rationale/pattern as Test-InstallResolve.Tests.ps1.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UpdatePs1 = Join-Path $ScriptDir "..\update.ps1"

. $UpdatePs1 -Skill "req-discovery"

Describe "update.ps1 Get-ReleaseTags / Resolve-ReleaseTag" {
    It "gh present: resolves highest matching tag" {
        Mock Get-Command { [PSCustomObject]@{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-GhApi {
            $global:LASTEXITCODE = 0
            @("req-discovery-v1.0.0", "req-discovery-v1.10.0", "req-discovery-v1.9.0")
        }

        $tag = Resolve-ReleaseTag -Repo "hjagar/hjagar-skills" -SkillName "req-discovery"
        $tag | Should Be "req-discovery-v1.10.0"
    }

    It "gh absent: REST fallback resolves highest matching tag" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod {
            @(
                [PSCustomObject]@{ tag_name = "req-discovery-v1.0.0" },
                [PSCustomObject]@{ tag_name = "req-discovery-v1.10.0" }
            )
        }

        $tag = Resolve-ReleaseTag -Repo "hjagar/hjagar-skills" -SkillName "req-discovery"
        $tag | Should Be "req-discovery-v1.10.0"
    }

    It "gh absent, zero releases: returns a real (non-null) empty array" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod { @() }

        $tags = Get-ReleaseTags -Repo "hjagar/hjagar-skills"
        ($null -eq $tags) | Should Be $false
        $tags.Count | Should Be 0
    }

    It "no matching tag: Resolve-ReleaseTag returns null" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod {
            @([PSCustomObject]@{ tag_name = "us-refinement-v1.0.0" })
        }

        $tag = Resolve-ReleaseTag -Repo "hjagar/hjagar-skills" -SkillName "res-onboarding"
        $tag | Should Be $null
    }

    It "listing failure: Resolve-ReleaseTag throws" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod { throw "network down" }

        $threw = $false
        try {
            Resolve-ReleaseTag -Repo "hjagar/hjagar-skills" -SkillName "req-discovery" | Out-Null
        } catch {
            $threw = $true
        }
        $threw | Should Be $true
    }
}

Describe "update.ps1 Get-ReleaseZip" {
    It "gh present: downloads via Invoke-GhReleaseDownload" {
        $fixtureZip = Join-Path $ScriptDir "fixtures\data\req-discovery.zip"
        $outZip = Join-Path $env:TEMP ("pester-update-dl-" + [Guid]::NewGuid() + ".zip")

        Mock Get-Command { [PSCustomObject]@{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-GhReleaseDownload {
            param($Tag, $Repo, $SkillName, $OutZip)
            $global:LASTEXITCODE = 0
            Copy-Item $fixtureZip $OutZip -Force
        }

        $ok = Get-ReleaseZip -Repo "hjagar/hjagar-skills" -Tag "req-discovery-v1.10.0" -SkillName "req-discovery" -OutZip $outZip
        $ok | Should Be $true
        (Test-Path $outZip) | Should Be $true

        Remove-Item $outZip -Force -ErrorAction SilentlyContinue
    }
}

# Pester tests (Phase 2.3 / 2.4 / 5.1 / 5.2) for install.ps1's network
# resolution boundary. Dot-sources install.ps1 (safe — guarded, Main() never
# runs) then mocks Invoke-GhApi / Invoke-GhReleaseDownload / Get-Command /
# Invoke-RestMethod / Invoke-WebRequest so NO real network call is ever made.
# We call the extracted functions directly (Get-ReleaseTags /
# Resolve-ReleaseTag / Get-ReleaseZip) rather than Main(), because Main()
# calls `exit` on failure paths, which would terminate the whole Pester run
# instead of failing just one test.
#
# Note: mocking the bare external `gh` Application directly proved unreliable
# in this Pester 3.4 host (Get-Command kept resolving the real gh.exe ahead
# of the Pester-created function). install.ps1/update.ps1 route the actual
# `gh` invocation through Invoke-GhApi / Invoke-GhReleaseDownload wrapper
# functions specifically so Pester can mock a real PowerShell function
# instead (see install.ps1 comments for the same rationale).

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallPs1 = Join-Path $ScriptDir "..\install.ps1"

. $InstallPs1 -Local -Path $ScriptDir

Describe "Get-ReleaseTags / Resolve-ReleaseTag (gh present)" {
    It "lists tag_names via Invoke-GhApi output" {
        Mock Get-Command { [PSCustomObject]@{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-GhApi {
            $global:LASTEXITCODE = 0
            # Real `& gh ...` output auto-splits into an array of lines - mock
            # that faithfully rather than returning one multi-line string.
            @("req-discovery-v1.0.0", "req-discovery-v1.10.0", "req-discovery-v1.9.0")
        }

        $tags = Get-ReleaseTags -Repo "hjagar/hjagar-skills"
        $tags.Count | Should Be 3
        $tags -contains "req-discovery-v1.10.0" | Should Be $true
    }

    It "Resolve-ReleaseTag returns the highest matching tag via gh" {
        Mock Get-Command { [PSCustomObject]@{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-GhApi {
            $global:LASTEXITCODE = 0
            @("req-discovery-v1.0.0", "req-discovery-v1.10.0", "req-discovery-v1.9.0")
        }

        $tag = Resolve-ReleaseTag -Repo "hjagar/hjagar-skills" -SkillName "req-discovery"
        $tag | Should Be "req-discovery-v1.10.0"
    }
}

Describe "Get-ReleaseTags (gh absent — REST fallback)" {
    It "falls back to Invoke-RestMethod when gh is unavailable" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod {
            @(
                [PSCustomObject]@{ tag_name = "req-discovery-v1.0.0" },
                [PSCustomObject]@{ tag_name = "req-discovery-v1.10.0" },
                [PSCustomObject]@{ tag_name = "req-discovery-v1.9.0" }
            )
        }

        $tags = Get-ReleaseTags -Repo "hjagar/hjagar-skills"
        $tags.Count | Should Be 3

        $tag = Resolve-ReleaseTag -Repo "hjagar/hjagar-skills" -SkillName "req-discovery"
        $tag | Should Be "req-discovery-v1.10.0"
    }

    # NOTE: the REST-fallback "empty list", "no matching tag", and "listing
    # failure" scenarios are intentionally kept as It blocks WITHIN this same
    # Describe (rather than separate Describe blocks) — Pester 3.4's Mock
    # scoping proved unreliable for Get-Command/Invoke-RestMethod mocks
    # defined in DIFFERENT Describe blocks within the same file (state from
    # an earlier Describe's Mock leaked into a later one). Consolidating into
    # one Describe with per-It re-mocking is the reliable pattern this host's
    # Pester version supports.
    It "returns null (not throw) when REST succeeds with zero releases at all" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod { @() }

        $tags = Get-ReleaseTags -Repo "hjagar/hjagar-skills"
        ($null -eq $tags) | Should Be $false
        $tags.Count | Should Be 0
    }

    It "Resolve-ReleaseTag returns null when the list is fetched but nothing matches the skill prefix" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod {
            @(
                [PSCustomObject]@{ tag_name = "us-refinement-v1.0.0" },
                [PSCustomObject]@{ tag_name = "us-refinement-v1.5.0" }
            )
        }

        $tag = Resolve-ReleaseTag -Repo "hjagar/hjagar-skills" -SkillName "res-onboarding"
        $tag | Should Be $null
    }

    It "Resolve-ReleaseTag throws when neither gh nor REST can list releases at all" {
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

Describe "Get-ReleaseTags + Get-SkillNamesFromTags (US-17 D8 discover-all)" {
    It "discovers every distinct skill with a release, none skipped/duplicated" {
        Mock Get-Command { [PSCustomObject]@{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-GhApi {
            $global:LASTEXITCODE = 0
            @("us-refinement-v1.0.0", "req-discovery-v1.0.0", "req-discovery-v1.10.0", "tc-generator-v2.0.0")
        }

        $tags = Get-ReleaseTags -Repo "hjagar/hjagar-skills"
        $discovered = Get-SkillNamesFromTags -Tags $tags
        ($discovered -join ',') | Should Be "req-discovery,tc-generator,us-refinement"
    }

    It "excludes lookalike skills at the prefix boundary" {
        Mock Get-Command { [PSCustomObject]@{ Name = "gh" } } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-GhApi {
            $global:LASTEXITCODE = 0
            @("us-refinement-v1.0.0", "us-refinement-x-v9.9.9")
        }

        $tags = Get-ReleaseTags -Repo "hjagar/hjagar-skills"
        $discovered = Get-SkillNamesFromTags -Tags $tags
        ($discovered -join ',') | Should Be "us-refinement,us-refinement-x"
    }

    It "returns an empty (not null) set when the repo has zero releases" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-RestMethod { @() }

        $tags = Get-ReleaseTags -Repo "hjagar/hjagar-skills"
        ($null -eq $tags) | Should Be $false
        $discovered = Get-SkillNamesFromTags -Tags $tags
        ($null -eq $discovered) | Should Be $false
        $discovered.Count | Should Be 0
    }
}

Describe "Get-ReleaseZip (gh present)" {
    It "downloads the exact resolved tag's <skill>.zip via Invoke-GhReleaseDownload" {
        $fixtureZip = Join-Path $ScriptDir "fixtures\data\req-discovery.zip"
        $outZip = Join-Path $env:TEMP ("pester-dl-" + [Guid]::NewGuid() + ".zip")

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

Describe "Get-ReleaseZip (gh absent — HTTP fallback)" {
    It "falls back to Invoke-WebRequest when gh is unavailable" {
        $outZip = Join-Path $env:TEMP ("pester-dl-" + [Guid]::NewGuid() + ".zip")

        Mock Get-Command { $null } -ParameterFilter { $Name -eq "gh" }
        Mock Invoke-WebRequest {
            param($Uri, $OutFile)
            Set-Content -Path $OutFile -Value "fake-zip-bytes"
        }

        $ok = Get-ReleaseZip -Repo "hjagar/hjagar-skills" -Tag "req-discovery-v1.10.0" -SkillName "req-discovery" -OutZip $outZip
        $ok | Should Be $true
        (Test-Path $outZip) | Should Be $true

        Remove-Item $outZip -Force -ErrorAction SilentlyContinue
    }
}

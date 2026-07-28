# lib/quality-gate.ps1
# Shared quality gate discovery engine for participating skills.

function Invoke-QualityGate {
    param(
        [string]$RepoRoot = (git rev-parse --show-toplevel 2>$null)
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-Location
    }

    Write-Host "Running shared skill quality gate..." -ForegroundColor Cyan

    $skillsDir = Join-Path $RepoRoot "skills"
    if (-not (Test-Path $skillsDir)) {
        Write-Host "Error: skills directory not found at $skillsDir" -ForegroundColor Red
        return $false
    }

    $failed = $false
    $manifestCount = 0

    $manifests = Get-ChildItem -Path $skillsDir -Filter "validation.json" -Recurse -File -ErrorAction SilentlyContinue

    foreach ($manifest in $manifests) {
        $manifestCount++
        $skillDir = $manifest.Directory.FullName
        $data = Get-Content $manifest.FullName -Raw | ConvertFrom-Json
        $skillName = if ($data.skill) { $data.skill } else { $manifest.Directory.Name }
        $validatorRel = $data.validator

        if ([string]::IsNullOrWhiteSpace($validatorRel)) {
            Write-Host "Error: Manifest $($manifest.FullName) missing 'validator' field." -ForegroundColor Red
            $failed = $true
            continue
        }

        $validatorPath = Join-Path $skillDir $validatorRel
        if (-not (Test-Path $validatorPath)) {
            Write-Host "Error: Validator script not found at $validatorPath" -ForegroundColor Red
            $failed = $true
            continue
        }

        Write-Host "  [Quality Gate] Validating skill: $skillName" -ForegroundColor Gray

        if ($data.fixtures -and $data.fixtures.valid) {
            foreach ($vf in $data.fixtures.valid) {
                $vfPath = Join-Path $skillDir $vf
                Write-Host "    - Checking valid fixture $vf (expecting PASS)..." -ForegroundColor Gray
                python $validatorPath $vfPath
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    ERROR: Validation failed on valid fixture $vfPath for skill $skillName." -ForegroundColor Red
                    $failed = $true
                }
            }
        }

        if ($data.fixtures -and $data.fixtures.invalid) {
            foreach ($ivf in $data.fixtures.invalid) {
                $ivfPath = Join-Path $skillDir $ivf
                Write-Host "    - Checking invalid fixture $ivf (expecting FAIL)..." -ForegroundColor Gray
                python $validatorPath $ivfPath 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    ERROR: Validation unexpectedly succeeded on invalid fixture $ivfPath for skill $skillName." -ForegroundColor Red
                    $failed = $true
                }
            }
        }
    }

    if ($manifestCount -eq 0) {
        Write-Host "Warning: No validation manifests found in $skillsDir." -ForegroundColor Yellow
    }

    # Verify SKILL.md metadata versions for participating skills
    $reqDiscSkill = Join-Path $skillsDir "req-discovery/SKILL.md"
    if (Test-Path $reqDiscSkill) {
        Write-Host "  [Quality Gate] Checking req-discovery version declaration..." -ForegroundColor Gray
        $content = Get-Content $reqDiscSkill -Raw
        $fmMatch = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---')
        if (-not $fmMatch.Success) {
            Write-Host "    ERROR: req-discovery SKILL.md missing frontmatter block." -ForegroundColor Red
            $failed = $true
        } else {
            $verMatch = [regex]::Match($fmMatch.Groups[1].Value, 'version:\s*"?(?:v)?([0-9\.]+)"?')
            $actualVer = if ($verMatch.Success) { $verMatch.Groups[1].Value } else { "unknown" }
            if ($actualVer -ne "1.1.0") {
                Write-Host "    ERROR: req-discovery metadata.version '$actualVer' does not match expected version '1.1.0'." -ForegroundColor Red
                $failed = $true
            } else {
                Write-Host "    req-discovery metadata.version 1.1.0 verified." -ForegroundColor Green
            }
        }
    }

    return (-not $failed)
}

# If executed directly as a script
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s+') {
    $result = Invoke-QualityGate
    if (-not $result) {
        exit 1
    }
}

# lib/quality-gate.ps1
# Shared quality gate discovery engine for participating skills.

function Invoke-QualityGate {
    param(
        [string]$RepoRoot = (git rev-parse --show-toplevel 2>$null),
        [string]$TargetSkill = ""
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

    if (-not [string]::IsNullOrWhiteSpace($TargetSkill)) {
        $targetDir = Join-Path $skillsDir $TargetSkill
        if (-not (Test-Path $targetDir)) {
            Write-Host "Error: skill '$TargetSkill' not found at $targetDir" -ForegroundColor Red
            return $false
        }

        $manifest = Join-Path $targetDir "validation.json"
        if (Test-Path $manifest) {
            $manifestCount = 1
            $data = Get-Content $manifest -Raw | ConvertFrom-Json
            $skillName = if ($data.skill) { $data.skill } else { $TargetSkill }
            $validatorRel = $data.validator

            if ([string]::IsNullOrWhiteSpace($validatorRel)) {
                Write-Host "Error: Manifest $manifest missing 'validator' field." -ForegroundColor Red
                return $false
            }

            $validatorPath = Join-Path $targetDir $validatorRel
            if (-not (Test-Path $validatorPath)) {
                Write-Host "Error: Validator script not found at $validatorPath" -ForegroundColor Red
                return $false
            }

            Write-Host "  [Quality Gate] Validating skill: $skillName" -ForegroundColor Gray

            if ($data.fixtures -and $data.fixtures.valid) {
                foreach ($vf in $data.fixtures.valid) {
                    $vfPath = Join-Path $targetDir $vf
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
                    $ivfPath = Join-Path $targetDir $ivf
                    Write-Host "    - Checking invalid fixture $ivf (expecting FAIL)..." -ForegroundColor Gray
                    python $validatorPath $ivfPath 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "    ERROR: Validation unexpectedly succeeded on invalid fixture $ivfPath for skill $skillName." -ForegroundColor Red
                        $failed = $true
                    }
                }
            }
        } else {
            Write-Host "Error: no validation.json manifest found for $TargetSkill - quality gate requires one." -ForegroundColor Red
            return $false
        }
    } else {
        $skillDirs = Get-ChildItem -Path $skillsDir -Directory -ErrorAction SilentlyContinue

        foreach ($dir in $skillDirs) {
            $skillDir = $dir.FullName
            $manifestPath = Join-Path $skillDir "validation.json"

            if (-not (Test-Path $manifestPath)) {
                Write-Host "Error: skill '$($dir.Name)' is missing validation.json - quality gate requires one." -ForegroundColor Red
                $failed = $true
                continue
            }

            $manifestCount++
            $data = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $skillName = if ($data.skill) { $data.skill } else { $dir.Name }
            $validatorRel = $data.validator

            if ([string]::IsNullOrWhiteSpace($validatorRel)) {
                Write-Host "Error: Manifest $manifestPath missing 'validator' field." -ForegroundColor Red
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
    }

    return (-not $failed)
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s+') {
    $result = Invoke-QualityGate
    if (-not $result) {
        exit 1
    }
}

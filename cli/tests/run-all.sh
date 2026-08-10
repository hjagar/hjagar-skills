#!/usr/bin/env bash
# Runs every bash test script + Pester/plain-assertion PowerShell test script
# for the US-17 skill-release-resolution (install.sh/.ps1, update.sh/.ps1)
# and skill-release-publishing (Release-Repo.sh/.ps1) capabilities. Exits
# non-zero if any suite fails.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OVERALL_STATUS=0

run_bash_suite() {
    echo "=== $1 ==="
    bash "$SCRIPT_DIR/$1"
    local status=$?
    if [ $status -ne 0 ]; then OVERALL_STATUS=1; fi
    echo ""
    return $status
}

run_pwsh_suite() {
    echo "=== $1 ==="
    pwsh -NoProfile -File "$SCRIPT_DIR/$1"
    local status=$?
    if [ $status -ne 0 ]; then OVERALL_STATUS=1; fi
    echo ""
    return $status
}

run_pester_suite() {
    echo "=== $1 (Pester) ==="
    local win_path
    if command -v cygpath &>/dev/null; then
        win_path="$(cygpath -w "$SCRIPT_DIR/$1")"
    else
        win_path="$SCRIPT_DIR/$1"
    fi
    pwsh -NoProfile -Command "
        Import-Module Pester -RequiredVersion 3.4.0
        \$r = Invoke-Pester -Script '$win_path' -PassThru
        if (\$r.FailedCount -gt 0 -or \$r.TotalCount -eq 0) { exit 1 } else { exit 0 }
    "
    local status=$?
    if [ $status -ne 0 ]; then OVERALL_STATUS=1; fi
    echo ""
    return $status
}

run_bash_suite  "test-install-unit.sh"
run_bash_suite  "test-update-unit.sh"
run_bash_suite  "test-install-integration.sh"
run_bash_suite  "test-update-integration.sh"

run_bash_suite  "test-release-repo-unit.sh"
run_bash_suite  "test-release-repo-integration.sh"

if command -v pwsh &>/dev/null; then
    run_pwsh_suite   "Test-InstallUnit.ps1"
    run_pwsh_suite   "Test-UpdateUnit.ps1"
    run_pester_suite "Test-InstallResolve.Tests.ps1"
    run_pester_suite "Test-UpdateResolve.Tests.ps1"
    run_pwsh_suite   "Test-InstallIntegration.ps1"
    run_pwsh_suite   "Test-UpdateIntegration.ps1"
    run_bash_suite   "test-parity.sh"
    run_pwsh_suite   "Test-ReleaseRepoUnit.ps1"
    run_pwsh_suite   "Test-ReleaseRepoIntegration.ps1"
    run_bash_suite   "test-release-repo-parity.sh"
else
    echo "SKIP: pwsh not found — skipping all PowerShell test suites"
fi

if [ $OVERALL_STATUS -eq 0 ]; then
    echo "ALL SUITES PASSED"
else
    echo "SOME SUITES FAILED"
fi
exit $OVERALL_STATUS

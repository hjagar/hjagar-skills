#!/usr/bin/env bash
# Parity tests (PR2, US-17 Phase 5.4 — Release-Repo half) — Release-Repo.sh
# vs Release-Repo.ps1: identical D6 preflight-guard decisions and identical
# D4 staged-payload layout for the same inputs. Kept as a separate file from
# cli/tests/test-parity.sh (PR1, install/update-scoped) so that suite is
# never touched by PR2 work. Requires `pwsh` on PATH.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_REPO_SH="$REPO_ROOT/cli/Release-Repo.sh"
RELEASE_REPO_PS1="$REPO_ROOT/cli/Release-Repo.ps1"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1)); echo "ok - $desc"
    else
        FAIL=$((FAIL+1)); echo "NOT OK - $desc (expected [$expected], got [$actual])"
    fi
}

if ! command -v pwsh &>/dev/null; then
    echo "SKIP: pwsh not on PATH — cannot run shell/PowerShell parity tests"
    exit 0
fi

to_win_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

RELEASE_REPO_PS1_WIN="$(to_win_path "$RELEASE_REPO_PS1")"

# ---------------------------------------------------------------------------
# check_publish_target (bash) vs Test-PublishTarget (ps1) — identical
# accept/reject decision for the same inputs.
# ---------------------------------------------------------------------------
check_target_bash() {
    local expected="$1" actual="$2"
    (
        # shellcheck disable=SC1090
        source "$RELEASE_REPO_SH" >/dev/null 2>&1
        check_publish_target "$expected" "$actual" >/dev/null 2>&1
    )
    echo "$?"
}

check_target_ps1() {
    local expected="$1" actual="$2"
    pwsh -NoProfile -Command "
        . '$RELEASE_REPO_PS1_WIN' | Out-Null
        if (Test-PublishTarget -Expected '$expected' -Actual '$actual') { '0' } else { '1' }
    " 2>/dev/null | tr -d '\r'
}

for CASE in "hjagar/hjagar-skills|hjagar/hjagar-skills|match" "hjagar/hjagar-skills|someone-else/other-repo|mismatch" "hjagar/hjagar-skills||empty"; do
    IFS='|' read -r EXPECTED ACTUAL LABEL <<< "$CASE"
    BASH_STATUS="$(check_target_bash "$EXPECTED" "$ACTUAL")"
    PS1_STATUS="$(check_target_ps1 "$EXPECTED" "$ACTUAL")"
    assert_eq "check_publish_target/Test-PublishTarget agree on $LABEL" "$BASH_STATUS" "$PS1_STATUS"
done

# ---------------------------------------------------------------------------
# stage_release_payload (bash) vs New-ReleaseStagingPayload (ps1) — same
# skill fixture produces the same set of relative paths in both staging
# dirs (US-17 D4 layout parity).
# ---------------------------------------------------------------------------
PARITY_TMP="$(mktemp -d)"
FAKE_REPO_ROOT="$PARITY_TMP/repo-root"
FAKE_SKILL_DIR="$FAKE_REPO_ROOT/skills/parity-skill"
STAGING_BASH="$PARITY_TMP/staging-bash"
STAGING_PS1="$PARITY_TMP/staging-ps1"

mkdir -p "$FAKE_REPO_ROOT/cli/lib" "$FAKE_SKILL_DIR/assets"
echo "# parity-skill SKILL.md" > "$FAKE_SKILL_DIR/SKILL.md"
echo "asset content" > "$FAKE_SKILL_DIR/assets/example.txt"
echo "#!/usr/bin/env bash" > "$FAKE_REPO_ROOT/cli/lib/skill-payload.sh"
echo "# ps1 payload" > "$FAKE_REPO_ROOT/cli/lib/skill-payload.ps1"

(
    # shellcheck disable=SC1090
    source "$RELEASE_REPO_SH" >/dev/null 2>&1
    stage_release_payload "$FAKE_REPO_ROOT" "parity-skill" "$FAKE_SKILL_DIR" "$STAGING_BASH"
)

FAKE_REPO_ROOT_WIN="$(to_win_path "$FAKE_REPO_ROOT")"
FAKE_SKILL_DIR_WIN="$(to_win_path "$FAKE_SKILL_DIR")"
STAGING_PS1_WIN="$(to_win_path "$STAGING_PS1")"

pwsh -NoProfile -Command "
    . '$RELEASE_REPO_PS1_WIN' | Out-Null
    New-ReleaseStagingPayload -RepoRoot '$FAKE_REPO_ROOT_WIN' -SkillName 'parity-skill' -SkillDir '$FAKE_SKILL_DIR_WIN' -StagingDir '$STAGING_PS1_WIN'
" >/dev/null 2>&1

BASH_LISTING="$(cd "$STAGING_BASH" && find . -type f | sed 's#^\./##' | LC_ALL=C sort)"
PS1_LISTING="$(cd "$STAGING_PS1" && find . -type f | sed 's#^\./##' | LC_ALL=C sort)"

assert_eq "staged payload file set: bash produces the expected 4 files" \
    "$(printf 'cli/lib/skill-payload.ps1\ncli/lib/skill-payload.sh\nskills/parity-skill/SKILL.md\nskills/parity-skill/assets/example.txt')" \
    "$BASH_LISTING"
assert_eq "staged payload file set: bash and ps1 agree" "$BASH_LISTING" "$PS1_LISTING"

rm -rf "$PARITY_TMP"

echo ""
echo "release-repo-parity: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

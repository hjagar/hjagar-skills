#!/usr/bin/env bash
# Parity tests (Phase 5.4): install.sh vs install.ps1 (and update.sh vs
# update.ps1) resolve the same tag, emit identical unhappy-path error text,
# and exit with the same code for the same inputs. Requires `pwsh` on PATH.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/cli/install.sh"
INSTALL_PS1="$REPO_ROOT/cli/install.ps1"
UPDATE_SH="$REPO_ROOT/cli/update.sh"
UPDATE_PS1="$REPO_ROOT/cli/update.ps1"

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

# pwsh needs Windows-style paths, not git-bash's /c/... POSIX-style paths.
to_win_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

INSTALL_PS1_WIN="$(to_win_path "$INSTALL_PS1")"
UPDATE_PS1_WIN="$(to_win_path "$UPDATE_PS1")"
SCRIPT_DIR_WIN="$(to_win_path "$SCRIPT_DIR")"

# ---------------------------------------------------------------------------
# select_highest_tag (bash) vs Select-HighestTag (ps1) — identical resolution
# ---------------------------------------------------------------------------
TAGS_ARG='req-discovery-v1.0.0,req-discovery-v1.10.0,req-discovery-v1.9.0,us-refinement-v2.0.0,us-refinement-x-v9.9.9'

BASH_RESULT="$(
    # shellcheck disable=SC1090
    source "$INSTALL_SH" >/dev/null 2>&1
    select_highest_tag "req-discovery" "$(printf '%s' "$TAGS_ARG" | tr ',' '\n')"
)"

PS1_RESULT="$(pwsh -NoProfile -Command "
    . '$INSTALL_PS1_WIN' -Local -Path '$SCRIPT_DIR_WIN' | Out-Null
    \$tags = '$TAGS_ARG' -split ','
    Select-HighestTag -SkillName 'req-discovery' -Tags \$tags
" 2>/dev/null | tr -d '\r')"

assert_eq "select_highest_tag / Select-HighestTag resolve the same tag (req-discovery)" \
    "req-discovery-v1.10.0" "$BASH_RESULT"
assert_eq "bash and ps1 resolvers agree with each other" "$BASH_RESULT" "$PS1_RESULT"

PS1_RESULT_2="$(pwsh -NoProfile -Command "
    . '$INSTALL_PS1_WIN' -Local -Path '$SCRIPT_DIR_WIN' | Out-Null
    \$tags = '$TAGS_ARG' -split ','
    Select-HighestTag -SkillName 'us-refinement' -Tags \$tags
" 2>/dev/null | tr -d '\r')"
BASH_RESULT_2="$(
    # shellcheck disable=SC1090
    source "$INSTALL_SH" >/dev/null 2>&1
    select_highest_tag "us-refinement" "$(printf '%s' "$TAGS_ARG" | tr ',' '\n')"
)"
assert_eq "prefix-boundary parity: us-refinement-v* vs us-refinement-x-v*" \
    "$BASH_RESULT_2" "$PS1_RESULT_2"

# ---------------------------------------------------------------------------
# Phase 5.5 (US-17 D8) — discover-all-skills fixture matrix produces
# identical discovered-name sets across install.sh vs install.ps1.
# ---------------------------------------------------------------------------
DISCOVERY_TAGS_ARG='us-refinement-v1.0.0,req-discovery-v1.0.0,req-discovery-v1.10.0,tc-generator-v2.0.0,us-refinement-x-v9.9.9,not-a-valid-tag'

BASH_DISCOVERED="$(
    # shellcheck disable=SC1090
    source "$INSTALL_SH" >/dev/null 2>&1
    extract_skill_names_from_tags "$(printf '%s' "$DISCOVERY_TAGS_ARG" | tr ',' '\n')" | tr '\n' ',' | sed 's/,$//'
)"

PS1_DISCOVERED="$(pwsh -NoProfile -Command "
    . '$INSTALL_PS1_WIN' -Local -Path '$SCRIPT_DIR_WIN' | Out-Null
    \$tags = '$DISCOVERY_TAGS_ARG' -split ','
    (Get-SkillNamesFromTags -Tags \$tags) -join ','
" 2>/dev/null | tr -d '\r')"

assert_eq "discover-all-skills fixture matrix: bash produces expected set" \
    "req-discovery,tc-generator,us-refinement,us-refinement-x" "$BASH_DISCOVERED"
assert_eq "discover-all-skills fixture matrix: bash and ps1 agree" "$BASH_DISCOVERED" "$PS1_DISCOVERED"

# ---------------------------------------------------------------------------
# No-release error text — identical across all 4 scripts
# ---------------------------------------------------------------------------
BASH_INSTALL_ERR="$(
    # shellcheck disable=SC1090
    source "$INSTALL_SH" >/dev/null 2>&1
    print_no_release_error "res-onboarding" 2>&1
)"
BASH_UPDATE_ERR="$(
    # shellcheck disable=SC1090
    source "$UPDATE_SH" >/dev/null 2>&1
    print_no_release_error "res-onboarding" 2>&1
)"
PS1_INSTALL_ERR="$(pwsh -NoProfile -Command "
    . '$INSTALL_PS1_WIN' -Local -Path '$SCRIPT_DIR_WIN' | Out-Null
    Write-NoReleaseError -SkillName 'res-onboarding' -Repo 'hjagar/hjagar-skills'
" 2>&1 | tr -d '\r')"
PS1_UPDATE_ERR="$(pwsh -NoProfile -Command "
    . '$UPDATE_PS1_WIN' -Skill 'res-onboarding' | Out-Null
    Write-NoReleaseError -SkillName 'res-onboarding' -Repo 'hjagar/hjagar-skills'
" 2>&1 | tr -d '\r')"

assert_eq "install.sh vs update.sh no-release error text" "$BASH_INSTALL_ERR" "$BASH_UPDATE_ERR"
assert_eq "install.sh vs install.ps1 no-release error text" "$BASH_INSTALL_ERR" "$PS1_INSTALL_ERR"
assert_eq "install.sh vs update.ps1 no-release error text" "$BASH_INSTALL_ERR" "$PS1_UPDATE_ERR"

# ---------------------------------------------------------------------------
# Threat matrix parity — same malformed input, same exit code, both shells
# ---------------------------------------------------------------------------
for bad in "a b" "../x"; do
    HOME_DIR="$(mktemp -d)"
    HOME="$HOME_DIR" bash "$INSTALL_SH" --skill "$bad" >/dev/null 2>&1
    BASH_STATUS=$?

    HOME_DIR2="$(mktemp -d)"
    PS1_STATUS=$(USERPROFILE="$HOME_DIR2" pwsh -NoProfile -File "$INSTALL_PS1_WIN" -Skill "$bad" >/dev/null 2>&1; echo $?)

    assert_eq "malformed --skill/-Skill '$bad' exit code parity" "$BASH_STATUS" "$PS1_STATUS"
    rm -rf "$HOME_DIR" "$HOME_DIR2"
done

echo ""
echo "parity: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

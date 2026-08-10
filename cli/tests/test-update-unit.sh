#!/usr/bin/env bash
# Unit tests (Phase 1.5 / 3.1): validate_skill_name + select_highest_tag +
# detect_local_version in update.sh. Sourcing update.sh is safe because it is
# guarded — no update side effects run.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SH="$SCRIPT_DIR/../update.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL+1))
        echo "NOT OK - $desc (expected [$expected], got [$actual])"
    fi
}

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL+1))
        echo "NOT OK - $desc (expected exit $expected, got $actual)"
    fi
}

assert_true() {
    local desc="$1" cond="$2"
    if [ "$cond" = "true" ]; then
        PASS=$((PASS+1))
        echo "ok - $desc"
    else
        FAIL=$((FAIL+1))
        echo "NOT OK - $desc"
    fi
}

# shellcheck disable=SC1090
source "$UPDATE_SH"
set +e

# --- validate_skill_name ----------------------------------------------------

validate_skill_name "req-discovery" >/dev/null 2>&1
assert_status "valid skill name accepted" "0" "$?"

validate_skill_name "a b" >/dev/null 2>&1
assert_status "space in skill name rejected" "1" "$?"

validate_skill_name "../x" >/dev/null 2>&1
assert_status "path traversal skill name rejected" "1" "$?"

validate_skill_name '$(id)' >/dev/null 2>&1
assert_status "command substitution skill name rejected" "1" "$?"

# --- select_highest_tag (pure) ----------------------------------------------

TAGS=$'req-discovery-v1.0.0\nreq-discovery-v1.10.0\nreq-discovery-v1.9.0\nus-refinement-v2.0.0\nus-refinement-x-v9.9.9'

RESULT=$(select_highest_tag "req-discovery" "$TAGS")
assert_eq "2-digit-safe semver ordering: v1.10.0 beats v1.9.0" "req-discovery-v1.10.0" "$RESULT"

RESULT=$(select_highest_tag "us-refinement" "$TAGS")
assert_eq "prefix boundary excludes lookalike skill" "us-refinement-v2.0.0" "$RESULT"

# --- detect_local_version (approval — captures pre-existing frontmatter logic) --

TMP_CENTRAL="$(mktemp -d)"
mkdir -p "$TMP_CENTRAL/skills/req-discovery"
cat > "$TMP_CENTRAL/skills/req-discovery/SKILL.md" <<'EOF'
---
name: req-discovery
metadata:
  version: v3.2.1
---
body
EOF
CENTRAL_DIR="$TMP_CENTRAL"
RESULT=$(detect_local_version "req-discovery")
assert_eq "detects frontmatter version" "v3.2.1" "$RESULT"

RESULT=$(detect_local_version "does-not-exist"); STATUS=$?
assert_status "missing skill file returns failure status" "1" "$STATUS"

rm -rf "$TMP_CENTRAL"

# --- discover_locally_installed_skills (US-17 D8 — update never defaults) --

TMP_CENTRAL2="$(mktemp -d)"
mkdir -p "$TMP_CENTRAL2/skills/req-discovery" "$TMP_CENTRAL2/skills/tc-generator"
touch "$TMP_CENTRAL2/skills/req-discovery/SKILL.md" "$TMP_CENTRAL2/skills/tc-generator/SKILL.md"
mkdir -p "$TMP_CENTRAL2/skills/empty-dir-no-skill-md"
CENTRAL_DIR="$TMP_CENTRAL2"
RESULT="$(discover_locally_installed_skills | sort)"
assert_eq "discovers every locally-installed skill, dir without SKILL.md excluded" \
    "$(printf 'req-discovery\ntc-generator')" "$RESULT"
if printf '%s' "$RESULT" | grep -q '^us-refinement$'; then
    assert_true "never defaults to only us-refinement" "false"
else
    assert_true "never defaults to only us-refinement" "true"
fi
rm -rf "$TMP_CENTRAL2"

TMP_CENTRAL3="$(mktemp -d)"
CENTRAL_DIR="$TMP_CENTRAL3"
RESULT="$(discover_locally_installed_skills)"
assert_eq "no locally-installed skills returns empty" "" "$RESULT"
rm -rf "$TMP_CENTRAL3"

echo ""
echo "update-unit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

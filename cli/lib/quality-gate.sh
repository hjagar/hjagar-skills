#!/usr/bin/env bash
# lib/quality-gate.sh
# Shared quality gate discovery engine for participating skills.

run_quality_gate() {
    local repo_root="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    local failed=false
    local manifest_count=0

    echo "Running shared skill quality gate..."

    local skills_dir="$repo_root/skills"
    if [[ ! -d "$skills_dir" ]]; then
        echo "Error: skills directory not found at $skills_dir" >&2
        return 1
    fi

    for manifest in "$skills_dir"/*/validation.json; do
        [[ -f "$manifest" ]] || continue
        manifest_count=$((manifest_count + 1))

        local skill_dir
        skill_dir="$(dirname "$manifest")"
        local default_skill_name
        default_skill_name="$(basename "$skill_dir")"

        local skill_name validator_rel
        skill_name=$(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); print(data.get('skill', sys.argv[2]))" "$manifest" "$default_skill_name")
        validator_rel=$(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); print(data.get('validator', ''))" "$manifest")

        if [[ -z "$validator_rel" ]]; then
            echo "Error: Manifest $manifest missing 'validator' field." >&2
            failed=true
            continue
        fi

        local validator_path="$skill_dir/$validator_rel"
        if [[ ! -f "$validator_path" ]]; then
            echo "Error: Validator script not found at $validator_path" >&2
            failed=true
            continue
        fi

        echo "  [Quality Gate] Validating skill: $skill_name"

        # Read valid fixtures
        local vf
        while IFS= read -r vf; do
            [[ -n "$vf" ]] || continue
            local vf_path="$skill_dir/$vf"
            echo "    - Checking valid fixture $vf (expecting PASS)..."
            if ! python3 "$validator_path" "$vf_path"; then
                echo "    ERROR: Validation failed on valid fixture $vf_path for skill $skill_name." >&2
                failed=true
            fi
        done < <(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); [print(f) for f in data.get('fixtures', {}).get('valid', [])]" "$manifest")

        # Read invalid fixtures
        local ivf
        while IFS= read -r ivf; do
            [[ -n "$ivf" ]] || continue
            local ivf_path="$skill_dir/$ivf"
            echo "    - Checking invalid fixture $ivf (expecting FAIL)..."
            if python3 "$validator_path" "$ivf_path" &>/dev/null; then
                echo "    ERROR: Validation unexpectedly succeeded on invalid fixture $ivf_path for skill $skill_name." >&2
                failed=true
            fi
        done < <(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); [print(f) for f in data.get('fixtures', {}).get('invalid', [])]" "$manifest")
    done

    if [[ "$manifest_count" -eq 0 ]]; then
        echo "Warning: No validation manifests found in $skills_dir." >&2
    fi

    # Verify SKILL.md metadata versions for participating skills
    local req_disc_skill="$skills_dir/req-discovery/SKILL.md"
    if [[ -f "$req_disc_skill" ]]; then
        echo "  [Quality Gate] Checking req-discovery version declaration..."
        local actual_ver
        actual_ver=$(python3 -c "import sys, re; content=open(sys.argv[1], encoding='utf-8').read(); fm=re.search(r'(?s)\A---\r?\n(.*?)\r?\n---', content); ver=re.search(r'version:\s*\"?(?:v)?([0-9\.]+)\"?', fm.group(1)) if fm else None; print(ver.group(1) if ver else 'unknown')" "$req_disc_skill")
        if [[ "$actual_ver" != "1.1.0" ]]; then
            echo "    ERROR: req-discovery metadata.version '$actual_ver' does not match expected version '1.1.0'." >&2
            failed=true
        else
            echo "    req-discovery metadata.version 1.1.0 verified."
        fi
    fi

    if [[ "$failed" == true ]]; then
        return 1
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_quality_gate "$@"
fi

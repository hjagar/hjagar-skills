#!/usr/bin/env bash
# lib/quality-gate.sh
# Shared quality gate discovery engine for participating skills.

run_quality_gate() {
    local repo_root="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    local target_skill="${2:-}"
    local failed=false
    local manifest_count=0

    echo "Running shared skill quality gate..."

    local skills_dir="$repo_root/skills"
    if [[ ! -d "$skills_dir" ]]; then
        echo "Error: skills directory not found at $skills_dir" >&2
        return 1
    fi

    if [[ -n "$target_skill" ]]; then
        local target_dir="$skills_dir/$target_skill"
        if [[ ! -d "$target_dir" ]]; then
            echo "Error: skill '$target_skill' not found at $target_dir" >&2
            return 1
        fi

        local manifest="$target_dir/validation.json"
        if [[ -f "$manifest" ]]; then
            manifest_count=1
            local skill_name validator_rel
            skill_name=$(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); print(data.get('skill', sys.argv[2]))" "$manifest" "$target_skill")
            validator_rel=$(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); print(data.get('validator', ''))" "$manifest")

            if [[ -z "$validator_rel" ]]; then
                echo "Error: Manifest $manifest missing 'validator' field." >&2
                return 1
            fi

            local validator_path="$target_dir/$validator_rel"
            if [[ ! -f "$validator_path" ]]; then
                echo "Error: Validator script not found at $validator_path" >&2
                return 1
            fi

            echo "  [Quality Gate] Validating skill: $skill_name"

            local vf
            while IFS= read -r vf; do
                [[ -n "$vf" ]] || continue
                local vf_path="$target_dir/$vf"
                echo "    - Checking valid fixture $vf (expecting PASS)..."
                if ! python3 "$validator_path" "$vf_path"; then
                    echo "    ERROR: Validation failed on valid fixture $vf_path for skill $skill_name." >&2
                    failed=true
                fi
            done < <(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); [print(f) for f in data.get('fixtures', {}).get('valid', [])]" "$manifest")

            local ivf
            while IFS= read -r ivf; do
                [[ -n "$ivf" ]] || continue
                local ivf_path="$target_dir/$ivf"
                echo "    - Checking invalid fixture $ivf (expecting FAIL)..."
                if python3 "$validator_path" "$ivf_path" &>/dev/null; then
                    echo "    ERROR: Validation unexpectedly succeeded on invalid fixture $ivf_path for skill $skill_name." >&2
                    failed=true
                fi
            done < <(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); [print(f) for f in data.get('fixtures', {}).get('invalid', [])]" "$manifest")
        else
            echo "Error: no validation.json manifest found for $target_skill — quality gate requires one." >&2
            return 1
        fi
    else
        for skill_dir in "$skills_dir"/*/; do
            [[ -d "$skill_dir" ]] || continue
            skill_dir="${skill_dir%/}"
            local default_skill_name
            default_skill_name="$(basename "$skill_dir")"
            local manifest="$skill_dir/validation.json"

            if [[ ! -f "$manifest" ]]; then
                echo "Error: skill '$default_skill_name' is missing validation.json — quality gate requires one." >&2
                failed=true
                continue
            fi

            manifest_count=$((manifest_count + 1))

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
    fi

    if [[ "$failed" == true ]]; then
        return 1
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_quality_gate "$@"
fi

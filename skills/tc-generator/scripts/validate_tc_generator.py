#!/usr/bin/env python3
import sys
import re

def validate_content(content, banner):
    print(banner)
    errors = []

    # 1. Validate Confidence Tag
    confidence_match = re.search(r"(?:confidence|Confidence):\s*(high|low)", content)
    if not confidence_match:
        errors.append("Missing explicit confidence tag ('Confidence: high' or 'Confidence: low').")
    else:
        confidence_level = confidence_match.group(1).lower()
        if confidence_level == 'low':
            if "requires human review" not in content.lower():
                errors.append("Low-confidence outputs MUST include 'requires human review'.")

    # 2. Validate Track A Exclusion when existing tests are reported
    existing_tests_match = re.search(r"(?:existing_tests|Existing Tests|existing tests):\s*(true|false|yes|no)", content, re.IGNORECASE)
    if existing_tests_match:
        has_tests = existing_tests_match.group(1).lower() in ['true', 'yes']
        if has_tests:
            if re.search(r"##\s*(?:Track A|Unit [Tt]est [Ss]uggestions)", content):
                errors.append("Track A (Unit test suggestions) MUST NOT be generated when existing tests are present.")

    # 3. Validate Track B Presence
    track_b_match = re.search(r"##\s*(?:Track B|QA [Mm]anual [Cc]hecklist|QA [Cc]hecklist)", content)
    if not track_b_match:
        errors.append("Missing required Track B section ('## Track B' or '## QA Manual Checklist').")
    else:
        # Validate Track B Groups: Happy path, Edge cases, Negative/error cases
        track_b_text = content[track_b_match.start():]

        if not re.search(r"###?\s*Happy [Pp]ath", track_b_text):
            errors.append("Track B MUST contain a 'Happy path' group.")
        if not re.search(r"###?\s*Edge [Cc]ases", track_b_text):
            errors.append("Track B MUST contain an 'Edge cases' group.")
        if not re.search(r"###?\s*(?:Negative|Error|Negative\s*/\s*Error)\s+[Cc]ases", track_b_text, re.IGNORECASE):
            errors.append("Track B MUST contain a 'Negative/error cases' group.")

        # Validate Test Case Structure in Track B: Precondition, Steps, Expected result
        if "precondition" not in track_b_text.lower():
            errors.append("Track B test cases MUST include 'Precondition:'.")
        if "expected result" not in track_b_text.lower():
            errors.append("Track B test cases MUST include 'Expected result:'.")

    if errors:
        print("\nValidation failed with the following errors:")
        for err in errors:
            print(f"  - {err}")
        return False

    print("\nValidation successful! Test cases document conforms to tc-generator hard rules.")
    return True

def validate(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error: Unable to read file {file_path}. Details: {e}")
        return False

    return validate_content(content, f"Validating test cases file: {file_path}")

def validate_stdin():
    try:
        content = sys.stdin.buffer.read().decode('utf-8')
    except Exception as e:
        print(f"Error: Unable to read content from stdin. Details: {e}")
        return False

    return validate_content(content, "Validating test cases content from stdin")

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        success = validate(sys.argv[1])
    elif not sys.stdin.isatty():
        success = validate_stdin()
    else:
        print("Usage: python validate_tc_generator.py <path_to_markdown_file>")
        print("       or pipe content via stdin: cat file.md | python validate_tc_generator.py")
        sys.exit(1)

    sys.exit(0 if success else 1)

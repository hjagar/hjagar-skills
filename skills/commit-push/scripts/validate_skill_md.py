#!/usr/bin/env python3
"""Structural validator for process skills (no generated-document output).

Unlike output-document validators (tc-generator, us-refinement, ...), this
validates the skill's own SKILL.md: frontmatter shape, required sections per
the repo's skill anatomy convention, and the no-AI-attribution hard rule.
"""
import sys
import re


def validate_content(content, banner):
    print(banner)
    errors = []

    # 1. Frontmatter block present with name + description.
    fm_match = re.search(r"\A---\r?\n(.*?)\r?\n---", content, re.DOTALL)
    if not fm_match:
        errors.append("Missing YAML frontmatter block (--- ... ---) at the top of the file.")
    else:
        frontmatter = fm_match.group(1)
        if not re.search(r"^name:\s*\S+", frontmatter, re.MULTILINE):
            errors.append("Frontmatter missing 'name:' field.")
        if not re.search(r"^description:\s*\S+", frontmatter, re.MULTILINE):
            errors.append("Frontmatter missing 'description:' field.")

    # 2. Required sections per the repo's skill anatomy convention.
    for section in ("Activation Contract", "Hard Rules", "Decision Gates"):
        if not re.search(rf"^##\s+{re.escape(section)}\b", content, re.MULTILINE):
            errors.append(f"Missing required '## {section}' section.")

    # 3. No AI attribution — process skills commit on the user's behalf and
    #    must never inject a Co-Authored-By trailer. Match only the actual
    #    trailer shape (line-start, colon, a value) so Hard Rules prose that
    #    merely *talks about* not adding one doesn't false-positive.
    if re.search(r"^co-authored-by:\s*\S", content, re.IGNORECASE | re.MULTILINE):
        errors.append("SKILL.md must not contain a literal 'Co-Authored-By:' trailer — process skills never add AI attribution to commits.")

    if errors:
        print("\nValidation failed with the following errors:")
        for err in errors:
            print(f"  - {err}")
        return False

    print("\nValidation successful! SKILL.md conforms to the repo's skill anatomy and attribution rules.")
    return True


def validate(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"Error: Unable to read file {file_path}. Details: {e}")
        return False

    return validate_content(content, f"Validating SKILL.md: {file_path}")


def validate_stdin():
    try:
        content = sys.stdin.buffer.read().decode("utf-8")
    except Exception as e:
        print(f"Error: Unable to read content from stdin. Details: {e}")
        return False

    return validate_content(content, "Validating SKILL.md content from stdin")


if __name__ == "__main__":
    if len(sys.argv) >= 2:
        success = validate(sys.argv[1])
    elif not sys.stdin.isatty():
        success = validate_stdin()
    else:
        print("Usage: python validate_skill_md.py <path_to_SKILL.md>")
        print("       or pipe content via stdin: cat SKILL.md | python validate_skill_md.py")
        sys.exit(1)

    sys.exit(0 if success else 1)

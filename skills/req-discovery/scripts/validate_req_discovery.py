#!/usr/bin/env python3
import sys
import re

ZERO_CANDIDATE_MESSAGES = [
    "no candidate requirements were found in this transcript.",
    "no se encontraron requisitos candidatos en esta transcripción."
]

def validate(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error: Unable to read file {file_path}. Details: {e}")
        return False

    return validate_content(content, f"Validating req-discovery file: {file_path}")

def validate_stdin():
    try:
        content = sys.stdin.buffer.read().decode('utf-8')
    except Exception as e:
        print(f"Error: Unable to read content from stdin. Details: {e}")
        return False

    return validate_content(content, "Validating req-discovery content from stdin")

def validate_content(content, banner):
    print(banner)

    stripped_content = content.strip()

    # 1. Zero-Candidate Verification
    if stripped_content.lower() in ZERO_CANDIDATE_MESSAGES or stripped_content.lower().startswith("no candidate requirements were found") or stripped_content.lower().startswith("no se encontraron requisitos candidatos"):
        print("\nValidation successful! Output is a valid zero-candidate requirement response.")
        return True

    # 2. Candidate Requirement Blocks Verification
    parts = re.split(r'(?m)^###\s+', content)
    
    # If no ### headers found at all
    if len(parts) <= 1:
        print("\nValidation failed with the following errors:")
        print("  - Output contains no candidate requirement blocks ('### <title>') and does not match zero-candidate response message.")
        return False

    errors = []

    # Iterate over candidate blocks (parts[0] is preamble before first ###)
    for i, block in enumerate(parts[1:], start=1):
        lines = block.splitlines()
        if not lines:
            errors.append(f"Candidate block [{i}] is empty.")
            continue

        title = lines[0].strip()
        if not title:
            errors.append(f"Candidate block [{i}] missing title header.")

        block_identifier = f"'{title}'" if title else f"[{i}]"

        # Key-Value lines parsing
        fields = {}
        for line in lines[1:]:
            sline = line.strip()
            if not sline:
                continue
            
            kv_match = re.match(r'^\*\*([^*]+):\*\*\s*(.*)$', sline)
            if kv_match:
                key = kv_match.group(1).strip()
                val = kv_match.group(2).strip()
                fields[key] = val

        # Validate Story
        if 'Story' not in fields:
            errors.append(f"Candidate {block_identifier} is missing required field '**Story:**'.")
        else:
            story_val = fields['Story']
            story_pattern = r'^(?:As a|As an|Como)\s+.+,\s*(?:I want|quiero)\s+.+,\s*(?:so that|para|para poder)\s+.+$'
            if not re.match(story_pattern, story_val, re.IGNORECASE):
                errors.append(
                    f"Candidate {block_identifier} '**Story:**' field value '{story_val}' does not conform to user story format "
                    "('**Story:** As a ..., I want ..., so that ...' or '**Story:** Como ..., quiero ..., para ...')."
                )

        # Validate Context
        if 'Context' not in fields:
            errors.append(f"Candidate {block_identifier} is missing required field '**Context:**'.")
        elif not fields['Context']:
            errors.append(f"Candidate {block_identifier} '**Context:**' field cannot be empty.")

        # Validate Resolution
        if 'Resolution' not in fields:
            errors.append(f"Candidate {block_identifier} is missing required field '**Resolution:**'.")
        elif not fields['Resolution']:
            errors.append(f"Candidate {block_identifier} '**Resolution:**' field cannot be empty.")

        # Validate Confidence
        if 'Confidence' not in fields:
            errors.append(f"Candidate {block_identifier} is missing required field '**Confidence:**'.")
        elif fields['Confidence'].lower() not in ('explicit', 'implied'):
            errors.append(
                f"Candidate {block_identifier} '**Confidence:**' field value '{fields['Confidence']}' "
                "must be strictly 'explicit' or 'implied'."
            )

        # Validate Possible match if present
        if 'Possible match' in fields and not fields['Possible match']:
            errors.append(f"Candidate {block_identifier} '**Possible match:**' field is present but empty.")

        # Validate Hidden English Summary Comment
        comment_match = re.search(r"<!--\s*en-summary:\s*(.+?)\s*-->", block, re.DOTALL)
        if not comment_match or not comment_match.group(1).strip():
            errors.append(
                f"Candidate {block_identifier} is missing required hidden summary comment block ('<!-- en-summary: ... -->')."
            )

    if errors:
        print("\nValidation failed with the following errors:")
        for err in errors:
            print(f"  - {err}")
        return False

    print("\nValidation successful! All candidate requirement blocks conform to the output contract.")
    return True

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        success = validate(sys.argv[1])
    elif not sys.stdin.isatty():
        success = validate_stdin()
    else:
        print("Usage: python validate_req_discovery.py <path_to_markdown_file>")
        print("       or pipe content via stdin: cat file.md | python validate_req_discovery.py")
        sys.exit(1)

    sys.exit(0 if success else 1)

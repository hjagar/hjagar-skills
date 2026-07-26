#!/usr/bin/env python3
import sys
import re

def parse_yaml_block(yaml_text):
    data = {
        'id': None,
        'type': None,
        'breaking': None,
        'dependencies': [],
        'metadata': {},
        'scenarios': []
    }
    
    lines = yaml_text.splitlines()
    current_key = None
    current_scenario = None
    in_metadata = False
    in_scope = False
    in_scenarios = False
    
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
            
        indent = len(line) - len(line.lstrip())
        
        if indent == 0:
            in_metadata = False
            in_scope = False
            in_scenarios = False
            current_key = None
            
            if ':' in line:
                key, val = [x.strip() for x in line.split(':', 1)]
                if key == 'id':
                    data['id'] = val
                elif key == 'type':
                    data['type'] = val
                elif key == 'breaking':
                    data['breaking'] = val.lower() == 'true' if val.lower() in ['true', 'false'] else val
                elif key == 'dependencies':
                    if val.startswith('[') and val.endswith(']'):
                        deps_str = val[1:-1].strip()
                        data['dependencies'] = [x.strip() for x in deps_str.split(',') if x.strip()]
                    else:
                        current_key = 'dependencies'
                elif key == 'metadata':
                    in_metadata = True
                elif key == 'scenarios':
                    in_scenarios = True
            continue
            
        if current_key == 'dependencies' and indent > 0:
            if stripped.startswith('- '):
                dep_val = stripped[2:].strip()
                if (dep_val.startswith('"') and dep_val.endswith('"')) or (dep_val.startswith("'") and dep_val.endswith("'")):
                    dep_val = dep_val[1:-1]
                data['dependencies'].append(dep_val)
            continue
            
        if in_metadata and indent > 0:
            if indent == 2:
                in_scope = False
                if ':' in line:
                    key, val = [x.strip() for x in line.split(':', 1)]
                    if key == 'scope':
                        data['metadata']['scope'] = {}
                        in_scope = True
                    else:
                        if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                            val = val[1:-1]
                        data['metadata'][key] = val
            elif in_scope and indent == 4:
                if ':' in line:
                    key, val = [x.strip() for x in line.split(':', 1)]
                    data['metadata']['scope'][key] = val.lower() == 'true' if val.lower() in ['true', 'false'] else val
            continue
            
        if in_scenarios and indent > 0:
            if stripped.startswith('- '):
                rest = stripped[2:].strip()
                if rest.startswith('name:'):
                    name_val = rest.split(':', 1)[1].strip()
                    if (name_val.startswith('"') and name_val.endswith('"')) or (name_val.startswith("'") and name_val.endswith("'")):
                        name_val = name_val[1:-1]
                    current_scenario = {'name': name_val, 'given': None, 'when': None, 'then': None}
                    data['scenarios'].append(current_scenario)
            elif current_scenario is not None:
                if ':' in line:
                    key, val = [x.strip() for x in line.split(':', 1)]
                    if key in ['given', 'when', 'then']:
                        if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                            val = val[1:-1]
                        current_scenario[key] = val
            continue
            
    return data

def validate(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error: Unable to read file {file_path}. Details: {e}")
        return False

    return validate_content(content, f"Validating refinement file: {file_path}")


def validate_stdin():
    try:
        content = sys.stdin.buffer.read().decode('utf-8')
    except Exception as e:
        print(f"Error: Unable to read content from stdin. Details: {e}")
        return False

    return validate_content(content, "Validating refinement content from stdin")


def validate_content(content, banner):
    print(banner)

    # Extract the block starting with <!-- [AI-DATA] and ending with -->
    match = re.search(r"<!--\s*\[AI-DATA\]\s*\n(.*?)\n\s*-->", content, re.DOTALL)
    if not match:
        print("Error: Missing '<!-- [AI-DATA]' block in file.")
        return False
        
    yaml_text = match.group(1)
    
    try:
        data = parse_yaml_block(yaml_text)
    except Exception as e:
        print(f"Error parsing YAML block. Details: {e}")
        return False

    errors = []

    # 1. Validate ID
    if not data['id']:
        errors.append("Field 'id' is missing.")
    elif not re.match(r"^US-?\d+$", str(data['id'])):
        errors.append(f"Field 'id' value '{data['id']}' must match the pattern US-?\\d+.")

    # 2. Validate Type
    allowed_types = {'feat', 'fix', 'refactor', 'docs', 'chore'}
    if not data['type']:
        errors.append("Field 'type' is missing.")
    elif data['type'] not in allowed_types:
        errors.append(f"Field 'type' value '{data['type']}' must be one of {allowed_types}.")

    # 3. Validate Breaking
    if data['breaking'] is None:
        errors.append("Field 'breaking' is missing.")
    elif not isinstance(data['breaking'], bool):
        errors.append(f"Field 'breaking' value '{data['breaking']}' must be a boolean (true/false).")

    # 4. Validate Dependencies
    if not isinstance(data['dependencies'], list):
        errors.append("Field 'dependencies' must be a list.")
    else:
        for dep in data['dependencies']:
            if not re.match(r"^US-?\d+$", str(dep)):
                errors.append(f"Dependency '{dep}' must match the pattern US-?\\d+.")

    # 5. Validate Metadata
    metadata = data['metadata']
    required_meta_keys = {'scope', 'role', 'endpoint', 'auth', 'ui'}
    for key in required_meta_keys:
        if key not in metadata:
            errors.append(f"Metadata field '{key}' is missing.")
            
    if 'scope' in metadata:
        scope = metadata['scope']
        if not isinstance(scope, dict):
            errors.append("Metadata 'scope' must be a map.")
        else:
            for subkey in ['backend', 'frontend']:
                if subkey not in scope:
                    errors.append(f"Metadata 'scope' field is missing subkey '{subkey}'.")
                elif not isinstance(scope[subkey], bool):
                    errors.append(f"Metadata 'scope.{subkey}' must be a boolean (true/false).")

    for key in ['role', 'endpoint', 'auth', 'ui']:
        if key in metadata and (not metadata[key] or not isinstance(metadata[key], str)):
            errors.append(f"Metadata '{key}' must be a non-empty string.")

    # 6. Validate Scenarios
    scenarios = data['scenarios']
    if not isinstance(scenarios, list):
        errors.append("Field 'scenarios' must be a list.")
    elif len(scenarios) == 0:
        errors.append("List 'scenarios' must contain at least one scenario.")
    else:
        for i, sc in enumerate(scenarios):
            for step in ['name', 'given', 'when', 'then']:
                if step not in sc or not sc[step]:
                    errors.append(f"Scenario [{i}] is missing or has an empty '{step}' field.")

    if errors:
        print("\nValidation failed with the following errors:")
        for err in errors:
            print(f"  - {err}")
        return False
        
    print("\nValidation successful! AI-DATA block conforms to the schema.")
    return True

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        success = validate(sys.argv[1])
    elif not sys.stdin.isatty():
        success = validate_stdin()
    else:
        print("Usage: python validate_refinement.py <path_to_markdown_file>")
        print("       or pipe AI-DATA content via stdin: cat file.md | python validate_refinement.py")
        sys.exit(1)

    sys.exit(0 if success else 1)

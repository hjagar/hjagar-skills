#!/usr/bin/env python3
"""
Validator script for res-onboarding output documents.
Checks compliance with Hard Rules for both Senior Briefings and Junior Onboarding Guides.
"""

import sys
import re

def validate_content(content, banner="Validating onboarding document"):
    print(banner)

    if not content or not content.strip():
        print("Error: Document content is empty.")
        return False

    errors = []
    lines = content.splitlines()

    # 1. Heading check
    has_headers = any(line.strip().startswith('#') for line in lines)
    if not has_headers:
        errors.append("Document missing Markdown headings (# or ##).")

    content_lower = content.lower()

    # 2. Determine mode: Senior Briefing vs Junior Onboarding Guide
    is_senior = "senior" in content_lower or "briefing" in content_lower
    is_junior = "junior" in content_lower or "modo profesor" in content_lower or "profesor" in content_lower

    if not is_senior and not is_junior:
        # Default fallback check if not explicitly labeled
        is_senior = True

    if is_senior:
        # Check mandatory Senior Briefing sections
        required_senior_sections = [
            ("project map", ["project map", "domain", "resumen del proyecto", "mapa del proyecto"]),
            ("stack & commands", ["stack", "comandos", "commands"]),
            ("architecture", ["architecture", "arquitectura"]),
            ("conventions", ["conventions", "convenciones"]),
            ("gotchas", ["gotchas", "puntos de atención", "consideraciones"]),
            ("where to look", ["where to look", "dónde mirar", "donde mirar", "ubicación"])
        ]
        for section_name, keywords in required_senior_sections:
            found = any(kw in content_lower for kw in keywords)
            if not found:
                errors.append(f"Senior Briefing missing required section: '{section_name}'")

    if is_junior:
        # Check mandatory Junior Onboarding sections
        required_junior_sections = [
            ("task / context", ["task", "tarea", "context", "contexto", "problema"]),
            ("reflective questions / socratic check", ["preguntas", "questions", "¿qué", "socratic", "intentaste"]),
            ("escalation ladder / next steps", ["escalada", "ladder", "pasos", "next steps", "siguientes pasos"])
        ]
        for section_name, keywords in required_junior_sections:
            found = any(kw in content_lower for kw in keywords)
            if not found:
                errors.append(f"Junior Guide missing required section: '{section_name}'")

        # Hard Rule violation check: Direct full code block without reflective questions
        has_code_block = "```" in content
        has_question = any(q in content_lower for q in ["¿", "?", "intentaste", "entendés", "entendimiento"])
        if has_code_block and not has_question:
            errors.append("Hard Rule Violation: Full code provided to junior without reflective questions or Socratic check.")

    if errors:
        print("\nValidation failed with the following errors:")
        for err in errors:
            print(f"  - {err}")
        return False

    print("\nValidation successful! Onboarding document conforms to Hard Rules.")
    return True

def validate_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error: Unable to read file {file_path}. Details: {e}")
        return False
    return validate_content(content, f"Validating onboarding file: {file_path}")

def validate_stdin():
    try:
        content = sys.stdin.buffer.read().decode('utf-8')
    except Exception as e:
        print(f"Error: Unable to read content from stdin. Details: {e}")
        return False
    return validate_content(content, "Validating onboarding content from stdin")

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        success = validate_file(sys.argv[1])
    elif not sys.stdin.isatty():
        success = validate_stdin()
    else:
        print("Usage: python validate_onboarding.py <path_to_markdown_file>")
        print("       or pipe content via stdin: cat briefing.md | python validate_onboarding.py")
        sys.exit(1)

    sys.exit(0 if success else 1)

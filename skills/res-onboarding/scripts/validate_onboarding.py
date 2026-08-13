#!/usr/bin/env python3
"""
Validator script for res-onboarding output documents.
Checks compliance with Hard Rules for both Senior Briefings and Junior Onboarding Guides.
"""

import sys
import re

# Fixed senior track section IDs (references/persistence.md "Senior track section IDs").
SENIOR_SECTION_IDS = {
    "project-map", "stack-commands", "architecture",
    "conventions", "gotchas", "where-to-look",
}


def _section_block(content, heading_regex):
    """Return the text between a heading matching heading_regex and the next
    level-2 (##) heading, or None if the heading isn't present."""
    m = re.search(heading_regex, content, re.IGNORECASE)
    if not m:
        return None
    start = m.end()
    next_heading = re.search(r'\n##\s', content[start:])
    end = start + next_heading.start() if next_heading else len(content)
    return content[start:end]


def check_persistence(content, content_lower, errors):
    """Persistence checks per references/persistence.md (issue #32).

    Gated by the caller on presence of persistence markers, so ordinary
    senior briefings / junior guides without a persisted progress record
    are never affected by these checks.
    """
    has_stored_at = "Stored at:" in content

    senior_log_block = _section_block(content, r'##\s*Senior Track Log')
    junior_track_block = _section_block(content, r'##\s*Junior Track[^\n]*')

    senior_entries = []
    if senior_log_block is not None:
        senior_entries = re.findall(r'^-\s*\[[ xX]\]\s*(.+)$', senior_log_block, re.MULTILINE)

    junior_chapters = []
    if junior_track_block is not None:
        junior_chapters = re.findall(r'^###\s*Chapter:\s*(.+)$', junior_track_block, re.MULTILINE)

    # 1. Stored-at receipt present whenever progress was actually persisted.
    if (senior_entries or junior_chapters) and not has_stored_at:
        errors.append(
            "Persistence: progress was persisted (senior log entries or junior chapters present) "
            "but no 'Stored at: ...' receipt line was found (persistence.md 'Stored-At Receipt')."
        )

    # 2. Senior log entries must reference a fixed section ID, not free text.
    for entry in senior_entries:
        id_match = re.match(r'^([a-z0-9-]+)(?:\s|$)', entry.strip())
        entry_id = id_match.group(1) if id_match else None
        if not entry_id or entry_id not in SENIOR_SECTION_IDS:
            errors.append(
                f"Persistence: Senior Track Log entry '{entry.strip()}' does not start with one of the "
                f"fixed section IDs ({', '.join(sorted(SENIOR_SECTION_IDS))}); persistence.md requires "
                "structural section IDs, not a free-text description."
            )

    # 3. Junior chapters must be structured per topic, not a running log.
    if junior_track_block is not None:
        topics = [t.strip() for t in junior_chapters if t.strip()]
        if not topics:
            errors.append(
                "Persistence: Junior Track section has no '### Chapter: <topic>' headings; "
                "persistence.md requires the curriculum record to be structured as chapters keyed by topic."
            )
        elif len(set(topics)) != len(topics):
            errors.append(
                "Persistence: Junior Track has duplicate '### Chapter:' topics; each chapter must be "
                "distinguishable by topic, not collapsed into one running log."
            )

    # 5. Stop-mentoring marks the track inactive; it never deletes the record.
    stop_match = (
        re.search(r'stop(?:ped|s)?\b[^.\n]{0,60}\b(senior|junior)\b', content_lower)
        or re.search(r'\b(senior|junior)\b[^.\n]{0,60}\bstop(?:ped|s)?\b', content_lower)
    )
    if stop_match:
        track = stop_match.group(1)
        status_field = f"{track}_track_status"
        status_match = re.search(rf'{status_field}\s*:\s*(\S+)', content_lower)
        if not status_match or status_match.group(1) != "inactive":
            errors.append(
                f"Persistence: content indicates the {track} track was stopped, but no "
                f"'{status_field}: inactive' marker is present; persistence.md requires marking the "
                "track inactive, never deleting the record (see 'Stopping Mentoring')."
            )


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

    # Persistence checks (issue #32) — only when the document actually
    # carries a persisted progress record, so ordinary briefings/guides are unaffected.
    # NOTE: the session-start 3-way choice (persistence.md "Session Start Flow") is
    # deliberately NOT checked here — it's a runtime dialogue behavior, not a persisted
    # artifact, so a static markdown validator has no output to inspect for it.
    has_persistence_markers = bool(
        re.search(r'##\s*Senior Track Log', content, re.IGNORECASE)
        or re.search(r'##\s*Junior Track', content, re.IGNORECASE)
        or re.search(r'\bperson\s*:', content, re.IGNORECASE)
        or "Stored at:" in content
    )
    if has_persistence_markers:
        check_persistence(content, content_lower, errors)

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

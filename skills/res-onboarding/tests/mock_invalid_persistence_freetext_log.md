# Senior Briefing — Project Onboarding

## Project Map
This system handles user story refinement and skill management across multiple AI agent platforms.

## Stack & Commands
- Stack: Python 3.10+, Markdown, Shell/PowerShell CLI tools.
- Run tests: `python skills/res-onboarding/scripts/validate_onboarding.py`.

## Architecture
Monorepo containing shared CLI scripts in `cli/` and modular skills under `skills/`.

## Conventions
- Conventional commits only.
- Strict English default for code, instructions, and documentation artifacts.

## Gotchas
- Multi-skill installer scripts in `cli/` currently assume single-skill paths during Phase 3 migration.

## Where to Look
- Shared CLI functions: `cli/lib/skill-payload.sh`
- Skill definitions: `skills/<skill_name>/SKILL.md`

---
person: dana
level: senior
senior_track_status: active
last_session: 2026-08-13
---

## Senior Track Log

- [x] project-map — shown 2026-08-13
- [x] Explained how the CI release pipeline resolves skill tags — shown 2026-08-13

Stored at: .ai/dana/progress.md

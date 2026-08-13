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

# Junior Onboarding Guide — Modo Profesor

## Task / Context
Priya is picking up the billing chapter of the onboarding curriculum this session.

## Reflective Questions
- ¿Qué parte del flujo de JWT no te quedó clara todavía?

## Escalation Ladder / Next Steps
1. Try it yourself first.
2. Ask a peer if still stuck.
3. Escalate to the tech lead if the blocker persists.

---
person: priya
level: senior
senior_track_status: active
junior_track_status: inactive
last_session: 2026-08-13
---

## Senior Track Log

- [x] project-map — shown 2026-08-13
- [x] stack-commands — shown 2026-08-13
- [ ] architecture
- [ ] conventions
- [ ] gotchas
- [ ] where-to-look

## Junior Track — Mentor/Mentee Arc

Priya chose to stop the junior track mentoring this session; the record stays as reference in case it resumes later.

### Chapter: Authentication Flow
- status: in-progress
- stage: in-progress
- last_touched: 2026-08-13
- notes: Walked through the login handshake and open questions about JWT refresh.

### Chapter: Billing Integration
- status: not-started
- stage: new
- last_touched: 2026-08-13
- notes: Not started yet; next steps planned for a future session.

Stored at: .ai/priya/progress.md

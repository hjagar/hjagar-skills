---
name: res-onboarding
description: "Trigger: /onboarding, onboarding a un dev nuevo, arranca un junior/senior, guiar a alguien nuevo, guía de onboarding. Onboards a new developer (junior or senior) into a codebase."
license: MIT
metadata:
  author: hjagar
  version: "0.9.9"
---

## Activation Contract

Activate this skill when:
- The user types `/onboarding` (optionally with `[stage]` and/or `[level]`, e.g., `/onboarding junior`, `/onboarding new junior`, `/onboarding in-progress senior`).
- The user asks to onboard a developer (e.g., "onboarding a un dev nuevo", "arranca un junior/senior en el proyecto", "necesito guiar a alguien nuevo", "genera una guía de onboarding").
- A new collaborator introduces themselves at the start of a session implying they need project orientation.

## Hard Rules

1. **No Duplicate Documentation:** Never document what existing files or codebase patterns already make clear and consistent. Defer to existing project AI-instruction files (`CLAUDE.md`, `AI.md`, `AGENTS.md`, `core.md`, `.cursorrules`).
2. **AI-Instructions File Detection:** Always check root for an AI-instructions file first. If found, respect its philosophy and use it as authority. If missing, perform a minimal scan and produce non-obvious architecture rules/gotchas.
3. **Domain Context Preservation:** Reference existing domain-context docs (`docs/context/`, `docs/domain/`, README wiki) without re-summarizing. Never infer domain logic solely from code; ask the user or PO if absent.
4. **Explicit Level Resolution:** Resolve developer level in strict priority order: (1) CLI argument, (2) user/session context or `.ai/<name>/` progress file, (3) single clarification question, (4) default to `senior`.
5. **Explicit Stage Resolution:** Resolve project stage for junior developers in priority order: (1) CLI argument, (2) repository signals (commit history depth, domain docs, code maturity), (3) clarification question.
6. **Structured Output Delegation:** Delegate senior onboarding to `references/senior-briefing.md` and junior onboarding to `references/modo-profesor.md`.
7. **Language Matching:** Maintain skill instructions in English, but output all user-facing content (briefings, mentor dialogue, questions) in the user's active conversation language.
8. **Progress Persistence:** Persist both tracks' progress per `references/persistence.md` — senior track logs shown sections by ID, junior track persists the curriculum as distinct chapters. Never repeat a returning senior's already-shown sections or lose a junior's curriculum state without being told to.
9. **Continuation Consent:** For a returning user with a progress record, always offer explicitly to continue the senior track, continue the junior track/arc, or stop mentoring — never silently resume or silently restart.
10. **Stored-At Receipt:** Whenever a session persists progress, end the output with a `Stored at: ...` line naming the exact backend and location (Engram topic key or file path), per `references/persistence.md`.

## Decision Gates

| Situation | Action |
| --- | --- |
| AI-instructions file exists (`CLAUDE.md`, `AI.md`, etc.) | Read and defer to its philosophy and conventions |
| AI-instructions file missing | Scan repo for non-obvious rules, gotchas, and build minimal context |
| Domain-context folder/doc exists (`docs/context/`, etc.) | Reference external doc; do not duplicate domain text |
| Domain-context doc missing | Ask user/PO for domain summary; do not infer domain from code |
| Target audience is Senior (`level = senior`) | Apply `references/senior-briefing.md` (stage choice ignored) |
| Target audience is Junior (`level = junior`) | Apply `references/modo-profesor.md` (branches on `stage`) |
| Engram MCP server active | Persist progress as an Engram memory (`res-onboarding/<name>` topic) per `references/persistence.md` |
| Engram MCP server inactive | Persist progress to `.ai/<name>/progress.md` per `references/persistence.md` |
| Returning user has a progress record | Offer to continue senior track, continue junior track/arc, or stop mentoring — don't resume silently |
| No progress record exists for this person | Start from a blank log/curriculum, no error |
| User chooses to stop mentoring | Mark that track's record `inactive`; never delete it |

## Execution Steps

1. **Parse Arguments & Context:** Extract `stage` (`new` | `in-progress`) and `level` (`junior` | `senior`) from command `/onboarding [stage] [level]` or prompt text.
2. **Resolve Progress Record:** Resolve the person's identity and look up their progress record per `references/persistence.md` (Engram topic, else `.ai/<name>/progress.md`). No record → start blank. Record found → offer continue senior track, continue junior/arc, or stop mentoring.
3. **Inspect Existing Instructions:** Scan root for `CLAUDE.md`, `AI.md`, `AGENTS.md`, `core.md`, `.cursorrules`. Extract architectural rules and non-obvious gotchas.
4. **Inspect Business Domain:** Check for `docs/context/`, `docs/domain/`, or README links. If missing, prompt for domain overview if required.
5. **Resolve Level & Stage:** Apply priority rules to determine developer level and project stage.
6. **Generate Briefing Output:** Produce senior briefing via `references/senior-briefing.md` (skipping sections already logged as shown) or junior mentor guidance via `references/modo-profesor.md`.
7. **Persist Progress:** At session end, write the shown senior sections or updated junior chapter back to the progress record per `references/persistence.md`, unless the user opted to stop mentoring (in which case mark the track inactive instead).

## Output Contract

Return:
- Structured onboarding briefing or mentor dialogue matching the resolved level and stage.
- Explicit references to existing project instruction files and domain documentation.
- Non-obvious architectural patterns, command references, and gotchas not evident from single-file reads.
- When progress was persisted this session, a closing `Stored at: ...` line naming the exact backend and location (per `references/persistence.md`).

## References

- `references/senior-briefing.md` — Detailed structure and guidelines for Senior/SSR onboarding briefings.
- `references/modo-profesor.md` — Pedagogical framework, teaching rules, and escalation ladder for Junior onboarding.
- `references/persistence.md` — Storage-mode hierarchy, progress record schema, and session start/end persistence flow for both tracks.

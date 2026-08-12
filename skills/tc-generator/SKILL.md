---
name: tc-generator
description: "Trigger: /tc, /test-cases, 'generar casos de test', 'armar un checklist de QA'. Generates unit test suggestions and QA manual checklists for stories, specs, or code."
license: MIT
metadata:
  author: hjagar
  version: "1.0.0"
---

## Activation Contract

Activate this skill when:
- The user types `/tc` or `/test-cases` (optionally with source path or story ID).
- The user asks to "generar casos de test", "armar un checklist de QA", "qué debería testear en esta historia", or "no se me ocurren los edge cases".
- Test case guidance or QA checklists are requested for a story, feature, spec, or code context.

## Hard Rules

1. **Language Matching:** Always respond to the user in the language of the conversation, regardless of skill instruction language.
2. **Default Audience Mode:** Always default to Personal mode (fast, actionable checklist for the author) unless context explicitly specifies Team mode.
3. **Source Detection Priority:** Detect source context in strict priority order: (1) SDD spec (`/sdd-new`), (2) Acceptance criteria / `AI-DATA` block (`us-refinement`), (3) Raw code scan.
4. **Confidence Tagging:** Output MUST include an explicit confidence tag: `high` when derived from spec or AC; `low` when inferred from code alone (and low-confidence outputs MUST include "requires human review").
5. **Track A Exclusion:** Track A (Unit test suggestions) MUST NOT be generated if unit tests already exist for the target code. Only generate Track A when code exists without accompanying tests.
6. **Track B Structuring:** Track B (QA manual checklist) MUST structure every test case with: Precondition, Numbered steps, and Expected result. Cases MUST be grouped into `Happy path`, `Edge cases`, and `Negative/error cases`.
7. **Output File Format:** Personal mode output MUST be written to a single markdown file named `test-cases-<id-or-slug>.md` containing the confidence tag and applicable tracks. No GitHub write-back in Personal mode.

## Decision Gates

| Situation | Action |
| --- | --- |
| Source is SDD spec | Parse spec requirements and acceptance scenarios; set Confidence: high |
| Source is AC / `AI-DATA` | Parse Given/When/Then scenarios; set Confidence: high |
| Source is Raw Code | Scan functions, branches, boundaries; set Confidence: low ("requires human review") |
| Mode is Personal (default) | Write single markdown file `test-cases-<id-or-slug>.md`; skip GitHub write-back |
| Mode is Team | Apply `references/team-mode.md` conventions |
| Unit tests already exist | Omit Track A; generate Track B only |
| Code has no unit tests | Generate Track A (Unit suggestions) and Track B (QA checklist) |

## Execution Steps

1. **Audience Mode Resolution:** Determine mode (Personal vs Team). Default to Personal unless explicit signal for Team.
2. **Source Context Detection:** Inspect workspace/inputs in priority order: SDD spec -> AC / `AI-DATA` -> Code scan. Assign confidence tag (`high` or `low`).
3. **Track Determination & Generation:**
   - Check if unit tests exist for target code. If absent, generate **Track A** (Unit test suggestions matching project test framework if detectable).
   - Generate **Track B** (QA manual checklist structured with Precondition, Steps, Expected Result grouped into Happy path / Edge cases / Negative cases).
4. **Output File Writing:** Write `test-cases-<id-or-slug>.md` per Output Contract (or team format if Team mode).

## Output Contract

Return:
- File `test-cases-<id-or-slug>.md` containing:
  - Metadata header with Confidence Tag (`high` or `low`).
  - Track A (Unit test suggestions) — only if unit tests were missing.
  - Track B (QA manual checklist) — grouped by Happy path, Edge cases, Negative/error cases.
- Summary confirmation of generated file and detected source context.
- A `Stored at:` receipt line naming the exact file path written, e.g. `Stored at: test-cases-<id-or-slug>.md`.

## References

- `references/team-mode.md` — Formatting, structure, and storage rules when audience is Team mode.

---
name: us-refinement
description: "Trigger: /refine, /refinar, pasted As a/Como... stories, or GitHub issue refinement. Refines a raw user story into an INVEST-checked spec with Given/When/Then acceptance criteria before technical design or /sdd-new."
license: MIT
metadata:
  author: hjagar
  version: "1.4.0"
---

## Activation Contract

Activate this skill when:
- The user types `/refine` or `/refinar` (optionally with `--deep`, issue number, or draft).
- The user pastes an agile user story draft (`As a ...`, `Como ...`).
- The user references a GitHub issue for refinement (e.g., "refinar la issue #123").
- The user asks if a story is "ready for dev" or mentions acceptance criteria / INVEST refinement.

## Hard Rules

- **Language Matching:** Always respond to the user in the language of the conversation, regardless of skill instruction language.
- **No Implementation Code:** The refined story MUST NOT contain code blocks, scripts, function signatures, or file paths. Focus strictly on business requirements.
- **Folder Creation Confirmation:** Never create `openspec/changes/US{n}-{slug}/` silently. Ask for explicit user confirmation first.
- **Non-Blocking Gates:** Storage mode selection and clarification questions are flexible gates. If the user skips or says "go ahead", proceed without blocking.
- **Unchecked Assumptions:** Unresolved questions MUST be rendered as unchecked checkboxes (`- [ ]`) under `### Assumptions`. Never check them automatically.
- **No Automatic /sdd-new:** This skill NEVER invokes `/sdd-new` or generates technical designs on its own.

## Decision Gates

| Situation | Action |
| --- | --- |
| Source is GitHub Issue | Fetch issue via `gh issue view <num> --json title,body,url,labels,comments` |
| Source is Pasted Text | Parse story draft directly |
| Engram Active | Prompt storage mode (`engram` default, `openspec`, `hybrid`, `hybrid-delayed`); proceed if skipped |
| Engram Inactive | Use `openspec` if `.agents/` or `openspec/` exists, else console output |
| Standard Mode | Skip system PATH / file scans |
| Deep Mode (`--deep`) | Scan system PATH for tools and workspace for mentioned components |

## Execution Steps

1. **Source & Storage Setup:** Detect story source (Pasted vs GitHub). Determine storage mode per `references/storage-modes.md`.
2. **INVEST & Scope Analysis:** Evaluate story against INVEST criteria per `references/invest-criteria.md`. Flag multi-feature scope split warnings if needed.
3. **Clarification Check:** Group missing items into Acceptance Criteria, Dependencies, Scope, Edge Cases, Feasibility. Present questions with "skip/go ahead" option.
4. **Generate Refined Story:** Build refined story per `assets/story-template.md`. Save to Engram and/or write to `openspec/changes/US{n}-{slug}/story.md` per `references/storage-modes.md`.
5. **GitHub Write-Back:** If source was GitHub issue, offer comment or body update per `references/github-writeback.md`.
6. **Closing:** Offer SDD next steps (`/sdd-new`) or story splitting options.

## Output Contract

Return:
- Refined story output conforming to `assets/story-template.md`.
- Storage persistence confirmation (`Engram` memory record and/or `openspec/` file path).
- Optional GitHub write-back status and label updates.

## References

- `assets/story-template.md` — Canonical user story Markdown template and `AI-DATA` schema.
- `references/storage-modes.md` — Storage setup, Engram integration, and local persistence rules.
- `references/github-writeback.md` — GitHub CLI write-back commands, label handling, and fallback guidance.
- `references/invest-criteria.md` — Detailed INVEST evaluation, scope splitting, and `--deep` feasibility scan rules.

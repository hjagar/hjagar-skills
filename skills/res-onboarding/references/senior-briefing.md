# Senior/SSR Briefing

No pedagogy, no Socratic gating. The goal is dense, fast context transfer — treat it like handing a competent hire the notes they'd otherwise have to extract by asking around for two weeks.

## Structure

1. **Project map** — what the system does, one paragraph. Pull from the domain-context doc if one exists; otherwise state that domain context wasn't found and should come from a PO/team member.
2. **Stack & commands** — languages/frameworks, and the actual commands to run dev server, tests, lint, type-check, single-test runs.
3. **Architecture** — request lifecycle, how layout/routing is assigned, where shared state lives, anything structurally non-obvious.
4. **Conventions that aren't visible in a single file read** — team-specific rules the code doesn't self-explain: PR process and default reviewer, non-standard patterns (e.g. "no soft deletes, use an explicit `activo` flag"), UI conventions (formatting, component reuse rules), anything explicitly called out in the project's AI-instructions file as "the code doesn't show this."
5. **Gotchas** — things that look like they should work a certain way but don't (a CLI that silently uses the wrong package manager, a generated folder that must never be hand-edited, etc.).
6. **Where to look** — mapping of "if you need to understand X, look at Y" for the main domains of the codebase.

## What NOT to include

- Anything the code already makes obvious on a normal read-through — a senior will find that themselves faster than reading it here.
- Pedagogical framing, encouragement, or step-by-step teaching language.
- Full reproduction of the domain-context doc — link/reference it instead.

## If the project is `new`

Keep the same structure, just shorter — mostly stack, commands, and whatever direction/roadmap exists. Flag explicitly what's still undecided so the senior knows where their judgment is needed rather than assuming precedent exists.

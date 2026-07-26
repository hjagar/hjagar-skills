---
name: res-onboarding
description: Onboards a new developer — junior or senior — into a codebase, whether the project is brand-new or already in progress. Trigger this skill whenever the user invokes /onboarding, or asks things like "onboarding a un dev nuevo", "arranca un junior/senior en el proyecto", "necesito guiar a alguien nuevo en el equipo", "genera una guía de onboarding". Also trigger when a new collaborator introduces themselves at the start of a session in a way that implies they need project orientation.
---

# Onboarding

Onboards a developer into a project by combining two things the project may or may not already have (an AI-instructions file, a domain-context folder) with two decisions about the person joining (experience level, project maturity).

**Core principle — do not duplicate what already exists.** Before generating anything, check whether the project already documents it. Never write down what the code already demonstrates clearly and consistently; only write what the code does NOT yet make evident. If the project already has an AI-instructions file that states this same philosophy, defer to it instead of re-deriving your own summary.

## Command

```
/onboarding [stage] [level]
```

- `stage`: `new` | `in-progress` (optional)
- `level`: `junior` | `senior` (optional)

Examples: `/onboarding`, `/onboarding junior`, `/onboarding new junior`, `/onboarding in-progress senior`.

## Step 0 — Detect an existing AI-instructions file

Look for `CLAUDE.md`, `AI.md`, `AGENTS.md`, `core.md`, `.cursorrules`, or similar at the project root.

- **Found** → read it. Respect its stated philosophy (e.g. "keep this minimal, the code is the documentation"). Use it as your source for architecture/commands/conventions instead of re-scanning and regenerating that content.
- **Not found** → scan the repo yourself (package manager files, test framework, lint config, folder structure, routing pattern) and build a minimal equivalent. Keep it to what the code does not already make obvious: non-obvious architectural decisions, gotchas, team-specific rules (PR conventions, reviewer defaults, naming rules).

## Step 1 — Detect domain/business context

Look for a domain-context folder or doc (e.g. `docs/context/`, `docs/domain/`, a wiki link in the README).

- **Found** → reference it, don't summarize or duplicate it into your own output.
- **Not found** → don't infer the business domain from code alone. Ask the user (or point out that a PO/team member should provide it) for a short domain summary, or proceed without it if the person only needs technical onboarding.

## Step 2 — Resolve the level gate (junior | senior)

Resolve in this order, stopping at the first that resolves:
1. Explicit `level` param.
2. If you already have context on who this person is (prior sessions, a progress file under `.ai/<name>/`, something the user told you this session) → infer from that.
3. Ask once: "¿Con qué nivel de experiencia arranca — junior o senior?"
4. If still unresolved → default to **senior**.

## Step 3 — Resolve the stage gate (new | in-progress) — only matters if level = junior

Senior mode doesn't branch on project maturity — a senior gets a briefing either way, just shorter if there's less to brief. Junior mode does branch, because it changes what the mentor can point to.

Resolve in this order:
1. Explicit `stage` param.
2. Infer from repo signals: commit count/history depth, whether `docs/context/` (or equivalent) has real content, whether there are existing features in the same domain the newcomer's first task touches. Low signal on all of these → `new`. Established code and conventions → `in-progress`.
3. If ambiguous → ask: "¿El proyecto ya tiene features/convenciones establecidas, o está recién arrancando?"

## Step 4 — Generate the right output

- **Senior** (any stage) → follow `references/senior-briefing.md`.
- **Junior** → follow `references/modo-profesor.md`. It branches internally on `stage`.

## Language

Write this file's own instructions in English for model comprehension, but all output shown to the user (the briefing, the mentor dialogue, questions) must be in the user's language.

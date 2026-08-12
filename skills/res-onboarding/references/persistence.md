# Persistence — Onboarding & Mentoring Progress

Both tracks (senior briefing log, junior mentoring arc) persist across sessions so neither repeats itself or loses state. This reference defines the storage-mode hierarchy, the progress record schema, and the session-start/session-end flow. It follows the same backend-priority pattern as `us-refinement` (`references/storage-modes.md`) and `req-discovery` (HR-10/HR-11): **highest available backend wins, never fail a run because a backend is missing.**

## Storage Mode Resolution

1. **If Engram MCP server is ACTIVE**: persist progress as an Engram memory under topic key `res-onboarding/<name>` (one topic per person, both tracks inside it as structured observations). No local file required.
2. **If Engram MCP server is INACTIVE**: fall back to a markdown file at `.ai/<name>/progress.md` (this is the same path Hard Rule 4 in `SKILL.md` already reads to resolve a returning user's level — persistence formalizes what that rule assumed).
   - If `.ai/<name>/` does not exist, create it without asking — this is per-person local state, not a shared project artifact, so it doesn't need the confirm-before-create gate that `us-refinement` uses for `openspec/changes/`.
3. Never fail an onboarding/mentoring session because neither backend is reachable — if the markdown write itself fails (permissions, read-only fs), degrade to printing the progress summary in the response and say so explicitly instead of silently losing it.

`<name>` is the person's identifier as given at session start (their name or handle) — slugify it (lowercase, `-` for spaces) for the filesystem path.

## Progress Record Schema

One record per person, holding both tracks (a person can be senior-track and junior-track over time — e.g., promoted). Markdown form:

```markdown
---
person: <name>
level: senior | junior
senior_track_status: active | inactive | not-started
junior_track_status: active | inactive | not-started
last_session: <ISO date>
---

## Senior Track Log

Sections already shown, by ID (see below) — not a free-text summary:

- [x] project-map — shown 2026-08-12
- [x] stack-commands — shown 2026-08-12
- [ ] architecture
- [ ] conventions
- [ ] gotchas
- [ ] where-to-look

## Junior Track — Mentor/Mentee Arc

Ongoing curriculum, one chapter per topic. Each chapter is distinct — don't collapse them into one running log.

### Chapter: <topic name>
- status: not-started | in-progress | mastered
- stage: new | in-progress
- last_touched: <ISO date>
- notes: one line per session — what was worked, what was decided, what's left half-understood. Task status does NOT go here (issue tracker owns that).

### Chapter: <next topic>
...
```

### Senior track section IDs

Fixed to the six sections defined in `references/senior-briefing.md`, so logging is structural, not prose:

`project-map` · `stack-commands` · `architecture` · `conventions` · `gotchas` · `where-to-look`

When a section is (re-)presented in a session, mark it shown with the session date. A future session reads this log first and skips sections already marked shown, unless the user explicitly asks to revisit one.

### Junior track chapters

Chapters are curriculum topics the mentor builds from what it knows about the codebase (main domains, architecture layers, conventions) — not fixed IDs like the senior track, since the curriculum is generated per-project. Each chapter tracks its own mastery independently; finishing one doesn't affect another's status.

## Session Start Flow

1. Resolve the person (`<name>`) the same way level is resolved (Hard Rule 4).
2. Look up their progress record (Engram topic, else `.ai/<name>/progress.md`).
3. **No record found** — start from a blank log/curriculum. Do not treat this as an error; proceed as a first session.
4. **Record found, track(s) active** — offer explicitly: continue the senior track, continue the junior track/arc, or stop mentoring. Don't just resume silently — the user chooses.
5. **Record found, track inactive** — mention it's on hold as reference; ask if they want to reactivate it or start fresh.

## Stopping Mentoring

When the user chooses to stop (either track):
- Set that track's status to `inactive` in the record.
- Keep the record — never delete it. It stays as reference (what was covered, what chapter the junior arc was on) in case mentoring resumes later.

## Session End — What Gets Persisted

- **Senior track**: mark every section actually shown this session in the Senior Track Log, by section ID, with the session date.
- **Junior track**: update the current chapter's `status`, `last_touched`, and one line of session notes. Add a new `### Chapter:` block if this session opened a new curriculum topic.
- Write happens at session end (or when the session is explicitly wrapped up) — not per-message, to avoid noisy partial writes.

## Stored-At Receipt

After persisting, state where it went, matching the pattern every other skill's Output Contract uses (see #25):
- Engram: `Stored at: Engram topic_key res-onboarding/<name>`
- Markdown fallback: `Stored at: .ai/<name>/progress.md`

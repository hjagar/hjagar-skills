# Storage Modes & Local Persistence Reference

## Environment & Storage Setup

Before refinement analysis, check available tools and select storage mode:

1. **If Engram MCP server is ACTIVE**:
   Prompt the user to select preferred storage mode (default: `engram`):
   - `engram`: Memory-only in Engram SQLite DB, no local files created.
   - `openspec`: Local files under `openspec/changes/US{n}-{slug}/story.md`.
   - `hybrid`: Save to Engram memory AND local file in real time.
   - `hybrid-delayed`: Local file for visualization during session, save to Engram at session close.

   *Flexible Gate:* If the user says "go ahead", "skip it", or doesn't pick, proceed with `engram`.

2. **If Engram MCP server is INACTIVE**:
   Check if workspace has active SDD structure (`.agents/` or `openspec/`).
   - If yes: default to `openspec`.
   - If no: default to standard console log output.

## Local File Persistence Rules (`openspec`, `hybrid`, `hybrid-delayed`)

- Target file path: `openspec/changes/US{n}-{slug}/story.md`.
- **If folder `openspec/changes/US{n}-{slug}/` does NOT exist**:
  Warn the user and ask for explicit confirmation before creating it.
  - If user confirms: create folder and write `story.md`.
  - If user declines/fails: fall back to printing refined story via console log.
- **If folder already exists**:
  Write directly to `story.md` without asking again.

## Post-Refinement Validation Hint

If local file was written (`openspec`, `hybrid`, `hybrid-delayed`), append tip:
```markdown
> [!TIP]
> You can run `python scripts/validate_refinement.py <path-to-file>` to validate this story's AI-DATA block against the schema.
```
If mode is `engram` (memory-only), omit this hint.

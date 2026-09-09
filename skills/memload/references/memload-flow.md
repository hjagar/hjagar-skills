# Memload Flow — Implementation Detail

Detailed command sequence backing `SKILL.md`'s Execution Steps. `engram` here is the standalone `engram` CLI (`engram sync`, not the `gentle-ai` CLI, which has no memory subcommand).

## 1. Pending-State Check

```bash
engram sync --status
```

Capture the reported local vs. pending/remote chunk counts before importing. This is the baseline used to detect whether `--import` actually did anything, and to phrase the report in step 3.

## 2. Import

```bash
engram sync --import
```

- Idempotent: running it with nothing new to pull does not error, it just reports (or silently confirms) nothing changed.
- Its own stdout/stderr is the primary source of truth for what was imported (chunk count, observation count) — prefer relaying that directly over re-deriving it.
- If the command's output reports memory conflicts, do not interpret or resolve them (Hard Rule 2 of `SKILL.md`) — surface that output to the user exactly as printed.

## 3. Report

- If step 2's own output states counts imported → report those directly (e.g. "Imported 3 chunks / 47 observations").
- If step 2's output doesn't state counts clearly, re-run `engram sync --status` and diff the local chunk count against step 1's baseline to report the delta.
- If step 1 and step 2 both show no change → report explicitly that there was nothing new to import (Hard Rule 3). No further action.
- If conflicts were surfaced in step 2 → include that output verbatim in the report, without adding independent conflict guidance.

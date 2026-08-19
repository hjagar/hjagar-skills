---
name: req-discovery
description: "Trigger: user pastes a transcript or a single-author note/brain-dump, references a meeting, or asks to extract requirements or draft stories from a conversation or personal notes. Drafts raw user stories for us-refinement."
license: MIT
metadata:
  author: hjagar
  version: "1.1.9"
---

# req-discovery

## Activation Contract
- **Trigger**: User pastes a meeting transcript or a single-author note/brain-dump, references a meeting, or asks to extract requirements / draft user stories from a conversation or personal notes.
- **Role**: Surface requirement-shaped signals from transcripts or single-author notes as raw draft user stories. Story refinement (INVEST, Given/When/Then, IDs) is handled downstream by `us-refinement`.
- **Input**: Plain text transcript or single-author note/brain-dump (file path or pasted). Text only (no audio).

## Hard Rules
- **HR-1**: Text input only. If audio is provided, notify user and stop immediately (speech-to-text handled upstream).
- **HR-2**: Do not invent acceptance criteria, technical approach, or unstated scope.
- **HR-3**: Do not refine stories into INVEST format or Given/When/Then scenarios (`us-refinement` responsibility).
- **HR-4**: Do not assign `US-{issue_number}` IDs (assigned downstream on issue creation).
- **HR-5**: Language contract — output fields (`title`, `story`, `context`, `resolution`, `confidence`, `Possible match`, zero-candidate message, wrappers) MUST mirror transcript language. Preserve anglicisms ("mergear", "deploy").
- **HR-6**: Append a hidden English summary comment (`<!-- en-summary: ... -->`) per candidate block (1 line prose, no schema).
- **HR-7**: Segment long transcripts (~400 lines) sequentially at natural boundaries (~100 lines overlap) preserving traceability index.
- **HR-8**: Cross-meeting dedup — run read-only check against rejected/approved corpus. Add conditional `Possible match`; never auto-classify, merge, or delete.
- **HR-9**: Zero-candidate result — if no signals found, return exactly `"No candidate requirements were found in this transcript."` in transcript language.
- **HR-10**: Rejection storage — set-aside candidates MUST persist to Engram or dual fallback files (`openspec/req-discovery-rejected/index.md` & `{NN}-{slug}.md`). Every persisted set-aside candidate MUST be followed by a `Stored at:` line naming the exact backend and location (Engram topic key, or the two file paths written).
- **HR-11**: Graceful degrade + honest coverage — fallback gracefully if backends missing; disclose when approved-tier history coverage is limited.

> **Backend Priority Pattern**: Highest available backend wins (Engram > local OpenSpec > Markdown). Never fail run if missing.

## Decision Gates

| Gate | Check | Action |
|------|-------|--------|
| **Input Format** | Audio provided? | **STOP**. Report speech-to-text must be done upstream. |
| **Source Detection** | Multi-speaker structure present (speaker labels, timestamps, dialogue turns)? | Present -> **transcript mode** (unchanged). Absent -> **prompt mode**. Ambiguous -> ask once, non-blocking; proceed in transcript mode if unanswered. |
| **Signal Detection** | 0 signals? | Output "No candidate requirements were found in this transcript." and **STOP**. |
| **Dedup Check** | Corpus match? | Attach `Possible match` line. Do NOT alter candidate list. |
| **User Review** | Approved? | Include in Hand-off list for `us-refinement`. |
| **User Review** | Set-aside? | Persist to rejection storage (Engram / OpenSpec) with reason, then emit `Stored at:` receipt. |

## Execution Steps

1. **Detect Environment**: Check `gh` CLI, Engram, OpenSpec availability. Fallback to Markdown if missing.
2. **Scan Transcript**: Search for requirement signals. For transcripts > 400 lines, scan in overlapping (~100 lines) sequential segments.
3. **Cluster & Draft**: Group repeated mentions into candidate stories (`title`, `story`, `context`, `resolution`, `confidence`). Run read-only dedup check against corpus (`Possible match` if found). Append hidden `<!-- en-summary: ... -->` comment.
4. **Present Candidates**: Display candidate list in transcript language for user approval.
5. **Hand-off / Set-Aside**:
   - Approved -> Output clean list formatted for `us-refinement`.
   - Set-aside -> Persist to rejection storage ([rejection-index-template](assets/rejection-index-template.md) & [rejection-record-template](assets/rejection-record-template.md)).

## Output Contract

```markdown
### <title>
**Story:** As a ..., I want ..., so that ...
**Context:** <paraphrase, speaker, timestamp if known>
**Resolution:** <note if topic revisited; last position wins>
**Confidence:** explicit | implied
**Possible match:** <ONLY when dedup check found match>

<!-- en-summary: <English prose recap> -->
```

Two fields change wording by mode (per Source Detection gate); every other field is identical in both modes:
- **Context** — transcript mode: `<paraphrase, speaker, timestamp if known>`. Prompt mode: `<paraphrase of the note>` (no speaker or timestamp reference).
- **Resolution** — transcript mode: `<note if topic revisited; last position wins>`. Prompt mode: `<note if topic revisited within the same note; latest wording wins>` (no speaker framing).

Hand-off output contains approved candidate stories ready to paste into `us-refinement`.

If any candidate was set aside and persisted (HR-10), append one `Stored at:` line per candidate:
- Engram available: `Stored at: Engram topic_key <topic-key-used>`.
- Engram unavailable (dual-file fallback): `Stored at: openspec/req-discovery-rejected/index.md + openspec/req-discovery-rejected/{NN}-{slug}.md`.

## References
- [Rejection Storage Index Template](assets/rejection-index-template.md)
- [Rejection Storage Record Template](assets/rejection-record-template.md)

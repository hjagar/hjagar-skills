# GitHub Issue Write-Back & Label Management Reference

When the story source is a GitHub Issue (Step 0B):

## 1. Temporary File Bridge

Write the refined story output to a temporary scratch file first (`<refined-story-file>`), regardless of storage mode. `--body-file` requires a real file path.

## 2. Execution Choice

Check `gh` CLI availability and authentication (`gh auth status` and remote URL).
Ask the user for explicit choice before writing to GitHub:

- **Option A: Comment (Default, non-destructive)**
  ```bash
  gh issue comment <number> --body-file <refined-story-file>
  ```
- **Option B: Replace issue description**
  ```bash
  gh issue edit <number> --body-file <refined-story-file>
  ```

## 3. Post-Write Label Management

On command success, delete `<refined-story-file>`. Then inspect the refined text:

- **If output contains `### Assumptions` with at least 1 unchecked checkbox (`- [ ]`)**:
  Apply label `needs-review-assumptions`:
  ```bash
  gh label create needs-review-assumptions --color FBCA04 --description "Issue has pending assumptions that need business review" --force
  gh issue edit <number> --add-label "needs-review-assumptions"
  ```
- **If output has no `### Assumptions` or no unchecked checkboxes**:
  Remove label `needs-review-assumptions`:
  ```bash
  gh issue edit <number> --remove-label "needs-review-assumptions"
  ```

## 4. Fallback on Failure or Missing `gh`

If `gh` is unavailable, unauthenticated, or execution fails, keep `<refined-story-file>` on disk and instruct the user to copy content into GitHub manually.

# INVEST Criteria & Feasibility Scan Reference

## 1. INVEST Criteria Evaluation

Analyze the raw user story across these 6 axes:

- **Independent:** Does it depend on another unresolved story?
- **Negotiable:** Is it over-specified (dictates code implementation) or under-specified (says nothing)?
- **Valuable:** Is value to the user/business explicit in "So that"?
- **Estimable:** Is there sufficient information to estimate effort?
- **Small:** Is it scoped to a reasonable cycle, or should it be split?
- **Testable:** Can "done" be objectively verified with Given/When/Then scenarios?

### Multi-Feature Scope Pre-Check
If the story describes 2+ independent, separately shippable features (Small violation), warn the user before proceeding and offer to split into separate stories. If the user prefers to refine it whole, respect that choice.

---

## 2. Technical Feasibility Scan (Deep Mode `--deep` Only)

Runs ONLY when `--deep` flag is explicitly provided (e.g. `/refine --deep` or `/refinar --deep 81`). In Standard Mode, skip all shell commands.

1. **Tool Dependency Scan:**
   - Extract tool names mentioned in text (e.g., `Docker`, `Python`, `gh`, `unzip`, `shellcheck`, `winget`).
   - Validate each name against safe pattern `^[\w.-]+$`.
   - Run system check (`where <tool>` on Windows, `command -v <tool>` on Unix). Record warning if missing.

2. **Codebase Component Scan:**
   - Scan for referenced files/components (e.g. `installer`, `validator`).
   - Search repository for matching files. If multiple or zero matches found, flag for clarification in Step 2.

3. **Standard Mode Contextual Tip:**
   If running in Standard Mode (no `--deep`) and raw story mentions external tools/files, append tip:
   ```markdown
   > [!TIP]
   > This story mentions external tools or files. You can run `/refine --deep` to scan system PATH and workspace for technical feasibility.
   ```

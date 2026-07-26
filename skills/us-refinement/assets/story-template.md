# Refined User Story Template & Schema

Use this canonical format for generating refined user stories.

## Output Structure

```markdown
## [Story title]

**As a** [role]
**I want** [action]
**So that** [value/benefit]

### Acceptance criteria

**Scenario 1: [scenario name]**
- Given [initial context]
- When [user/system action]
- Then [expected result]

**Scenario 2: [unhappy path / edge case]**
- Given ...
- When ...
- Then ...

### Dependencies
- [List of stories, services, or prior data required, or "None identified"]
- [WARNING: Any missing tool warnings discovered in Step 1.5]

### Assumptions
- [ ] [First unconfirmed assumption / skipped question mapping]
- [ ] [Second unconfirmed assumption / skipped question mapping]

<!-- [AI-DATA]
id: [US-{issue_number} if sourced from GitHub, e.g. US-24, OR US{number} if sourced from pasted text, e.g. US12]
type: [feat|fix|refactor|docs|chore]
breaking: [true|false]
dependencies: [list of referenced story IDs, e.g. [US-24, US1] or []]
metadata:
  scope:
    backend: [true|false]
    frontend: [true|false]
  role: "[role name]"
  endpoint: "[HTTP method + route, or 'none']"
  auth: "[auth policy, or 'none']"
  ui: "[page|modal|form|action|none]"
scenarios:
  - name: "[Scenario 1 name]"
    given: "[preconditions in English]"
    when: "[actions in English]"
    then: "[expected outcomes in English]"
-->
```

## Schema & Formatting Rules

1. **Separation of Concerns:** Never include code blocks, implementation scripts, function signatures, or folder paths in the refined story text. Keep it in business language.
2. **ID Generation for Pasted Stories:**
   - Reuse explicit `USxx` mentioned in text.
   - Or query active storage (`Engram` / `openspec/changes/`) for `max + 1`.
   - Or ask the user directly. Never fabricate an ID.
3. **Conditional Assumptions Header:**
   - Omit `### Assumptions` entirely if no unresolved questions exist.
   - All assumptions MUST use unchecked checkboxes (`- [ ]`).

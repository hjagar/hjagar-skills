## tc-generator structural parity

**As a** hjagar-skills maintainer
**I want** tc-generator brought up to the same structural standard as us-refinement (`metadata.version` + `license` in frontmatter, explicit Hard Rules/Decision Gates sections, a validator + fixture pair under `scripts/`/`tests/`)
**So that** it can be versioned, released, and quality-gated the same way as the other skills

### Acceptance criteria

**Scenario 1: Structural parity achieved**
- Given tc-generator's SKILL.md
- When the frontmatter and section structure are reviewed
- Then it contains `metadata.version`, `license`, and explicit Hard Rules / Decision Gates sections like us-refinement

**Scenario 2: Automated validation exists**
- Given a sample tc-generator output that violates a documented hard rule (e.g. Track A generated despite existing tests, or missing confidence tag)
- When the new validation script runs against it
- Then it reports failure; a compliant sample reports success

### Dependencies
- None identified (independent slice)

### Resolved decisions
- [x] Every current Step in `tc-generator/SKILL.md` becomes a formal, numbered Hard Rule — same criterion as US2, not just the steps already using imperative language.

<!-- [AI-DATA]
id: US3
type: chore
breaking: false
dependencies: []
metadata:
  scope:
    backend: true
    frontend: false
  role: "hjagar-skills maintainer"
  endpoint: "none"
  auth: "none"
  ui: "none"
scenarios:
  - name: "Structural parity achieved"
    given: "tc-generator's SKILL.md"
    when: "The frontmatter and section structure are reviewed"
    then: "It contains metadata.version, license, and explicit Hard Rules/Decision Gates sections"
  - name: "Automated validation exists"
    given: "A sample tc-generator output that violates a documented hard rule"
    when: "The new validation script runs against it"
    then: "It reports failure; a compliant sample reports success"
-->

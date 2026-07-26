## res-onboarding structural parity

**As a** hjagar-skills maintainer
**I want** res-onboarding brought up to the same structural standard as us-refinement (`metadata.version` + `license` in frontmatter, explicit Hard Rules/Decision Gates sections, a validator + fixture pair under `scripts/`/`tests/`)
**So that** it can be versioned, released, and quality-gated the same way as the other skills

### Acceptance criteria

**Scenario 1: Structural parity achieved**
- Given res-onboarding's SKILL.md
- When the frontmatter and section structure are reviewed
- Then it contains `metadata.version`, `license`, and explicit Hard Rules / Decision Gates sections like us-refinement

**Scenario 2: Automated validation exists**
- Given a sample onboarding output that violates a documented hard rule
- When the new validation script runs against it
- Then it reports failure; a compliant sample reports success

### Dependencies
- None identified (independent slice)

### Resolved decisions
- [x] Every current Step (0 through N) in `res-onboarding/SKILL.md` becomes a formal, numbered Hard Rule — same strictness as us-refinement, not just the steps already using imperative language.

<!-- [AI-DATA]
id: US2
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
    given: "res-onboarding's SKILL.md"
    when: "The frontmatter and section structure are reviewed"
    then: "It contains metadata.version, license, and explicit Hard Rules/Decision Gates sections"
  - name: "Automated validation exists"
    given: "A sample onboarding output that violates a documented hard rule"
    when: "The new validation script runs against it"
    then: "It reports failure; a compliant sample reports success"
-->

## req-discovery quality parity

**As a** hjagar-skills maintainer
**I want** req-discovery to have a validator script plus valid/invalid output fixtures (mirroring us-refinement's `scripts/validate_refinement.py` + `tests/mock_*.md` pattern) and to be wired into the release quality gate
**So that** req-discovery's output contract is checked automatically before release, same as us-refinement

### Acceptance criteria

**Scenario 1: Validator catches non-compliant output**
- Given a sample req-discovery output that violates one of its documented Hard Rules (e.g. missing hidden en-summary comment, wrong language-matching)
- When the new validation script runs against that sample
- Then it reports a failure

**Scenario 2: Valid output passes validation**
- Given a sample req-discovery output that follows all documented Hard Rules
- When the validation script runs against that sample
- Then it reports success

### Dependencies
- None identified (independent slice)

### Resolved decisions
- [x] Validator scope: check ALL documented output fields — `title`, `story`, `context`, `resolution`, `confidence`, the `Possible match` wrapper, and the hidden `<!-- en-summary: ... -->` comment — not just the critical subset.
- [x] `metadata.version` bumps from `v1.0.1` to `v1.1.0` as part of this change (minor: new tooling, not a patch).

<!-- [AI-DATA]
id: US1
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
  - name: "Validator catches non-compliant output"
    given: "A sample req-discovery output that violates a documented Hard Rule"
    when: "The new validation script runs against that sample"
    then: "It reports a failure"
  - name: "Valid output passes validation"
    given: "A sample req-discovery output that follows all documented Hard Rules"
    when: "The validation script runs against that sample"
    then: "It reports success"
-->

## Shared skill release quality gate with req-discovery validation

**As a** hjagar-skills maintainer
**I want** a shared release quality gate that runs the declared contract validation for each participating skill, starting with req-discovery
**So that** structured skill output contracts are verified consistently before release without duplicating release logic per skill

### Acceptance criteria

**Scenario 1: Shared gate runs each participating skill's declared validation**
- Given one or more skills declare a supported validation contract
- When the release quality gate runs
- Then it discovers and executes every declared validation using the shared gate
- And a failure from any participating skill fails the release quality gate

**Scenario 2: req-discovery valid fixture passes its full output contract**
- Given a req-discovery fixture that contains every required output field and structure
- When the shared release quality gate validates req-discovery
- Then validation succeeds
- And it verifies title, story, context, resolution, confidence, conditional Possible match behavior, language matching, and the hidden English summary comment

**Scenario 3: req-discovery contract violations fail validation**
- Given a req-discovery fixture that omits or violates any required output field or structure
- When the shared release quality gate validates req-discovery
- Then validation fails and identifies the violated contract rule

**Scenario 4: Existing participating-skill validation remains protected**
- Given a skill already has release validation
- When the shared release quality gate replaces skill-specific release wiring
- Then that skill's valid and invalid fixtures retain their expected pass and fail outcomes

**Scenario 5: Validation declarations remain safe and portable**
- Given a skill participates in the shared release quality gate
- When it declares its validation contract
- Then the declaration uses supported validator types and fixture expectations
- And it does not require arbitrary shell-command execution

### Dependencies
- None identified

### Resolved decisions
- [x] The release quality gate is shared across skills; skills opt in through declarative, constrained validation configuration.
- [x] req-discovery is the first skill added through the shared mechanism.
- [x] During the development rollout, skills without validation configuration are omitted from the gate; revisit whether they become release-blocking after every skill has been reviewed.
- [x] Validator coverage includes every documented req-discovery output-contract field and structural requirement.
- [x] Existing participating-skill validation remains covered by the shared gate.
- [x] `metadata.version` for req-discovery bumps from `v1.0.1` to `v1.1.0` as part of this change.

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
  - name: "Shared gate runs each participating skill's declared validation"
    given: "One or more skills declare a supported validation contract"
    when: "The release quality gate runs"
    then: "It executes every declared validation and fails if any participating skill fails"
  - name: "req-discovery valid fixture passes its full output contract"
    given: "A req-discovery fixture contains every required output field and structure"
    when: "The shared release quality gate validates req-discovery"
    then: "Validation succeeds after verifying the full declared contract"
  - name: "req-discovery contract violations fail validation"
    given: "A req-discovery fixture omits or violates a required output rule"
    when: "The shared release quality gate validates req-discovery"
    then: "Validation fails and identifies the violated rule"
  - name: "Existing participating-skill validation remains protected"
    given: "A skill already has release validation"
    when: "The shared release quality gate replaces skill-specific wiring"
    then: "Its valid and invalid fixtures retain their expected outcomes"
  - name: "Validation declarations remain safe and portable"
    given: "A skill participates in the shared release quality gate"
    when: "It declares its validation contract"
    then: "The declaration uses supported types and fixture expectations without arbitrary shell commands"
-->

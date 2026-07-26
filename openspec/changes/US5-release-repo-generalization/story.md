## Release-Repo + skill-payload generalization

**As a** hjagar-skills maintainer
**I want** `Release-Repo.sh`/`.ps1` to operate against `skills/<name>/` instead of assuming SKILL.md lives at repo root, and to generalize its quality gate/packaging to any skill (falling back gracefully when a skill has no scripts/tests)
**So that** any skill can be versioned, quality-gated, and packaged into a release zip independently

### Acceptance criteria

**Scenario 1: Releasing a skill with a validator**
- Given a skill with its own scripts/ and tests/ fixtures (e.g. us-refinement)
- When Release-Repo is run for that skill
- Then it bumps that skill's frontmatter version, runs its validator against its fixtures, and packages only that skill's files into the release zip

**Scenario 2: Releasing a skill without a validator**
- Given a skill with no scripts/tests
- When Release-Repo is run for that skill
- Then it prints a warning that the quality gate is being skipped, does not fail the release, and still packages and releases the skill

### Dependencies
- US4 (shares the same skill-root resolution pattern)
- Best sequenced after US2/US3 so every skill has a validator to exercise, though not strictly blocking

### Resolved decisions
- [x] "No scripts/tests" fallback prints a visible warning (e.g. `Warning: no scripts/tests found for <skill> — skipping quality gate`) and continues — non-blocking, not silent.

<!-- [AI-DATA]
id: US5
type: refactor
breaking: true
dependencies: [US4]
metadata:
  scope:
    backend: true
    frontend: false
  role: "hjagar-skills maintainer"
  endpoint: "none"
  auth: "none"
  ui: "none"
scenarios:
  - name: "Releasing a skill with a validator"
    given: "A skill with its own scripts/ and tests/ fixtures"
    when: "Release-Repo is run for that skill"
    then: "It bumps that skill's version, runs its validator, and packages only that skill's files"
  - name: "Releasing a skill without a validator"
    given: "A skill with no scripts/tests"
    when: "Release-Repo is run for that skill"
    then: "It warns, skips validation without failing, and still packages and releases the skill"
-->

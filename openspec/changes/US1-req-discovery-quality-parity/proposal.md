# Proposal: US1 req-discovery Quality Parity & Shared Release Quality Gate

## Intent
Establish a shared release quality gate in `hjagar-skills` that validates output contracts across participating skills via declarative configuration, incorporating `req-discovery` as the first new skill and bumping `req-discovery` to `v1.1.0`.

## Scope
### In Scope
- Shared quality gate discovery and execution framework for participating skills in release scripts.
- Declarative, safe validation contract definitions and test fixture execution (valid and invalid) for `req-discovery`.
- Full verification of `req-discovery` output contract rules: title, story, context, resolution, confidence, conditional match behavior, language matching, and hidden summary comment.
- Preservation of existing `us-refinement` validation fixture pass/fail guarantees.
- Version bump of `req-discovery` metadata to `1.1.0`.

### Out of Scope
- Enforcing mandatory quality gate validation for skills lacking validation configuration.
- Executing arbitrary shell commands inside skill validation declarations.
- Direct CI/CD workflow pipeline sync implementations.

## Capabilities
### New Capabilities
- `req-discovery-contract-validation`: Declarative schema and fixture validation verifying full `req-discovery` output contract compliance.
- `shared-skill-quality-gate`: Unified execution engine running validation for all declared participating skills during release.

### Modified Capabilities
- `release-repo-scripts`: Updated release verification step in `cli/Release-Repo.*` to run the shared quality gate across all configured skills.

## Approach
- Define a declarative validation configuration model for skills using supported validator types and fixture expectations.
- Create valid and invalid test fixtures for `req-discovery` covering all documented output rules.
- Update release scripts (`cli/Release-Repo.sh` and `cli/Release-Repo.ps1`) to iterate over participating skills and run declared validations safely.
- Ensure existing `us-refinement` validation suite runs intact through the shared gate.

## Affected Areas
- `skills/req-discovery/`: `SKILL.md` (version `1.1.0`), validation fixtures and schema declarations.
- `skills/us-refinement/`: Integration with shared validation gate.
- `cli/Release-Repo.sh` & `cli/Release-Repo.ps1`: Quality gate execution step.

## Risks
- False positives/negatives in structural contract validation rules.
  *Mitigation*: Provide granular valid and invalid test fixtures per contract rule.

## Rollback Plan
- Revert release script changes in `cli/Release-Repo.*`.
- Revert `skills/req-discovery/` validation declarations and restore `metadata.version` to `1.0.1`.

## Dependencies
- None.

## Success Criteria
- Shared release quality gate executes validation for all declared skills and halts on any failure.
- `req-discovery` valid fixture passes full contract validation; invalid fixtures fail with rule-specific errors.
- `us-refinement` existing validation tests retain 100% pass/fail parity.
- `req-discovery` `metadata.version` updated to `1.1.0`.

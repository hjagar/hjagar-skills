# Capability Spec: req-discovery Contract Validation

## Overview
Defines declarative validation rules and test fixture verification for the `req-discovery` skill output contract, ensuring full compliance with output structure and metadata requirements.

## Requirements

### Requirement: Full Output Contract Verification
The validator MUST enforce all documented output contract elements for `req-discovery` responses, including title, user story (As a / I want / So that), context, resolution, confidence rating, conditional match behavior, target language matching, and the hidden summary comment block (`<!-- [AI-DATA] ... -->`).

### Requirement: Valid Fixture Pass Guarantee
The validator MUST successfully validate compliant `req-discovery` test fixtures where all required structural sections, metadata fields, and formatting rules are present without raising errors.

### Requirement: Invalid Fixture Violation Detection
The validator MUST detect contract violations in non-compliant fixtures—including missing headers, invalid confidence values, missing story elements, or absent summary comment blocks—and MUST fail with rule-specific error messages.

## Scenarios

### Scenario: Valid output fixture validation
- Given a `req-discovery` output fixture containing all required sections, matching language, and valid metadata
- When contract validation is executed against the fixture
- Then validation MUST pass successfully without reporting errors

### Scenario: Detection of missing user story elements
- Given a `req-discovery` output fixture missing the "As a / I want / So that" story block
- When contract validation is executed against the fixture
- Then validation MUST fail and return a contract violation error targeting the user story requirement

### Scenario: Detection of missing hidden summary comment
- Given a `req-discovery` output fixture lacking the `<!-- [AI-DATA]` comment block
- When contract validation is executed against the fixture
- Then validation MUST fail and report a missing metadata comment violation

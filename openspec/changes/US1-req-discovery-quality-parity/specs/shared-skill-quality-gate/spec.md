# Capability Spec: Shared Skill Quality Gate

## Overview
Provides a unified release quality gate framework in `hjagar-skills` that discovers, configures, and executes validation suites across all participating skills.

## Requirements

### Requirement: Skill Validation Discovery and Execution
The quality gate engine MUST discover all participating skills with declared validation contracts and MUST execute their validation suites during release checks.

### Requirement: Strict Release Halt on Failure
The quality gate engine MUST propagate any validation failure from a participating skill and MUST return a non-zero exit status to halt execution.

### Requirement: Safe Declarative Configuration
Skill validation declarations MUST specify supported validator types and fixture expectations in a declarative format and MUST NOT execute arbitrary shell commands.

### Requirement: Backwards Compatibility for Participating Skills
The shared quality gate MUST preserve existing validation outcomes for skills currently using quality gates (such as `us-refinement`), ensuring 100% pass and fail parity.

## Scenarios

### Scenario: Execution of declared skill validations
- Given multiple skills declaring valid contract validation configurations
- When the shared release quality gate is executed
- Then the engine MUST run validation for each declared skill and report overall success

### Scenario: Halting on skill validation failure
- Given a participating skill with an invalid test fixture or failing contract rule
- When the shared release quality gate is executed
- Then the engine MUST report the specific skill failure and exit with a non-zero status code

### Scenario: Verification of existing skill quality gates
- Given the `us-refinement` skill with existing valid and invalid test fixtures
- When executed through the shared release quality gate
- Then all `us-refinement` test fixtures MUST produce identical pass and fail results as prior dedicated scripts

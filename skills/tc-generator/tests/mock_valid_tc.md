# Test Cases: User Authentication (US-101)

Confidence: high
Source: Acceptance Criteria (US-101)
Existing tests: false

## Track A — Unit Test Suggestions

- `test_login_with_valid_credentials_returns_jwt_token`
- `test_login_with_invalid_password_returns_401`

## Track B — QA Manual Checklist

### Happy Path

- **TC-01: Successful Login**
  - **Precondition:** User is registered and has an active account.
  - **Steps:**
    1. Navigate to `/login`.
    2. Enter valid email and password.
    3. Click "Sign In".
  - **Expected result:** User is redirected to dashboard with valid session.

### Edge Cases

- **TC-02: Password with Leading/Trailing Whitespace**
  - **Precondition:** User account exists.
  - **Steps:**
    1. Enter email and password with leading space.
    2. Click "Sign In".
  - **Expected result:** Whitespace is handled according to policy or appropriate validation error shown.

### Negative / Error Cases

- **TC-03: Account Locked after 5 Failed Attempts**
  - **Precondition:** User account exists.
  - **Steps:**
    1. Enter wrong password 5 times consecutively.
  - **Expected result:** Account is temporarily locked with message to reset password.

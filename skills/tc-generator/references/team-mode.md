# Team Mode (deferred — not fully specified yet)

This mode is sketched, not finalized. Flag to the user when it's invoked that the design is provisional and ask for confirmation before relying on it heavily.

Differences from personal mode, as currently understood:

- **Format**: rigid, consistent structure across the org — every case follows the same Precondition/Steps/Expected-result shape strictly, since the executor didn't write the code and can't fill gaps from memory.
- **Detail level**: explicit test data, required prior state, roles/credentials to use — nothing assumed.
- **Traceability**: cases link back to the originating issue/US id. GitHub integration becomes worth revisiting here (unclear yet how well GitHub issues fit test-case tracking specifically — this was an open question, not a settled decision).
- **AI-DATA metadata**: only add a structured metadata block (id, status: pending/passed/failed, executed-by) if there's a real tracking need — and note that a Playwright/robot-framework-style automated block only makes sense once there's actual automated execution, not before.
- **Ownership**: the file stops being read-only output — whoever executes (e.g. a QA junior) may need to add findings or mark cases not applicable, which pushes this toward a tracker/issue-based flow rather than a static markdown file.

Do not treat this file as a finished spec — surface open questions back to the user rather than silently deciding them.

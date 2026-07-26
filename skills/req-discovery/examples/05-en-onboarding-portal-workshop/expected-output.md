### Self-service client onboarding portal

**Story:** As a new client, I want to enter my own company details and upload required documents through a self-service portal, so that my account gets set up without the vendor's team re-keying my information by hand.
**Context:** Raj described today's manual PDF-and-retype process and proposed the fix directly — "a self-service portal... it just lands in our system without my team retyping anything" (Raj, 00:03:30) — with a review-before-active gate confirmed right after ("there should be a review step... Review, not retype", Raj, 00:04:10) and Tom backing the bottleneck it removes (Tom, 00:02:40).
**Resolution:** N/A — not revisited elsewhere in the meeting. (Branding/look-and-feel was raised at 00:05:20 but explicitly kept as a design-polish note, not drafted as a requirement.)
**Confidence:** explicit

<!-- en-summary: New clients should self-serve their onboarding (enter details,
upload docs) through a portal instead of the vendor retyping a PDF form, with a
review-before-active approval gate kept for the vendor's team. Explicit ask,
not revisited. -->

### Bulk import of legacy customer records

**Story:** As the vendor operations team, I want our ~5,000 existing customer records imported from the old spreadsheets on their core fields with a validation report for failed rows, so that legacy accounts move into the new portal without re-keying them and without any records being silently dropped.
**Context:** Raj introduced this just before the mid-workshop coffee break — "maybe five thousand existing customer records sitting in Excel files... those need to come into the new system" (Raj, 00:39:11) — and deferred the format details; the discussion resumed right after the break, where the scope was pinned down to four common fields (company name, contact email, signup date, plan tier) with a per-row error report (Raj, 00:45:18; Dana, 00:45:44; Tom's silent-drop concern, 00:45:31). The requirement spans the 00:42:03–00:44:20 break boundary; both mentions are the same need, tracked by their speaker/timestamp labels.
**Resolution:** The topic was split by the coffee break and picked up again in the second half — the last stated position wins: import on the four core fields, manual cleanup for the varying extra columns, and a validation report (row number + failure reason) instead of silent drops (Raj/Dana, 00:45:18–00:45:44). The earlier "let me come back to that — I want to think about the exact columns before I commit to anything" hesitation (00:40:03) was resolved, not left open.
**Confidence:** explicit

<!-- en-summary: Migrate ~5,000 legacy customer records from inconsistent old
Excel files into the new portal on four core fields, with a validation/error
report for rows that fail rather than silent drops. Discussed across the
mid-meeting break; resolved in the second half. Explicit. -->

### Role-based access for the vendor team

**Story:** As the vendor operations lead, I want at least two access roles — read-only support and an approver/lead role — so that support staff can view client data without being able to approve new accounts as active.
**Context:** Tom raised it in the second half — "support folks should see client data read-only, but only leads should be able to approve a new account as active" (Tom, 00:50:43) — scoped by Dana to two roles to start (Dana, 00:50:56) and agreed by both Tom and Raj to keep it at exactly two for v1 (00:51:09–00:51:22).
**Resolution:** N/A — agreed in one pass; scope explicitly bounded to two roles for v1, more deferred.
**Confidence:** explicit

<!-- en-summary: Two-role access control for the vendor team — read-only support
vs. approver/lead — so only leads can activate new accounts. Scoped to exactly
two roles for v1 by mutual agreement. Explicit. -->

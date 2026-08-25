# Blockers

| ID | Severity | Scope | Blocker | Needed to unblock | State |
|---|---|---|---|---|---|
| BLK-001 | P1 | Device matrix | The `Samsung-2` physical lane is connected but USB-debugging authorization is pending. | Unlock that phone and accept the USB-debugging prompt. | OPEN |
| BLK-002 | P0 | Release verdict | The exact installed clarityqa artifact is Android debug-signed and cannot be tied to a clean immutable source commit. | Supply the exact clean, signed release candidate with hash and provenance. | OPEN |
| BLK-003 | P0 | R2/R3 scenarios | Unique synthetic customer/Jeeber fixtures, provider approvals, two-persona pairing, and cleanup owners are not frozen. | Reserve an isolated account/request/delivery/chat/KYC matrix and cleanup plan. | OPEN |
| BLK-004 | P0 | Environment | Static destination and test-lane clearance was required. | Independent APK/source review. | RESOLVED FOR R0 ONLY |
| BLK-005 | P1 | Emulator lane | API-35 AVD cannot boot because the host data volume has only a few hundred MiB free. | Safely free several GiB and repeat emulator preflight. | OPEN |
| BLK-006 | P0 | Repeatable physical automation | Maestro 2.0.5 rejects the ADB-online A33 serial and the release-flavor hierarchy exposes no stable shell IDs. | Repair physical attachment and expose stable semantic identifiers in the exact RC/test artifact. | OPEN; manual exploratory navigation completed only |
| BLK-007 | P1 | Prior evidence integrity | Retained historical memory samples conflict with summaries; one file labels a signer hash as an APK hash; prior role selection/rendering disagrees. | Reconcile artifact timestamps/labels and reproduce on an exact known build. | OPEN; prior evidence only |
| BLK-008 | P1 | Clarity/privacy | Installed Settings shows a Privacy & analytics heading without an analytics/consent control. | Confirm adapter availability/configuration, render the recoverable consent choice, and correlate a consented synthetic session. | OPEN |
| BLK-009 | P0 | Paired delivery/chat | Only one authorized physical persona/device was available. | Authorize the second phone and reserve matched customer/Jeeber fixtures. | OPEN |
| BLK-010 | P0 | Authentication, role, KYC, and happy-path sign-off | The A33 session was created through debug-only Super Login Plus and persisted across an in-place release-flavor update. | With explicit approval, clear only the isolated package data; install the exact clean RC; log in through normal phone/OTP using reserved personas; read back authoritative role/KYC state; never use Super Login Plus in the evidence chain. | OPEN |

Product defects are tracked separately in [DEFECTS.md](DEFECTS.md); a defect is
not downgraded to BLOCKED merely because the full paired or mutation variant
could not be run.

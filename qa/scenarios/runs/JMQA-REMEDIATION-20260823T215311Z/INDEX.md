# Remediation and clean physical rerun index

> Run: JMQA-REMEDIATION-20260823T215311Z
>
> Started: 2026-08-23 21:53:11 UTC
>
> State: IN PROGRESS — ARTIFACT LAYER PASS; UPLOAD/LIVE/STORES/PHYSICAL BLOCKED
>
> Release verdict: NO-GO

This run has forced-clean, signed, fully inspected Android AAB and iOS IPA
artifacts for the canonical `com.olivium.jeeb` identity. The exact mobile suite
passes 7,868 tests with 66 intentional skips and zero failures. Both artifacts
use the protected canonical Firebase/Maps configuration, staging edge, and
contain no Super Login or Dev Tool release surface. Apple validation accepted
the current IPA; the branded iOS launch screen also replaces Flutter's default
placeholder.

The current AAB SHA-256 is
`4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b`;
the current IPA SHA-256 is
`eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94`.
They pass the artifact layer but are held from upload because the source tree
has not yet been frozen into an immutable, independently reviewed mobile
revision. Neither artifact result is a functional or store-delivery PASS.

The source audit found 133 unique changed tracked paths and 245 untracked paths
in an incoherent staged/unstaged overlay. The current index must not be
committed; the release changes must be reconstructed as scoped reviewable work
in clean worktrees while raw proof and signer material remain outside Git.

Live staging remains pre-deploy: normal OTP returns unavailable, Super Login
Plus/demo surfaces remain open, voice is fake, public WSS does not upgrade, and
the App/Universal Link association files are not live. No current JMS scenario
has run on a store-delivered candidate. The prior Super Login Plus session and
all sideloaded/debug observations are excluded from this evidence chain.

Infra #26 and gateway #523 are CI-green and independently approved at their
reviewed heads. OTP #27 exact head `29ff7af` is also remote-green and
independently approved after executable same-digest/full-Spec rollback proof.
Realtime #14 remains REQUEST_CHANGES on three P1 and one P2 findings, and voice
#27 remains REQUEST_CHANGES on one newly proven full-Spec rollback P1; isolated
writers are correcting both in parallel. Nothing has been merged or deployed.

## Run records

- [Detailed report](REPORT.md)
- [Execution checklist](CHECKLIST.md)
- [Sanitized test log](TEST-LOG.md)
- [Structured sanitized data](DATA.json)
- [Provider and environment blockers](BLOCKERS.md)
- [Parallel-agent ownership and shared-memory ledger](AGENT-LEDGER.md)
- [Mobile source reconstruction runbook](MOBILE-SOURCE-RECONSTRUCTION.md)
- [Staging TestFlight and Play Internal audit](STAGING-STORE-AUDIT-20260824.md)
- [OS App/Universal Link acceptance scenario](../../cross-cutting/JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md)

No source test or console inspection in this folder is a physical-device PASS.
Scenario outcomes change only after the exact candidates are delivered through
Play Internal Testing and TestFlight, normal OTP succeeds, and the required
device/server evidence is retained.

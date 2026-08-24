# Remediation and clean physical rerun index

> Run: JMQA-REMEDIATION-20260823T215311Z
>
> Started: 2026-08-23 21:53:11 UTC
>
> State: IN PROGRESS — RECONSTRUCTED SOURCE LOCAL PASS; FULL CI/REVIEW, FRESH ARTIFACT BUILDS, LIVE, STORES, AND PHYSICAL BLOCKED
>
> Release verdict: NO-GO

This run retains forced-clean, signed, fully inspected Android AAB and iOS IPA
artifacts for the canonical `com.olivium.jeeb` identity. Local source-bearing
commit `e07d4542` passes 7,882 CI-equivalent tests with 66 intentional skips and
zero failures in approximately 329 seconds, plus focused fatal-info and
credential/transport gates. It removes the committed development passcode
fallback and requires WSS for courier tracking outside the dev flavor.
The artifacts use protected canonical Firebase/Maps configuration, staging
edge, and contain no Super Login or Dev Tool release surface. Apple validation
accepted the IPA, but both binaries predate the reconstructed head.

The current AAB SHA-256 is
`4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b`;
the current IPA SHA-256 is
`eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94`.
They pass their historical artifact layer but are held from upload pending full
CI and independent review of the exact reconstructed head, followed by clean
rebuilds from that head. Neither artifact result is a functional or
store-delivery PASS.

The source audit historically found 133 unique changed tracked paths and 245
untracked paths in an incoherent staged/unstaged overlay. Its sanitized
188-file selection was reconstructed as `e208a4c8`, then reconciled with
`origin/main` `0c26c159` and hardened in `e07d4542`. The source-bearing diff is
194 files, 12,392 insertions, and 4,510 deletions. CI, Flutter CI, and Mobile CI
are active, but remote PR head `8788a24d` has only fail-closed evidence; the
next push must exercise all three at its exact evidence descendant.

Canonical historical dev Firebase configuration was validated without output,
the four named dev repository Actions secrets were installed, and read-back
was limited to names/timestamps. Real native config files remain absent, and
the dev wrapper cleans injected configuration after success and failure.

Live staging remains pre-deploy: normal OTP returns unavailable, Super Login
Plus/demo surfaces remain open, voice is fake, public WSS does not upgrade, and
the App/Universal Link association files are not live. No current JMS scenario
has run on a store-delivered candidate. The prior Super Login Plus session and
all sideloaded/debug observations are excluded from this evidence chain.

Infra #26 remains reviewed/green. Gateway bootstrap is local/unpushed from
`63b19dba`. Realtime #14 `4959d9e` is remote-green but exact-head review found
two P1s: a plain-CLI rollback race and stale rollout documentation. OTP
`29ff7af` and voice `6509c840` remain test-green, but their prior approvals are
superseded by the same race. No service is deployed. All four service rollouts
must use Engine API version-CAS recovery and the binding two-phase sequence.
All five GitHub staging environments enforce only their default branch.
Cloudflare target-account token authority and an owner-confirmed physical SMS
canary recipient remain blockers. Nothing was merged to main, deployed, sent
to a provider/store, or driven on a device in this reconciliation.

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

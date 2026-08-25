# Release GO/NO-GO checklist

## Smoke gate

- [ ] JMS-JHP-001 passes on the exact candidate or approved equivalent.
- [ ] Auth launch/session/navigation smoke passes.
- [ ] Core shell identifiers are available.
- [ ] Clarity-default-off smoke passes.
- [ ] No P0/P1 smoke defect remains.

## Regression gate

- [ ] All P0/P1 feature scenarios required by the change pass.
- [ ] Offline/retry/idempotency and lifecycle scenarios pass.
- [ ] English and Arabic RTL pass.
- [ ] Accessibility checks pass for affected critical paths.
- [ ] Push/deep-link receiver proof passes for affected categories.
- [ ] Unit/widget/seam/live results are labeled accurately; no mock result is called live proof.

## Release-candidate gate

- [ ] Exact source revision is immutable, independently reviewed, and matches
      the store artifacts through reproducible build evidence or an approved
      cryptographic provenance record.
- [ ] Fresh public staging probes prove normal OTP, disabled bypass/demo
      surfaces, real voice transcription, authenticated WSS, Firebase/push,
      AASA, and `assetlinks.json` before store upload.
- [ ] Exact release artifact is delivered by Play Internal Testing and TestFlight
      and tested on required real Android and iOS devices; sideloads do not count.
- [ ] JMS-JHP-003 full paired COD loop passes.
- [ ] KYC none/pending/approved/rejected/directed-resubmission matrix passes.
- [ ] Chat, tracking, OTP, cancellation, escalation, dispute, receipt, and rating pass.
- [ ] JMS-LINK-001 passes on Android and iOS with live association files and
      operating-system-owned HTTPS handoff.
- [ ] Security, privacy, cross-account authorization, performance/resource, and upgrade checks pass.
- [ ] Clarity is either fully disabled by build policy or all privacy/admin/device/dashboard gates pass.
- [ ] Evidence review and cleanup are complete.
- [ ] No electronic payment/refund behavior and no forbidden-host communication are detected.

## Automatic NO-GO conditions

- [ ] Any required P0/P1 is FAIL, BLOCKED, or unexecuted without approved disposition.
- [ ] Full two-device COD loop fails on the exact candidate.
- [ ] Retry creates duplicate request, offer, message, delivery, OTP use, receipt, or rating.
- [ ] Wrong-account access or protected-data flash occurs.
- [ ] Token, OTP, PII, KYC, chat, location, or private evidence leaks.
- [ ] Any electronic card/payment/gateway/refund or fake money-success path appears.
- [ ] Clarity captures before consent, crosses accounts, fails masking/revoke, or lacks required approvals.
- [ ] Release uses unreliable coordinate/text automation for a critical path.
- [ ] Any auth-dependent result used Super Login Plus, a demo user, mock/fake
      provider, crafted state, or a sideloaded substitute.
- [ ] Cleanup cannot contain the synthetic state.

Final decision: GO / GO WITH CLARITY DISABLED / NO-GO
Decision owner: Staff Mobile QA Lead
Build SHA and artifact hash:
Open risks/waivers and expiry:
Decision timestamp:

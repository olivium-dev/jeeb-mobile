# Test gate matrix

This matrix separates documentation from enforcement. A gate is proposed until
the corresponding workflow is actually wired and proven.

| Gate | Target runtime | Typical target | Required scenario sets | Blocks |
|---|---:|---|---|---|
| Smoke | 1–5 min | One clean emulator per supported platform | JMS-JHP-001, JMS-AUTH-001, JMS-AUTH-003, JMS-REQ-001, JMS-CLR-001 | Pull request when automated |
| Regression | 15–30 min | Sharded emulators plus one physical Android | All feature suites; RES-001–006; PUSH-001–005 | Main-branch promotion when automated |
| Release candidate | 30–90 min | Exact store-delivered artifact on real Android and iOS devices | All P0/P1 scenarios, all complex suites including JMS-LINK-001, full Clarity privacy suite | Store/internal release |
| Exploratory | Time-boxed | Real supported devices | New OS, layout, accessibility, performance, unknown-route investigation | Advisory unless a P0/P1 defect is found |

## Smoke checklist

- [ ] App launches from a clean install without a crash or dead end.
- [ ] Phone OTP happy path reaches the Requests shell using a synthetic account.
- [ ] Customer creates exactly one isolated synthetic request, reads it back,
      and completes the approved cleanup.
- [ ] Core shell tabs render with stable semantic identifiers.
- [ ] Clarity remains off before explicit consent.
- [ ] No secret, PII, live request, or real recipient was used.

## Regression checklist

- [ ] Every feature suite has happy, negative, boundary, and recovery coverage.
- [ ] English and Arabic RTL variants pass.
- [ ] Offline, timeout, retry, and process-restart variants pass.
- [ ] Push/deep-link paths are proven at receiver side with a unique nonce.
- [ ] All write scenarios use isolated resettable fixtures and are read back.
- [ ] No electronic payment, gateway settlement, or money-moving refund path exists.

## Release-candidate checklist

- [ ] The exact intended source is frozen in an immutable revision and passes
      independent release review; generated artifacts are bound to that
      revision or rebuilt from it.
- [ ] The exact release artifact hash is recorded.
- [ ] Play Internal Testing and TestFlight deliver the recorded hashes; no
      debug, sideloaded, simulator, or substitute build is accepted.
- [ ] Supported/minimum OS matrix is executed on real devices.
- [ ] Full customer + Jeeber COD loop passes on two synthetic accounts/devices.
- [ ] KYC states none, pending, approved, rejected, and directed field resubmission pass.
- [ ] Chat, tracking, OTP, cancellation, escalation, dispute, receipt, and rating pass.
- [ ] JMS-LINK-001 proves OS-owned HTTPS App/Universal Links on both store builds.
- [ ] Clarity consent, masking, revocation, background, auth loss, logout, account
      switch, kill switch, and no-send OS cases pass.
- [ ] Evidence and secret/privacy review are complete.
- [ ] Staff Mobile QA records an explicit GO or NO-GO; silence is NO-GO.

## Priority rule

- P0: loss of access, unauthorized data capture, identity/privacy exposure,
  illegal delivery state, fake money movement, or wrong-person action.
- P1: broken primary journey, message loss, duplicate write, incorrect KYC gate,
  unusable RTL/accessibility, or missing recovery.
- P2: secondary behavior or non-blocking quality defect.
- P3: cosmetic issue with no functional or accessibility consequence.

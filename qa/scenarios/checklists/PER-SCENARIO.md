# Per-scenario execution checklist

## Record

- Scenario ID:
- Run ID / nonce:
- Tester:
- Start/end UTC:
- Build SHA / artifact hash:
- Distribution channel / store build ID:
- Install provenance: Play Internal / TestFlight / diagnostic only
- Environment:
- Device / OS:
- Locale / font scale / orientation:
- Network / permission / lifecycle profile:
- Synthetic account and fixture aliases:

## Execute

- [ ] Confirm the exact documented precondition on the real app surface.
- [ ] Capture before-state for every affected entity.
- [ ] Perform the exact actor path; no substitute route or hidden shortcut.
- [ ] Where store or OS behavior is under test, prove store delivery and reject
      sideload, direct-intent, custom-scheme, simulator, or in-app-router substitutes.
- [ ] Authenticate through normal phone/OTP; no Super Login Plus, demo account,
      mock transport, fake provider, or crafted role/KYC state is used.
- [ ] Use semantic identifiers for automation.
- [ ] Introduce only the fault named by the scenario.
- [ ] Observe the primary expected result.
- [ ] Observe every required no-side-effect assertion.
- [ ] For writes, verify through receiving UI/server read-back with the run nonce.
- [ ] For push/chat, prove delivery on the receiver, not sender logs alone.
- [ ] For JMS-LINK-001, prove the tap starts outside Jeeb and the OS opens the
      verified HTTPS link without a chooser, browser hop, or duplicate target.
- [ ] After timeout/unknown result, reconcile before retrying.
- [ ] Execute cleanup and verify final state.

## Classify

- [ ] PASS — exact path and evidence passed.
- [ ] FAIL — product/contract differs from expected.
- [ ] BLOCKED — prerequisite, environment, authorization, fixture, device, or product capability missing.
- [ ] INVALID — scenario conflicts with current authoritative product contract.

Failure category, choose one:

- [ ] APP_DEFECT
- [ ] CONTRACT
- [ ] ENVIRONMENT
- [ ] FIXTURE
- [ ] FLOW
- [ ] PRIVACY

Defect/blocker ID:
Result summary:
Next authorized action:

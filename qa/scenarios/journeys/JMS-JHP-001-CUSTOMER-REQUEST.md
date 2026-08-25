# JMS-JHP-001 — Customer creates a request

> Result: **NOT RUN**
> Owner: Mobile QA
> Last verified: Never

## Contract

| Field | Value |
|---|---|
| Source | Current register, shell, request-type, location, summary, and waiting routes |
| Persona | New customer |
| Priority / gate | P0 / Smoke |
| Mutation class | R2 — creates one isolated synthetic request |
| Privacy class | Masked synthetic content only |
| Automation | Candidate composition of jm-009, jm-023, jm-024, and jm-026 Maestro flows |
| Clarity screens | onboarding, register, shell, request-type, client-location, capture-location, request-summary, waiting-no-coverage |

## Preconditions

- [ ] Authorized MSI test lane is healthy and does not resolve any dependency to
      the forbidden host named in workspace policy.
- [ ] A resettable synthetic adult customer alias is available; credentials and
      OTP values are supplied outside source control.
- [ ] Request text, photo, and location are visibly synthetic and non-sensitive.
- [ ] The fixture has no open request, accepted offer, or active delivery.
- [ ] The exact build SHA, artifact hash, device, OS, locale, permission state,
      and network profile are recorded.

## Acceptance scenario

```gherkin
Given a new synthetic customer with no open request
When the customer completes onboarding, phone OTP, and one valid request
Then the request appears once in the waiting or offer-review state
And the customer lands on the correct Requests experience without a duplicate write
```

## Execution checklist

| # | Action | Expected result | Evidence |
|---:|---|---|---|
| 1 | Clean-launch the exact build | Onboarding renders; no authenticated data appears | Root identifier + build record |
| 2 | Complete or skip onboarding according to the selected variant | Register renders | onboarding → register navigation |
| 3 | Enter the synthetic phone alias, request OTP, and verify | One authenticated customer session is created | register completion; no OTP value in logs |
| 4 | Confirm Requests shell | Requests content and its stable shell tab are visible | shell root/tab evidence |
| 5 | Start New Request and choose one valid request type | Request composition opens with the selected tier/type | request-type selection |
| 6 | Enter a unique synthetic description nonce | Text is preserved exactly; no PII | masked/sanitized composition evidence |
| 7 | Select a synthetic pickup/drop-off or safe test location | Location resolves and can be reviewed | no precise real location retained |
| 8 | Review and submit once | Exactly one request is created | request read-back by unique nonce |
| 9 | Observe waiting or offer-review | Timer/state is live and navigation remains usable | final screen and request identifier alias |

## Required variants

- [ ] English LTR and Arabic RTL.
- [ ] Permission already granted and location permission denied.
- [ ] Typed request and voice/dictation request.
- [ ] Coverage available and no-coverage waiting.
- [ ] Slow network with visible loading and one safe retry.
- [ ] App background/resume while request is still open.

## Pass criteria and cleanup

- [ ] One request exists with the unique nonce; no duplicate request exists.
- [ ] The customer can reopen the request after a warm restart.
- [ ] No real identity, address, location, or request content is in evidence.
- [ ] The request is cancelled/reset through the approved fixture cleanup path.
- [ ] Final status is recorded as PASS, FAIL, or BLOCKED; never inferred.

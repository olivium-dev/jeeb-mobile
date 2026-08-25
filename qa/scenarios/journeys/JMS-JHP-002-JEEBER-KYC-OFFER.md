# JMS-JHP-002 — Jeeber activation, KYC, and offer

> Result: **NOT RUN**
> Owner: Mobile QA + KYC test-state owner
> Last verified: Never

## Contract

| Field | Value |
|---|---|
| Source | Current additive shell capability, Jeeber onboarding, KYC, feed, and offer routes |
| Persona | Existing customer activating Jeeber capability |
| Priority / gate | P0 / Regression |
| Mutation class | R3 — KYC and offer lifecycle writes |
| Privacy class | Restricted synthetic KYC media; never version raw media |
| Automation | jm-036 through jm-048 where their present contracts still match |
| Clarity screens | shell, delivery-register-prompt, jeeber-onboarding, capture-location, kyc-status, onboarding-funding, offer-kyc-gate, jeeber-request-detail, jeeber-offer-submission, jeeber-pending-offers |

## Product invariants

- A Jeeber is also a customer. The five additive shell tabs remain present;
  there is no happy-path customer/Jeeber mode toggle.
- Unapproved users cannot bypass the KYC gate to submit an offer.
- Current KYC does not include vehicle registration.
- Final rejection leads to a support appeal. General resubmission is not
  assumed; only backend-directed field resubmission is valid.

## Preconditions

- [ ] A resettable adult synthetic user lacks Jeeber capability and KYC.
- [ ] Synthetic identity images are generated for testing and depict no real
      person or government document.
- [ ] One open synthetic request is available in the service area.
- [ ] An authorized test-state operator can advance KYC pending → approved
      without contacting a production vendor.
- [ ] No electronic payment or card action is required anywhere in the path.

## Acceptance scenario

```gherkin
Given a synthetic customer who is not yet an approved Jeeber
When the user completes Jeeber onboarding and the test KYC is approved
Then the existing account gains the Jeeber capability without losing customer access
And the user can submit exactly one offer to an open synthetic request
```

## Execution checklist

| # | Action | Expected result | Evidence |
|---:|---|---|---|
| 1 | Open Dashboard/Delivery capability from shell | Registration prompt renders; feed is not exposed | gate root evidence |
| 2 | Start Jeeber onboarding | Personal/photo, address, and service-area steps are reachable | step roots, no real location |
| 3 | Deny then allow required camera/location permissions | Denial has recovery; grant resumes at the same step | permission-state evidence |
| 4 | Complete onboarding with synthetic values | KYC identity step renders; no vehicle-registration step appears | KYC root + absence assertion |
| 5 | Submit synthetic KYC once | Status becomes pending; duplicate submit is blocked | pending status/read-back |
| 6 | Use the authorized fixture transition to approve | Account capability refreshes from server | approved read-back, no manual UI shortcut |
| 7 | Return to shell | All customer tabs remain; Jeeber feed/earnings bodies become active | additive shell evidence |
| 8 | Open the seeded request and offer composer | Approved user bypasses the KYC gate | request detail + composer |
| 9 | Submit one valid offer | Offer appears once in Pending Offers | receiver/read-back evidence |

## Required variants

- [ ] none, pending, approved, rejected, and directed field-resubmission KYC states.
- [ ] Stale local capability versus current server available_roles.
- [ ] Approval while app is foreground, background, and cold-started.
- [ ] Network loss during KYC upload and during offer submission.
- [ ] English and Arabic RTL; large text; TalkBack/VoiceOver.
- [ ] KYC rejection support appeal without a general reset button.
- [ ] Negative assertion that a customer/Jeeber mode toggle does not reappear.

## Pass criteria and cleanup

- [ ] No raw KYC image or response payload is committed as evidence.
- [ ] Capability is server-authoritative after relaunch.
- [ ] Exactly one offer exists and is linked to the synthetic request.
- [ ] The offer and KYC state are reset using authorized test tooling.

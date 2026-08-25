# JMS-JHP-003 — Two-persona cash-on-delivery loop

> Result: **NOT RUN**
> Owner: Scenario CTO + Mobile QA
> Last verified: Never

## Contract

| Field | Value |
|---|---|
| Source | Current request, offer, chat, tracking, OTP, receipt, and rating routes |
| Personas | One synthetic customer and one approved synthetic Jeeber |
| Priority / gate | P0 / Release candidate |
| Mutation class | R3 — request, offer, chat, delivery, and rating lifecycle |
| Privacy class | Masked synthetic content only; two-device receiver proof required |
| Automation | Composite candidate; existing jm-024–034 and jm-045–051 provide partial flows |
| Clarity screens | request-summary, waiting-no-coverage, offer-review, order-summary, chat-detail, jeeber-active-delivery, live-tracking, otp-handover, delivered-receipt, feedback, mutual-rating |

## Cash-only invariant

The customer hands cash directly to the Jeeber. The test may acknowledge that
handover using synthetic values, but it must not capture a card, call a payment
gateway, create an electronic settlement, issue a money-moving refund, or move
real cash. A benign success response for money that did not move is a failure.

## Preconditions

- [ ] Two isolated synthetic adult accounts are available on separate devices
      or independently controlled sessions.
- [ ] The Jeeber account is KYC-approved and inside the synthetic service area.
- [ ] Chat, delivery, and push fixtures use a unique non-sensitive run nonce.
- [ ] Both accounts have no open request, offer, chat, or delivery before seeding.
- [ ] State transitions and cleanup are explicitly authorized for the test lane.

## Acceptance scenario

```gherkin
Given an eligible synthetic customer and an approved synthetic Jeeber
When they complete one request from offer acceptance through physical cash handover
Then both devices show one consistent delivered order, receipt, chat, and rating lifecycle
And no electronic payment or duplicate state transition occurs
```

## End-to-end checklist

| # | Actor | Action | Expected result |
|---:|---|---|---|
| 1 | Customer | Create one request with the run nonce | Request is open exactly once |
| 2 | Jeeber | Open feed and submit one offer | Customer receives that offer; Jeeber sees pending offer |
| 3 | Customer | Accept the offer once | Other offers close; one delivery and one conversation are created |
| 4 | Both | Open chat and exchange a harmless nonce message | Each message appears once on the receiving device with correct receipt state |
| 5 | Jeeber | Advance Ordered → Picked → InTransit | Customer tracking and order summary match each transition |
| 6 | Both | Background/resume during active delivery | Tracking and chat recover without duplicate subscriptions or writes |
| 7 | Jeeber | Advance to AtDoor | Customer sees handover/OTP readiness; no Delivered state yet |
| 8 | Customer | Reveal the single-use handover OTP privately | Code is never shown in logs, screenshots, or Clarity evidence |
| 9 | Jeeber | Verify OTP once | Delivery becomes eligible for completion; replay is rejected |
| 10 | Both | Simulate direct cash handover with synthetic amount | UI acknowledges direct cash handover; no electronic payment call occurs |
| 11 | Jeeber | Mark delivered once | Both devices resolve to Done/delivered exactly once |
| 12 | Customer | Open receipt | Goods amount, delivery fee, total cash, proof, and status agree with delivery data |
| 13 | Both | Submit blind ratings | Each rating appears only after the product reveal rule is satisfied |

## Required complex variants

- [ ] Accept race between two customer sessions.
- [ ] Jeeber withdraws before acceptance.
- [ ] Request expires while the offer sheet is open.
- [ ] Chat WebSocket disconnect, queued retry, replay, and duplicate frame.
- [ ] Push cold-start, warm-start, foreground suppression, and duplicate delivery.
- [ ] Cancellation before pickup and too-late cancellation after pickup.
- [ ] Wrong/expired OTP, lockout, offline verify, lost response, and replay.
- [ ] Escalation/dispute while tracking and chat are open; evidence/status only,
      with no money-moving refund behavior.
- [ ] Arabic RTL and accessibility on both devices.
- [ ] Clarity grant/revoke and process restart during the journey using only
      synthetic content.

## Pass criteria and cleanup

- [ ] Customer, Jeeber, and server read-backs show the same final delivery ID alias and Done status.
- [ ] Exactly one accepted offer, delivery, conversation, OTP consumption, receipt, and rating per actor exist.
- [ ] No endpoint/configuration associated with electronic payment is called.
- [ ] All screenshots and logs pass privacy review; OTP and chat text are absent or sanitized.
- [ ] The complete synthetic graph is reset without touching shared/live data.

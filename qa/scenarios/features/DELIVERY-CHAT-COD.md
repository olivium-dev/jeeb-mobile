# Delivery, chat, handover, and COD scenarios

> Suite result: **NOT RUN**
> Payment rule: direct physical cash only; no electronic payment or refund path.

> Owner: Mobile QA + Scenario CTO for paired paths
> Last verified: Never
> Source / AC: [current router](../../../lib/core/router/app_router.dart), current
> delivery/chat/receipt code, workspace COD policy, and the JM flows named per row

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the Given clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); reconcile
both actors and server state, reset the isolated delivery graph, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Persona / mutation | Given / When / Then | Source / automation | Required variants and evidence |
|---|---|---|---|---|---|
| JMS-DEL-001 | P0 / Smoke | Customer + Jeeber / R0 | Given one accepted offer, when both open detail/summary, then order, actors, amounts, status, and chat/tracking entries agree without exposing private route data. | jm-031 | Cold deep link; missing extra; stale request ID vs delivery ID; EN/AR |
| JMS-DEL-002 | P0 / Regression | Both / R2 | Given an accepted conversation, when one harmless nonce message is sent, then it appears once on receiver with ordered delivery/seen receipts. | jm-025 partial | Empty/history; text/image/voice permission; optimistic failure/retry; sender and receiver proof |
| JMS-DEL-003 | P0 / Regression | Customer / R0 | Given a live delivery, when statuses advance, then tracking shows Ordered, Picked, InTransit, AtDoor, and Done once and stops polling on terminal states. | jm-032 partial | Canonical/legacy aliases; cancelled; failed/escalated; background; route ID resolution |
| JMS-DEL-004 | P0 / Regression | Jeeber / R3 | Given an accepted assigned delivery, when legal milestones advance, then each transition succeeds once and illegal/out-of-order/other-Jeeber actions are rejected. | jm-051 partial | Double tap; 403/409/422; cancellation underneath; concurrent device; lost response |
| JMS-DEL-005 | P1 / RC | Jeeber / R3 | Given AtDoor completion prerequisites, when a synthetic proof photo/note is added, then only approved non-sensitive media is linked and completion remains gated by OTP/COD rules. | jm-051 partial | Permission denial; upload timeout; corrupted/large file; process death; evidence masking |
| JMS-DEL-006 | P0 / RC | Customer + Jeeber / R3 | Given AtDoor delivery, when a valid single-use handover OTP is verified, then it is consumed once and wrong/expired/replayed codes never complete delivery. | OTP plan; screen automation partial | Offline; lockout; cross-delivery code; lost success response; no OTP in logs, screenshots, Clarity |
| JMS-DEL-007 | P0 / RC | Both / R3 | Given verified handover, when direct cash exchange is acknowledged, then customer total and Jeeber receipt state agree and no electronic payment system is contacted. | Policy/static tests partial | Zero/fraction/large display values; locale formatting; no card fields; no fake refund success |
| JMS-DEL-008 | P0 / Regression | Customer / R0 | Given Done delivery, when receipt opens online or from safe cache, then goods, delivery fee, total cash, proof, timestamp, and status match authoritative data. | jm-033 | Offline cache; share/export privacy; Arabic; large text; no customer commission line |
| JMS-DEL-009 | P0 / Regression | Customer/Jeeber / R3 | Given delivery phase allows or forbids cancellation, when cancel is confirmed, then exact legal transition occurs once or clear too-late recovery is shown. | Cancellation flows | Before/after pickup; 409/422/429; duplicate; offline; other device convergence |
| JMS-DEL-010 | P1 / Regression | Both / R2 | Given Done delivery, when feedback/mutual ratings are submitted, then blind reveal, one-rating-per-actor, and profile aggregation rules hold. | jm-034 | Skip; duplicate; abusive text; offline; route compatibility redirect; other actor not rated yet |
| JMS-DEL-011 | P0 / RC | Both / R3 | Given failed/unsafe delivery, when escalation with synthetic evidence is submitted, then status becomes FailedNeedsEscalation and active actions stop. | jm-060 partial | Upload failure; duplicate; support handoff; chat/tracking already open; evidence privacy |
| JMS-DEL-012 | P0 / RC | Both / R2–R3 | Given a dispute exists, when status/evidence/support are viewed or resolved, then both actors see consistent non-money status and no gateway refund is attempted. | jm-060, jm-065 | Open/resolved/rejected; concurrent status update; offline; support link; caller that tries money movement must fail visibly |

## COD no-go checklist

- [ ] No card, bank, wallet-payment, or electronic checkout control appears.
- [ ] No payment-gateway base URL, client binding, route, or network call is introduced or exercised.
- [ ] No refund is reported successful when no money moved.
- [ ] Customer cash total excludes platform fee/commission information intended for Jeeber accounting.
- [ ] Test values are synthetic; no real cash is exchanged.

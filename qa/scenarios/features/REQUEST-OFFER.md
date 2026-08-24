# Customer request and offer scenarios

> Suite result: **NOT RUN**

> Owner: Mobile QA
> Last verified: Never
> Source / AC: [current router](../../../lib/core/router/app_router.dart),
> [request lifecycle matrix](../../../docs/sprints/sprint-009/scenario-matrix.md),
> and the JM flows named per row

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the Given clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); read back
request/offer state, reset the isolated graph, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Persona / mutation | Given / When / Then | Source / automation | Required variants and evidence |
|---|---|---|---|---|---|
| JMS-REQ-001 | P0 / Smoke | Customer / R2 | Given a valid synthetic description, type, and location, when submit completes, then exactly one request reaches waiting/review with preserved details. | jm-024 | All request types; min/max text; duplicate tap; receiver/server read-back |
| JMS-REQ-002 | P1 / Regression | Customer / R1–R2 | Given microphone permission and a synthetic utterance, when voice/dictation is recorded, transcribed, reviewed, and confirmed, then editable text reaches request summary once. | Existing voice flows partial | Denied permission; empty/noisy clip; timeout; cancel/re-record; Arabic mixed text |
| JMS-REQ-003 | P0 / Regression | Customer / R1–R2 | Given current, saved, or captured synthetic location, when pickup/drop-off is confirmed, then labels/coordinates remain correctly paired and unresolved address cannot silently commit. | jm-049, jm-050 plus location flows | Permission denied; GPS off; reverse-geocode delay; RTL coordinates; edit and back |
| JMS-REQ-004 | P0 / Regression | Customer / R2 | Given an open request with no offer, when the window waits, expires, retargets, or cancels, then no dead end or phantom active request remains. | jm-026, jm-030 | Timer boundary; background; clock change; offline cancel; API contract gap marked BLOCKED not PASS |
| JMS-REQ-005 | P0 / Regression | Customer / R3 | Given one or more valid offers, when offer review and one acceptance complete, then exactly one offer wins and one delivery/conversation is created. | jm-027–029 | Sort/order; withdrawn offer; missing profile; double tap; second-device read-back |
| JMS-REQ-006 | P0 / RC | Two customer sessions / R3 | Given two acceptance attempts race, when both submit, then one succeeds and the loser gets exact closed/not-pending behavior without duplicate delivery. | Scenario matrix + unit/seam coverage | 409 discriminator; 404; 410 expiry; lost response; retry with idempotency |
| JMS-REQ-007 | P1 / Regression | Customer + Jeeber / R2–R3 | Given pending offers exist, when customer cancels before acceptance, then customer and each Jeeber converge on cancelled/superseded state. | jm-030 partial | No offers vs offers; backend request-cancel contract absence is BLOCKED; push/poll convergence |
| JMS-REQ-008 | P1 / RC | Customer / R0 | Given waiting/review is open, when app is killed, upgraded, deep-linked, or restored offline, then current server state wins and stale actions stay disabled. | Partial router tests | Expired, cancelled, accepted elsewhere, malformed/missing route payload, no private route parameter in Clarity |

## Suite checklist

- [ ] Every write uses a unique non-sensitive run nonce.
- [ ] Request creation and offer acceptance are verified on a receiving/server surface.
- [ ] Timer fixtures are relative to current time, never hard-coded past dates.
- [ ] A missing backend endpoint or fixture is BLOCKED, not simulated as success.
- [ ] Cleanup removes the entire request/offer graph from the isolated lane.

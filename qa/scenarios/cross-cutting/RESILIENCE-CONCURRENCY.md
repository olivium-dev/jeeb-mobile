# Resilience, retry, and concurrency scenarios

> Suite result: **NOT RUN**

> Owner: Mobile QA
> Last verified: Never
> Source / AC: [request lifecycle matrix](../../../docs/sprints/sprint-009/scenario-matrix.md),
> current lifecycle/connectivity code, and the linked feature scenario contract

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the fault clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); reconcile
all actors/server state before retry, reset isolated fixtures, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Fault and action | Required outcome | Evidence |
|---|---|---|---|---|
| JMS-RES-001 | P0 / Regression | Cold-launch offline with prior safe cache | Honest offline UI appears; protected stale actions are disabled; no infinite spinner | Screen + zero unintended calls |
| JMS-RES-002 | P0 / RC | Disconnect during request creation or KYC upload | App reports unknown/failure honestly, queries authoritative state before retry, and never duplicates write | Before/after entity count + idempotency key alias |
| JMS-RES-003 | P0 / RC | Two customer sessions accept the same offer/request concurrently | One winner; one exact conflict/closed result; one delivery and conversation | Both-device timestamps + server read-back |
| JMS-RES-004 | P0 / RC | Chat WebSocket drops around an optimistic send | Outbox retains one client message ID; reconnect/replay orders one receiver message; receipts resume | Sender + receiver nonce evidence |
| JMS-RES-005 | P0 / RC | Network is lost after OTP/completion commits but before response | App reconciles status before retry; OTP remains one-time; delivery completes once | Transition history + no duplicate call effect |
| JMS-RES-006 | P0 / Regression | 400, 401, 403, 404, 409, 410, 422, 429, 5xx, timeout, malformed body | Typed recovery is correct; bounded retry honors Retry-After; no illegal state change | Failure classification + final read-back |
| JMS-RES-007 | P0 / RC | detached, resumed, inactive, hidden, paused, resumed across request/chat/tracking/KYC/Clarity | Pollers, sockets, GPS, timers, and capture pause/resume exactly once and recover without leaks | Lifecycle timestamps + network/resource deltas |
| JMS-RES-008 | P1 / RC | Wi-Fi ↔ cellular, captive portal, DNS failure, TLS failure | Connection state is honest; writes wait/reconcile; no insecure fallback | Network profile + call trace |
| JMS-RES-009 | P1 / Regression | Device clock/time zone changes around OTP, offer window, countdown, and polling | Server time/absolute deadlines win; expired actions remain disabled; no timer storm | Before/after clock + server state |
| JMS-RES-010 | P1 / RC | Low memory/storage, permission revoke, app upgrade, preference migration | App fails recoverably, cleans temp media, preserves valid session/config, and does not leak data | OS/resource record + post-upgrade state |

## Combined-fault ladder

- [ ] Happy path, no fault.
- [ ] One transport fault before the write.
- [ ] One transport fault during the write.
- [ ] Unknown result after server commit.
- [ ] Process death before UI receives the result.
- [ ] Second device changes the same entity during recovery.
- [ ] Retry uses the same idempotency identity or proves why the operation is read-only.
- [ ] Final server, customer, Jeeber, and UI states reconcile.

Never solve an unknown result by blindly tapping the write action again.

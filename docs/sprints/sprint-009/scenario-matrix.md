# Sprint-009 — Request-lifecycle scenario matrix (client-side)

Lane 2, cycle 2 (`feat/request-scenarios`, base `fe053b9` integration/cycle-1).
Owner backlog item: **"cover ALL scenarios of all requests"**.

Vocabulary baseline (gateway `feat/status-normalization`, ADR-002):

* Canonical delivery statuses: `Ordered / Picked / InTransit / AtDoor / Done /
  Cancelled / FailedNeedsEscalation` (+ reserved request-lifecycle `Expired`).
* `DeliveryStatusAlias` dual-read: `accepted⇒Ordered`, `picked_up⇒Picked`,
  `heading_off⇒InTransit`, `at_door⇒AtDoor`, `delivered⇒Done`, `rated⇒Done`,
  `disputed⇒FailedNeedsEscalation`, `cancelled⇒Cancelled`, `expired⇒Expired`.
* Accept-race conflict: gateway answers **409** with a ProblemDetails body whose
  `type`/code discriminates: `already-accepted`, `offer-not-pending`,
  `request-not-acceptable`, upstream `request_not_open`,
  `too-many-active-deliveries`, `same-delivery-role-violation`
  (`OffersController.cs`, `RequestNotOpen409FidelityTests.cs`). Expiry on the
  accept leg is **410** `offer-expired`.

## Matrix

| # | Scenario | Current client behavior | Gap | Fix (this branch) |
|---|----------|-------------------------|-----|-------------------|
| 1 | Customer cancels while open, **no offers** (waiting screen) | `NoOfferTimeoutScreen` → `waiting_cancel_cta` → `CancelRequestSheet` (JM-030, free per D69). `DioCancelRequestRepository` posts `/v1/delivery/cancel`; 404/422 swallowed as benign no-op, only hard transport errors block; routes home. | Server-side release relies on a delivery-keyed cancel; a still-pending request has no delivery so the cancel is locally authoritative only. **Backend contract gap** (needs `POST /requests/:id/cancel`), already flagged in the repo docs. | None client-side (documented; deferred to gateway lane). |
| 2 | Customer cancels while open, **with pending offers** (offer-review list) | `offer_review_cancel_cta` on `ClientOffersScreen` → same `CancelRequestSheet`; CTA hidden once `!requestIsOpen`. | Same backend contract gap as #1. Jeebers' pending offers are superseded server-side (gateway cycle-1 polish) — jeeber list reflects via `offer_lifecycle` push + poll. | None client-side. |
| 3 | Customer cancels **after accept** | Distinct post-accept flow `lib/features/cancellation/` (reason picker, may charge fee). `DioCancellationRepository` posts `/v1/deliveries/:id/cancel`; 409/422 → typed `CancellationTooLateException`, 429 → rate-limit with `retryAfter`; gateway stamps the canonical `Cancelled` + trigger. | Covered; cubit renders typed failures. | None. |
| 4 | Request **expires** (window elapses, no accept) | Waiting screen: clock-driven flip to `waiting_no_coverage_state` with re-target + cancel CTAs (never a dead-end). Offer-review list: `OfferWindowTimer` flips to expired styling and every accept CTA is inerted (`windowExpired`). Offers superseded server-side. | Accepting after expiry returns **410** → was mapped to `requestNotOpen` copy; load of a dead request renders closed banner. Acceptable. Home/history map `expired⇒cancelled` bucket correctly. | None (behavior verified). |
| 5 | **Jeeber withdraws** offer pre-accept | `PendingOfferRow` withdraw → `DELETE /v1/offers/:offerId`; 204/404 treated as gone (idempotent), 403/409 keep the row. Customer side: withdrawn offers filtered out of the review list (`_liveStatuses`). | Covered. | None. |
| 6 | Customer **declines / ignores** an offer | No explicit decline verb in the product (D71: accepting one offer closes the rest; ignoring lets the window lapse → #4). | By design; no dead-end. | None. |
| 7 | **Accept race** — second accept attempt → 409 (`request_not_open` / `already-accepted` / `request-not-acceptable`) | `DioOffersRepository._rethrowAccept` mapped **every 409 → `offerNotPending`** ("This offer is no longer available") regardless of the body discriminator; worse, **`OfferAcceptSheet` never rendered `state.error` at all** — a failed accept just stopped the spinner silently and the user was left staring at a sheet that did nothing. | **P0 dead-end / wrong copy.** | (a) Discriminate the 409 ProblemDetails body: request-level closure codes (`request_not_open`, `request-not-acceptable`, `already-accepted`, `not-open`) → `OffersFailure.requestNotOpen` → "This request is no longer open."; offer-level codes stay `offerNotPending`. 404 on accept → `requestNotOpen` instead of generic unknown. (b) Render an inline OMDS error banner in the accept sheet (`offer_accept_error`) with the mapped l10n copy; confirm stays retryable, cancel returns to the list. |
| 8 | **Jeeber views expired/cancelled request** (push tap / cold deep link) | `JeeberRequestDetailLoader`: feed fetch miss → probe active delivery → redirect to active-delivery when ACCEPTED (cycle-1); otherwise `JeeberRequestUnavailableScreen`. That screen was a stub: **hard-coded English** "Request unavailable" / "Back" (bypassing l10n/RTL) and a bare centered `Text`. | **P1**: not a dead-end but un-localized, off-design, and gives no forward path other than back. | Rebuilt on `OmdsEmptyState` with l10n keys (`requestUnavailableTitle` / `requestNoLongerAvailable` / `requestUnavailableBrowseCta`), semantics id `jeeber_request_unavailable`, and a "Browse other requests" CTA (existing `onBack` → feed). |
| 9 | **Customer tracking of a cancelled delivery** (jeeber/admin cancels post-accept, or row reads terminal `Cancelled`) | `DeliveryTrackingInfo._parseStage` had **no case for `Cancelled`/`Expired`/`FailedNeedsEscalation`** → default `ordered`: the tracking screen showed a live "Ordered" stepper forever and kept polling a dead delivery. | **P1 misleading dead-end.** | Added a `TrackingLifecycle {active, cancelled, failed}` axis parsed from the raw status; cubit stops polling on `cancelled` and the screen renders a graceful terminal state (`tracking_cancelled_state`, `deliveryCancelledBanner` copy + subtitle) instead of a live stepper. `failed` (FailedNeedsEscalation) keeps the active view (dispute CTA is the correct affordance; admin-resolvable). |
| 10 | **Delivery status rendering — canonical + legacy aliases (customer)** | `_parseStage` handled `picked_up`, `at_door`, `delivered/done`, but **`heading_off` → `ordered`** (should be InTransit per alias table) and **`rated` → `ordered`** (should be Done). | **P1** wrong stepper position on legacy rows. | Alias-table-complete parse: `heading_off⇒inTransit`, `rated⇒delivered`, plus the lifecycle axis of #9. |
| 11 | **Delivery status rendering — canonical + legacy aliases (jeeber)** | `JeeberDeliveryStatus.fromApi` normalizes by stripping underscores but then had no `pickedup` / `headingoff` cases: legacy **`picked_up` and `heading_off` both parsed to `ordered`**, re-rendering an in-flight delivery at step 1. `disputed`/`FailedNeedsEscalation` also fell to `ordered`, resurrecting an escalated delivery as fresh. | **P1** wrong stage on jeeber active list. | Added `pickedup⇒picked`, `headingoff⇒inTransit`, `disputed`/`failedneedsescalation⇒done` (drops out of the in-flight filter — it is out of the jeeber's hands, admin-resolvable). |
| 12 | Home / order-history bucketing of every canonical status | `dio_client_home_repository._mapDeliveryStatus` and `order_summary` parse the full canonical + legacy set (`Done/delivered/rated → delivered`, `cancelled/expired → cancelled`, `FailedNeedsEscalation → accepted` i.e. still-in-progress). BUT `test/features/home_client` has **12 pre-existing failures at fe053b9** — the cycle-1 merge kept the S10/S11/S12/S13 regression tests while dropping parts of their lib fixes (e.g. S12 `Ordered ⇒ accepted` trackability reverted to `searching` by the later bucketing rewrite; S11 `status=active` merge dropped). | **Known merge-regression cluster.** The parallel `fix/debt-security` lane (90e093a, today) already re-applied the S11 slice in this exact file and documents the remaining 8 as the same class. | **Deferred to that lane / consolidation** — double-editing `dio_client_home_repository.dart` from two live lanes would guarantee an integration conflict. Verified none of the 12 are introduced by this branch (identical set with this branch's commits present or absent). |
| 15 | Customer opens tracking from home (S9: request id vs server delivery id) | The cycle-1 merge **dropped the S9 router helper `resolveTrackingDeliveryId` and the In-Progress CTA's `?deliveryId=` threading while keeping their tests** — `tracking_delivery_id_nav_test.dart` did not even compile at fe053b9, and tracking re-opened by request id 404s ("Delivery not found"). | **P1 regression at base.** | Restored on this branch: pure `resolveTrackingDeliveryId` (query param wins over path id) + the `live-tracking` route wiring + `_navigateToTracking` threading `?deliveryId=` (mirrors `_navigateToChat`). The 5 S9 tests compile and pass again. |
| 13 | Jeeber submits offer into a closed/expired request (409/404/410) | `DioOfferSubmissionRepository` discriminates the 409 body: offer-cap → keep composer + withdraw hint; `request-not-open-for-offers` and other 409/404/410 → `requestGone` → bounce to feed. 402 → insufficient-balance sheet. | Covered (sprint-009 Lane E). | None. |
| 14 | Jeeber advances a delivery that was cancelled under them (bad transition) | `DioActiveDeliveryRepository` maps 422/400 with `otp_required` to the OTP gate, other bad transitions to typed failures; terminal `Cancelled` rows collapse to `done` and drop from the active list on next poll. | Acceptable. | None. |

## Summary

* **15 scenarios audited; 7 gaps found** (#7 accept-race dead-end + wrong copy,
  #8 unlocalized unavailable stub, #9 cancelled-delivery live stepper, #10
  customer legacy aliases, #11 jeeber legacy aliases, #12 home_client
  merge-regression cluster, #15 S9 tracking-id regression at base).
* **6 fixed on this branch** (#7, #8, #9, #10, #11, #15); **3 deferred**:
  #1/#2 request-keyed pre-accept cancel endpoint (backend contract, gateway
  lane) and #12 home_client cluster (actively owned by the parallel
  `fix/debt-security` lane in the same file — fixing it twice would collide at
  integration).
* Fix constraint honored: OMDS components only, canonical vocab +
  `DeliveryStatusAlias` table as the single source of truth, no chat/** or
  core/theme/** touches.

# Gap Analysis — Domain: `jeeber-fulfil-money`

> Principal UX analyst gap map. Domain = JEEBER fulfilment + money. 8 blueprint screens.
> Authoritative spec: `jeeb-mind-map/web/blueprint.json` + `web/src/screens/_data/<id>.json`.
> Decisions: `jeeb-mind-map/docs/07_DECISIONS_LOG.md` + `flow-review/99_LEAD_SYNTHESIS.md §5`.
> Flutter: `jeeb-mobile/lib/features/*`, router `lib/core/router/app_router.dart`.
> Mock: `jeeb-mock-backend/src/services/*`.
> Generated 2026-06-18. Cite-by-id. No invented product decisions.

---

## Cross-cutting finding (read first): the wallet/ledger subsystem does not exist

Four of the eight screens in this domain (`wallet-hub`, `wallet-activity-list`,
`wallet-charge-info`, `transaction-detail`) are the **fee-only wallet** subsystem (D41).
In Flutter **none of them exist**: `/wallet` is a single inline `Scaffold('Wallet — coming
soon')` (`app_router.dart:808-816`, the T-MOB-035 placeholder). There is **no header wallet
chip** (D33) anywhere in the shell (`shell_screen.dart` has only the 3 nav tabs, no header).

In the mock backend the gap is just as deep: **`wallet-service.ts` is earnings-only**. Its
mobile routes are `GET/POST /v1/jeeb/earnings*` (lines 11, 38, 51) — there is **no balance,
no reserve, no ledger/activity, no transaction-by-id, no charge/topup, no gift** endpoint.
`offer-service.ts` (submit/list/edit/withdraw/accept) contains **no fee/reserve/capture/release
logic at all** — searching `reserve|wallet|balance|ledger|capture|release|fee` in
`offer-service.ts` returns nothing. So the 10%-reserved-on-offer / captured-on-win /
released-on-loss ledger that drives `wallet-hub`, `wallet-activity-list`, and
`transaction-detail` (D1/D37) **has no data source**.

=> A foundation work item must add a wallet/ledger service to the mock (balance + typed
ledger rows + transaction detail) and wire offer submit/accept/withdraw to emit reserve/
capture/release rows, BEFORE the three wallet ledger screens can be wired to `:4010`.
This is flagged as `mock_endpoints` on each affected screen below as **MOCK-MISSING**.

Synthesis S-10 already records the affordability bug: `wallet-hub` must show D43 affordability
state (not a capacity number) and block money actions offline (D35) — neither can be honored
by a "coming soon" stub.

---

## Per-screen gap table

### 1. `jeeber-mark-delivered` — Fulfilment Milestones / Mark Delivered (role: jeeber)

- **Status: PARTIAL (divergent flow).**
- **flutter_target:** extend `ActiveDeliveryJeeberScreen` (route `/jeeber/deliveries/:id/active`,
  `lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart`) + its
  `DeliveryStatusStepper` widget; plus the chat-side `ConfirmDeliveryActionSheet`
  (`lib/features/chat/presentation/widgets/confirm_delivery_action_sheet.dart`).
- **Gap:** The 4-step imperative milestone stepper (ordered→picked→inTransit→atDoor→done, D70)
  IS built in `delivery_status_stepper.dart` + `jeeber_delivery_status.dart`, advancing via
  `POST /delivery-service/v1/delivery/status/transition`. BUT three blueprint contract
  elements are missing: (a) **proof-of-delivery photo capture (D3)** — the stepper has no
  photo step and `ActiveDeliveryCubit.advanceStatus()` sends only from/to, no proof; the
  delivery_status_transition has no proof payload; (b) **optional note** field on mark-delivered;
  (c) the **"customer will be asked to confirm receipt + pay cash"** confirmation copy. Also a
  **navigation divergence**: on `done` the screen routes to **OTP handover**
  (`onOpenOtp → /orders/$id/otp?mode=jeeber`, `app_router.dart:759-761`), NOT to
  `feedback-rate-delivery` as the blueprint's only outgoing edge requires — OTP is the chosen
  D3 proof mechanism but the post-completion edge to the mandatory Jeeber rating is not wired
  from this screen.
- **nav_edges_missing:** `jeeber-mark-delivered -> feedback-rate-delivery` (on completion,
  blueprint's single outgoing edge — currently lands on OTP, then rating is not chained).
- **mock_endpoints:** `POST /delivery-service/v1/delivery/status/transition` (exists; needs proof
  field for D3), `GET /delivery-service/v1/delivery/:deliveryId` (exists). MOCK-MISSING: a proof
  upload sink for the delivery photo (D3) — no endpoint accepts a proof image today.
- **decisions:** D70 (imperative milestones — DONE per Wave 6), D3 (two-sided + proof — NOT
  honored: photo missing), D56 (mandatory rating on completion — edge not chained here).
- **complexity:** M. **priority:** P0 (terminal fulfilment step; D3 proof + the completion→rating
  edge are core-journey blockers).

### 2. `delivery-order-chat` — Delivery Chat with Customer (role: jeeber)

- **Status: EXISTS.**
- **flutter_target:** `/chat/:id` → `ChatDetailScreen` → role-aware `ChatScreen`
  (`lib/features/deep_link_targets/chat_detail_screen.dart`,
  `lib/features/chat/presentation/chat_screen.dart`). Jeeber variant resolved via `RoleCubit`.
- **Gap:** Real WhatsApp-style thread with pinned context, composer (text/attach/mic/send),
  PRICE\TIME offer entry, and a Jeeber-only **"Start delivery" CTA** on the
  `OfferAcceptedBanner` (`onStartActiveDelivery → /jeeber/deliveries/$id/active`). This matches
  the screenshot contract (`delivery-order-chat.json`). Minor: blueprint marks the only outgoing
  edge as `delivery-order-chat -> jeeber-mark-delivered` ("advance order / send milestone
  action"); Flutter advances milestones partly here via `ConfirmDeliveryActionSheet`
  (picking/heading-off) and partly via the active-delivery screen — the milestone surface is
  split. Acceptable per D83 (`order-chat ≠ delivery-order-chat`) but the edge should resolve to
  the active-delivery milestone screen.
- **nav_edges_missing:** none structurally (the milestone edge is satisfied via "Start delivery"
  → active-delivery, which hosts the D70 stepper). Confirm in nav plan that the chat→milestone
  edge points at `/jeeber/deliveries/:id/active`.
- **mock_endpoints:** `GET /chat-service/v1/chat/jeeb/conversations/:id`,
  `.../by-request/:requestId`, `GET .../messages?since=`, `POST .../messages`,
  `GET /delivery-service/v1/requests/:requestId` (header title), `GET /user-management/users/:id`,
  WS `jeeb:chat:<convId>` (all exist).
- **decisions:** D83 (distinct from customer order-chat), D70 (milestone surface), D36 (auto STT/
  image-desc on voice/image — verify present).
- **complexity:** S. **priority:** P1 (exists; needs only nav-edge confirmation + parity polish).

### 3. `earnings-fees-dashboard` — Earnings & Fees Dashboard (role: jeeber)

- **Status: DIVERGENT.**
- **flutter_target:** `EarningsDashboardScreen` hosted by `EarningsTab` (jeeber tab 2,
  `shell_screen.dart:109-115`) — NOT a standalone route.
  `lib/features/earnings/presentation/earnings_dashboard_screen.dart`.
- **Gap:** A real earnings screen exists (period pills today/week/month, summary card,
  stats row, per-delivery breakdown, PDF export, settlement link). BUT it frames the economics
  as **gross / commission / net-payout** (`EarningsSummary.totalEarnings/commission/netPayout`,
  `earnings_summary.dart`) — a classic platform-takes-a-cut model. The blueprint contract
  (D41/D44) is the **fee-only** model: "Total cash earned (net, off-wallet COD)" + "Total
  platform fees paid (captured 10%)" + "Net-per-offer running totals" + "member-since". The
  Flutter copy (`earningsGross`/`earningsCommission`/`earningsNet`) does not express the
  off-wallet-COD framing (the Jeeber is paid cash directly; only the 10% fee moves through the
  wallet). Also **missing the two blueprint outgoing edges**: `-> wallet-hub` ("back to wallet")
  and `-> wallet-activity-list` ("view full activity") — the screen currently only links
  forward to `/jeeber/settlement`, and there is no wallet to link back to.
- **nav_edges_missing:** `earnings-fees-dashboard -> wallet-hub`, `earnings-fees-dashboard ->
  wallet-activity-list` (both blocked until wallet screens exist).
- **mock_endpoints:** `GET /wallet-service/v1/jeeb/earnings?jeeberId=` (exists; ETag-cached),
  `GET /wallet-service/v1/jeeb/earnings/export?jeeberId=` (exists). NOTE app calls
  `/v1/wallet/jeeb/earnings*` (`dio_earnings_repository.dart:19-20`) while the mock mounts
  `/wallet-service/v1/jeeb/earnings*` — confirm the rewrite map resolves this (path-shape gap).
- **decisions:** D44 (net-per-offer + earnings/fees dashboard), D41 (fee-only/no withdrawals),
  D37 (exact 10%), D33 (wallet placement / chip).
- **complexity:** M. **priority:** P1 (exists but mis-framed vs the fee-only model + missing the
  wallet back-edges).

### 4. `wallet-hub` — Wallet Hub (role: jeeber)

- **Status: MISSING (stub).**
- **flutter_target:** NEW screen replacing the `/wallet` "coming soon" stub
  (`app_router.dart:808-816`); register a real `wallet` feature
  (`lib/features/wallet/...`). Also add the **persistent header wallet chip** (D33) entry-point
  in the shell.
- **Gap:** Everything. Need: available balance + gift-credit badge (usable after KYC, D42),
  **affordability state card** (D43 — "enough to bid" / "top up", NOT a capacity number; fixes
  S-10 false-green bug), reserved-now line (sum of live per-offer reserves, D1), '+ Top up'
  primary (routes to `wallet-charge-info` since there is no in-app payment, D92/D93), 'How fees
  work' explainer, typed activity preview list, KYC-pending banner, and state variants
  (healthy/low/empty/all-reserved, D30).
- **nav_edges_missing:** `wallet-hub -> wallet-charge-info`, `wallet-hub -> offer-kyc-gate`,
  `wallet-hub -> earnings-fees-dashboard`, `wallet-hub -> wallet-activity-list`; plus inbound
  header-chip edges from `customer-orders-home`, `customer-profile`, `delivery-requests` (D33)
  and from `notifications-list` (wallet rows deep-link, D84).
- **mock_endpoints:** MOCK-MISSING (all): a wallet `GET balance/affordability` + `GET reserves`
  endpoint. Reuse `GET /wallet-service/v1/jeeb/earnings` for the "Earnings & fees" link target.
- **decisions:** D1 (reserve 10%), D41 (fee-only), D43 (affordability state not capacity), D44
  (earnings link), D42 (gift credit post-KYC), D33 (header chip), D92/D93 (no in-app top-up),
  D35 (block money actions offline), D30 (full state set).
- **complexity:** L. **priority:** P0 (hub for the entire money subsystem + 4 outgoing edges; the
  affordability state gates whether a Jeeber believes they can offer — S-10 P0 bug).

### 5. `wallet-activity-list` — All Wallet Activity (role: jeeber)

- **Status: MISSING.**
- **flutter_target:** NEW route (e.g. `/wallet/activity`) + screen in the new `wallet` feature.
- **Gap:** Full ledger: infinite scroll + skeletons (D73), typed rows (Reserve / Fee[won] /
  Released[lost/withdrawn/expired] / Refund / Penalty / Top up / Gift) each with amount, sign,
  type icon, and order/source reference; tap row → `transaction-detail`.
- **nav_edges_missing:** `wallet-activity-list -> transaction-detail`,
  `wallet-activity-list -> wallet-hub` (back); inbound `wallet-hub -> wallet-activity-list` and
  `earnings-fees-dashboard -> wallet-activity-list`.
- **mock_endpoints:** MOCK-MISSING: `GET wallet ledger?jeeberId=&cursor=` (paginated typed
  rows). No such endpoint exists today (wallet-service is earnings-only).
- **decisions:** D41 (fee-only ledger scope), D1/D37 (reserve/capture exact 10%), D2 (refund/
  penalty types from disputes), D30/D73 (skeletons + infinite scroll).
- **complexity:** M. **priority:** P1 (depends on wallet-hub + the new ledger endpoint).

### 6. `wallet-charge-info` — How to Add Funds (role: jeeber)

- **Status: MISSING.**
- **flutter_target:** NEW route (e.g. `/wallet/charge-info`) + a static info screen.
- **Gap:** Static, no-payment instructional screen (D92/D93): "charge your wallet at an
  authorized store; give phone/ID; pay cash; store credits server-side; balance updates
  automatically; 10% fees deducted from pre-charged balance". **No** card, amount entry, or
  charging-point directory (Q18/Q19/Q19b resolved — see synthesis §5). Single back edge.
- **nav_edges_missing:** `wallet-charge-info -> wallet-hub` (back); inbound from `wallet-hub`,
  `offer-insufficient-balance`, `onboarding-funding`, `kyc-pending-status` ("how to add funds"
  CTAs) — those inbound CTAs live outside this domain but must target this route.
- **mock_endpoints:** none (purely static informational screen — no network call).
- **decisions:** D92 (no in-app payment / store charging), D93 (removed top-up screens, static
  info), D1/D41 (fees deducted from pre-charged balance).
- **complexity:** S. **priority:** P1 (static; cheap; unblocks the '+ Top up' / 'how to add funds'
  CTAs across wallet, insufficient-balance, funding, and KYC-pending).

### 7. `transaction-detail` — Transaction Detail (role: jeeber)

- **Status: MISSING.**
- **flutter_target:** NEW route (e.g. `/wallet/transactions/:id`) + screen in the `wallet` feature.
- **Gap:** Per-type detail with variant copy: Reserve(pending) / Fee[won] (captured exact 10% +
  pinned price, D37) / Released(+reason) / Refund-Penalty(+dispute link, D2) / Top up / Gift;
  amount, date/time, status; link to related order summary and (for refund/penalty) to the
  dispute.
- **nav_edges_missing:** `transaction-detail -> dispute-open-evidence` (refund/penalty rows),
  `transaction-detail -> wallet-activity-list` (back), `transaction-detail ->
  order-summary-pinned` (related order); inbound `wallet-activity-list -> transaction-detail`.
- **mock_endpoints:** MOCK-MISSING: `GET wallet transaction/:id` (typed detail). Does not exist.
- **decisions:** D37 (exact 10% captured == held), D1 (reserve), D2 (dispute refund/penalty
  outcomes), D41 (ledger scope).
- **complexity:** M. **priority:** P1 (leaf of the ledger; depends on wallet-activity-list + the
  transaction endpoint).

### 8. `feedback-rate-delivery` — Rate Customer (role: jeeber)

- **Status: EXISTS.**
- **flutter_target:** `/orders/:id/feedback?mode=jeeber` → `RatingScreen` (audience-flipped via
  `mode=jeeber`, `app_router.dart:698-710`), AND `/orders/:id/mutual-rate?mode=jeeber` →
  `MutualRatingScreen` (blind double-rating, T-MOB-020, `app_router.dart:714-729`).
  `lib/features/rating/presentation/rating_screen.dart` +
  `lib/features/rating/presentation/mutual_rating_screen.dart`.
- **Gap:** Jeeber-rates-customer flow exists with mandatory star input + optional written
  feedback (D6 per-role rating, D56 mandatory). Two concerns: (a) the blueprint contract says
  **NO dismiss/skip control** (D56), but `RatingScreen` renders a **close (X) action**
  (`feedback_close_button`, `rating_screen.dart:130-155`) — the mutual-rating variant is the
  compliant terminal one; confirm which is reachable post-completion and remove the skip on the
  mandatory path. (b) The outgoing edge `feedback-rate-delivery -> delivery-requests` ("submit →
  return to DELIVERY tab"): `RatingScreen._onSubmit` just `pop()`s with a result map and does not
  navigate to the DELIVERY tab; `MutualRatingScreen` goes to its awaiting/revealed state. Wire
  submit to return to the jeeber DELIVERY/Dashboard tab.
- **nav_edges_missing:** `feedback-rate-delivery -> delivery-requests` (post-submit return to the
  jeeber feed/DELIVERY tab — currently a `pop`, not a tab navigation).
- **mock_endpoints:** `POST /score-taking-service/v1/ratings/jeeb/submit` (idempotent),
  `GET /score-taking-service/v1/ratings/jeeb/:deliveryId/status` (blind reveal state) — both exist.
- **decisions:** D6 (per-role ratings), D56 (mandatory, no skip — verify the X is not on the
  mandatory path), D31 (per-role theme).
- **complexity:** S. **priority:** P1 (exists; needs the post-submit nav edge + skip-control audit).

---

## Domain navigation edge summary (missing / to-wire)

| from | to | trigger | status |
|------|----|---------|--------|
| jeeber-mark-delivered | feedback-rate-delivery | on completion (mandatory rating) | MISSING (lands on OTP, no rating chain) |
| earnings-fees-dashboard | wallet-hub | back to wallet | MISSING (no wallet) |
| earnings-fees-dashboard | wallet-activity-list | view full activity | MISSING |
| wallet-hub | wallet-charge-info | how to add funds | MISSING (no wallet) |
| wallet-hub | offer-kyc-gate | KYC status | MISSING |
| wallet-hub | earnings-fees-dashboard | Earnings & fees | MISSING |
| wallet-hub | wallet-activity-list | See all activity | MISSING |
| wallet-activity-list | transaction-detail | open detail | MISSING |
| wallet-activity-list | wallet-hub | back | MISSING |
| wallet-charge-info | wallet-hub | back | MISSING |
| transaction-detail | dispute-open-evidence | related dispute | MISSING |
| transaction-detail | wallet-activity-list | back | MISSING |
| transaction-detail | order-summary-pinned | related order | MISSING |
| feedback-rate-delivery | delivery-requests | submit → DELIVERY tab | TO-WIRE (currently pop) |
| [header chip] customer-orders-home / customer-profile / delivery-requests | wallet-hub | tap wallet chip (D33) | MISSING (no chip, no wallet) |

## Mock backend work items implied by this domain

1. **Add a wallet/ledger surface** to the mock (new endpoints): balance + affordability (D43),
   reserved-now sum (D1), typed ledger list (paginated), and transaction-by-id detail.
2. **Wire offer lifecycle to the ledger:** `offer-service` submit → reserve row; accept →
   capture(win) row + release(losers) rows; withdraw/expire → release row (D1/D15/D37). None of
   this exists in `offer-service.ts` today.
3. **Add a proof sink** for the delivery photo (D3) on/alongside
   `POST /delivery-service/v1/delivery/status/transition`.
4. **Confirm earnings path rewrite:** app calls `/v1/wallet/jeeb/earnings*`; mock mounts
   `/wallet-service/v1/jeeb/earnings*` — verify the gateway rewrite resolves it.

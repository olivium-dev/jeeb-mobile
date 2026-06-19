# 20_GAP — Customer Domain

> Principal UX gap analysis for the **customer journey** (15 blueprint screens).
> Authoritative design = `jeeb-mind-map/web/blueprint.json` + `web/src/screens/_data/<id>.json`.
> Flutter = `jeeb-mobile/lib/features/*` + router `lib/core/router/app_router.dart`.
> Mock = `jeeb-mock-backend/src/services`. Decisions = `jeeb-mind-map/docs/07_DECISIONS_LOG.md`.
> Status legend: **exists** (real, blueprint-faithful, routed) · **partial** (real screen, missing
> blueprint elements/edges) · **divergent** (a screen exists but models a different contract) ·
> **missing** (no screen, or built-but-orphaned with no route/entry edge).

---

## Domain-level structural findings (read first)

These cut across multiple screens and drive priority:

1. **Router has NO `StatefulShellRoute`.** The bottom-nav shell is a single `/` route → `ShellScreen`
   that swaps tab bodies via a local `IndexedStack` + `RoleCubit`. **Tabs are not routes.** Every
   `goNamed` deep-link target must be a top-level route. Customer tab bodies: `HomeTab` (Requests) →
   `ClientHomeScreen`; `OrdersTab` (DELIVERY) → `OrderHistoryScreen`; `ProfileTab` (Profile).

2. **The Profile tab is NOT the blueprint `customer-profile`.** `lib/features/shell/tabs/profile_tab.dart`
   is a QA/dev surface: a language selector, a **client↔jeeber role toggle**, and one "Open Settings" row.
   The real, blueprint-shaped `CustomerProfileScreen` (`lib/features/customer_profile/`) exists at route
   `/profile/customer` but is **only reachable via a debug fixture / `extra`** — no nav edge from the
   Profile tab reaches it. In release it falls back to `ProfileUnavailableScreen`.

3. **No persistent header (wallet chip + notification bell).** The blueprint puts a wallet chip +
   notification bell on `customer-orders-home`, `customer-profile`, and `my-orders` (edges to `wallet-hub`
   and `notifications-list`). Neither exists in the app: `/wallet` is a "coming soon" stub Scaffold and
   there is **no notifications-list route at all** (`/settings/notifications` is *preferences*, a different
   screen). These two header edges are missing on every customer screen that declares them.

4. **Create-request flow diverges from the chat-first model.** Blueprint: `request-type-selection`
   → `location-select` → **`order-chat`** where the *first chat message IS the request* (compose: text or
   voice required, then broadcast → `waiting-no-coverage`). Flutter: `/request-type` → `/request-summary`
   (a review-card screen) → submit → `/` (Requests tab). There is **no compose-the-request-in-chat
   entry**; the broadcasting-phase `ChatScreen` exists (it renders a broadcasting empty-state + TTL
   indicator + offer-card bubbles) but is reached only AFTER a request exists, via `/chat/:id`. This is
   the single largest customer-journey gap.

5. **Offer review/accept is in-chat, not a distinct screen pair.** Blueprint models `my-orders` (Replies
   cards) → `offer-review-list` (one card per Jeeber, sort, blind) → `offer-accept-confirm` (sheet) →
   `order-chat`. Flutter routes Replies "Check Offers" straight to `/chat/:id`, where offers are
   **in-thread offer-card bubbles** with an inline accept (no confirm sheet with consequence copy, D11/D71).
   A standalone `ClientOffersScreen` (`lib/features/client_offers/`) — which IS the blueprint
   `offer-review-list` (sort bar, per-card Accept, window timer) — is **built but orphaned** (no route, no
   caller anywhere in `lib/`).

6. **Tiers mismatch.** Blueprint `request-type-selection` lists 5 tiers (Flash/Express/Standard/
   On-the-Way/Eco). Mock `GET /delivery-service/v1/tiers` returns **flash/express/standard** only. Flag to
   backenders; do not invent the 2 extra tiers.

---

## Per-screen analysis

### 1. customer-orders-home — **partial** — P0
- **Flutter target:** extend `lib/features/home_client/presentation/client_home_screen.dart` (hosted by
  `lib/features/shell/tabs/home_tab.dart`, the Requests tab body).
- **What exists:** Greeting header + "+" FAB → `/request-type`; search bar (read-only placeholder, tap
  suppressed); 3 sub-tabs **In Progress / Pending Requests / Replies** (`InProgressTab`,
  `PendingRequestsTab`, `RepliesTab`); In-Progress rows with "Track my order" → `/orders/:id/tracking`;
  order rows → `/chat/:id`; voice CTA → `/voice-request`; empty state; bottom nav.
- **Gap:** (a) **No persistent header wallet chip / notification bell** → missing edges to `wallet-hub`
  and `notifications-list`. (b) Pending sub-tab opens chat, not the blueprint `waiting-no-coverage`
  waiting state. (c) Search is non-functional (acceptable for v1 per code comment). (d) "New Order" goes
  to `/request-type` (a screen), but blueprint flow continues to compose-in-chat (see structural #4).
- **Missing nav edges:** `customer-orders-home->wallet-hub`, `customer-orders-home->notifications-list`,
  `customer-orders-home->waiting-no-coverage` (pending thread).
- **Mock:** `GET /delivery-service/v1/requests?status=pending|offers-received|active` (decorated with
  offersCount/offerAvatars/conversationId); legacy `GET /delivery-service/api/requests`.
- **Decisions:** D82 (keep my-orders ≠ customer-orders-home), D70 (state stepper on rows), D84 (notif
  deep-links).

### 2. request-type-selection — **partial** — P1
- **Flutter target:** `lib/features/request_type/presentation/request_type_screen.dart` (route `/request-type`).
- **What exists:** tier radios + "Change Location" row → `/client-location`; Continue/tier-tap → assembles
  a `RequestDraft` and pushes `/request-summary`.
- **Gap:** (a) blueprint next step is `location-select` → `order-chat` (compose request as first message);
  Flutter goes to `/request-summary` (review card) instead — **edge `request-type-selection->order-chat`
  missing**, and the chat-compose entry does not exist. (b) Only 3 tiers available from mock vs 5 in
  blueprint (Flash/Express/Standard + On-the-Way/Eco missing) — backend gap. (c) No `Start order` CTA that
  opens the order thread.
- **Missing nav edges:** `request-type-selection->order-chat` (Start order), `request-type-selection->location-select`
  (the app jumps to `/client-location`, a near-equivalent, but not the blueprint `location-select` contract).
- **Mock:** `GET /delivery-service/v1/tiers`.
- **Decisions:** D14 (tier constrains ETA SLA band only).

### 3. order-chat — **partial** — P0
- **Flutter target:** `lib/features/chat/presentation/chat_screen.dart`, reached via
  `lib/features/deep_link_targets/chat_detail_screen.dart` (route `/chat/:id`).
- **What exists:** WhatsApp-style thread; composer (text + attach + mic + send); broadcasting-phase
  empty-state + `BroadcastTtlIndicator`; in-thread offer-card bubbles with accept/decline; offer-accepted
  banner with **client "Track order"** CTA → `/orders/:id/tracking`; system message bubbles; chat fee
  banner (jeeber variant). Role-aware (client vs jeeber via `RoleCubit`).
- **Gap:** (a) **No pinned order-summary strip** (locked price / ETA / tier / ref) persistent at top —
  D71/D11 require a persistent authoritative-price header through the whole order; current `ChatAppBar`
  shows only counterpart name/avatar. (b) **No compose-request → broadcast entry** (the blueprint's
  `order-chat` is also the request-composer that sends → `waiting-no-coverage`); the app's chat is only
  reachable after a request/conversation exists. (c) Edges to `order-summary-pinned`, `dispute-open-evidence`
  not wired from chat (escalate route exists at `/orders/:id/escalate` but no in-chat link). (d) Accept is
  inline, no `offer-accept-confirm` consequence sheet (see screen 7).
- **Missing nav edges:** `order-chat->waiting-no-coverage` (send request/broadcast),
  `order-chat->order-summary-pinned` (view summary), `order-chat->dispute-open-evidence` (open dispute),
  `order-chat->order-tracking` is present (banner CTA).
- **Mock:** `POST /chat-service/.../conversations` (createJeebConversation), `GET .../by-request/:requestId`,
  `GET .../:conversationId`, `GET/POST .../messages`, `GET .../snapshot` (dispute). WS
  `jeeb:chat:<convId>`.
- **Decisions:** D83 (order-chat ≠ delivery-order-chat), D71 (pinned accept message + order-summary header),
  D11 (pinned price), D70 (imperative jeeber milestones / customer stepper).

### 4. waiting-no-coverage — **divergent** — P1
- **Flutter target:** new route + extend/replace `lib/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart`
  (currently a built-but-orphaned screen). Alternatively surface this as a state of the broadcasting chat.
- **What exists:** `NoOfferTimeoutScreen` — a centered hourglass + "No offers received yet" + 3 actions
  (Upgrade Tier / Keep Waiting / Cancel Request) that `Navigator.pop` a string result. **Unrouted, hardcoded
  English (no l10n), no countdown / "N notified" state, no live offer arrival.**
- **Gap:** blueprint `waiting-no-coverage` is the post-broadcast waiting state: "waiting for offers / N
  notified + countdown" with one-tap re-target (widen / change tier reusing original content, D48), live
  transition when offers arrive (→ `my-orders` / `offer-review-list`), and free pre-accept cancel
  (→ `cancel-request-confirm`). The existing screen captures only the "tier upgrade" idea, not the wait
  state, the countdown, the no-coverage variant, or the content-reuse re-target.
- **Missing nav edges:** `waiting-no-coverage->my-orders` (offers arrive),
  `waiting-no-coverage->offer-review-list` (review), `waiting-no-coverage->order-chat` (widen/change tier),
  `waiting-no-coverage->request-type-selection` (re-target, D48), `waiting-no-coverage->cancel-request-confirm`.
- **Mock:** `POST /matching/v1/matching/find-jeebers`, `POST /matching/v1/matching/broadcast`;
  `GET /delivery-service/v1/requests?status=pending` for the wait list; `GET .../offers?requestId=` to detect
  arrival.
- **Decisions:** D48 (no-coverage wait + one-tap re-target reusing content), D69 (free pre-accept cancel).

### 5. my-orders — **partial** — P1
- **Flutter target:** `RepliesTab` (`lib/features/home_client/presentation/tabs/replies_tab.dart`) — the
  "Replies" sub-tab of `ClientHomeScreen`. Blueprint treats `my-orders` as the Replies offer-card list
  (D82 keeps it separate from customer-orders-home).
- **What exists:** Replies cards with stacked offerer avatars + offer badge + "Check Offers" CTA. Search +
  sub-tabs inherited from the home screen.
- **Gap:** "Check Offers" routes to `/chat/:id` (in-thread offers) instead of the blueprint
  `offer-review-list` standalone screen; and there is no Accept-on-card → `offer-accept-confirm` edge. Cards
  show an offers badge but not the per-offer accept entry the blueprint's `my-orders`→`offer-accept-confirm`
  edge implies.
- **Missing nav edges:** `my-orders->offer-accept-confirm` (tap Accept on a card),
  `my-orders->offer-review-list` (open offers) — currently both collapse into `->/chat/:id`.
- **Mock:** `GET /delivery-service/v1/requests?status=offers-received`.
- **Decisions:** D82 (my-orders separate), D11 ("pay cash" on each offer card).

### 6. offer-review-list — **missing** (built-but-orphaned) — P1
- **Flutter target:** wire `lib/features/client_offers/presentation/client_offers_screen.dart` to a new
  route (e.g. `/requests/:id/offers`) and an entry edge from `my-orders` / `waiting-no-coverage`. The screen
  is fully built but **no route and no caller reference it anywhere in `lib/`**.
- **What exists (orphaned):** `ClientOffersScreen` — offer window countdown, sort bar (price/ETA/rating),
  one `OfferCard` per offer, request-closed + accept-success banners, accept-in-flight gating. Backed by
  `DioOffersRepository`. This matches the blueprint `offer-review-list` contract closely.
- **Gap:** (a) not routed / not reachable; (b) per-card "Pay $X cash on delivery" line (D11) must be
  confirmed present on `OfferCard`; (c) tapping a Jeeber name/avatar should open `jeeber-profile-reviews`
  (shared domain) — no such edge; (d) Accept should route through `offer-accept-confirm` (consequence
  sheet) rather than accept inline.
- **Missing nav edges:** `offer-review-list->offer-accept-confirm`, `offer-review-list->jeeber-profile-reviews`,
  `offer-review-list->my-orders` (back), `offer-review-list->cancel-request-confirm`.
- **Mock:** `GET /offer-service/v1/offers?requestId=`, `POST /offer-service/v1/offers/:offerId/accept` (SAGA:
  supersede losers, flip convo, return handoverCode + conversationId).
- **Decisions:** D11 (pay cash on every card), D6/D58/D59 (per-role rating, cold-start hide < 5).

### 7. offer-accept-confirm — **missing** — P1
- **Flutter target:** new confirm-sheet (OMDS bottom sheet) invoked from `offer-review-list` (and/or the
  in-chat offer-card accept). No equivalent today: the in-chat `OfferCardBubble` accept and the
  `ClientOffersScreen` accept both fire immediately with no consequence sheet.
- **Gap:** entire screen missing. Blueprint requires a sheet titled "Accept X's offer?" with "Pay $N cash on
  delivery" + "Other offers will close" warning + Cancel / Confirm; Confirm triggers fee capture + closes
  losers, then routes to `order-chat`. This is the D11/D71 comprehension gate.
- **Missing nav edges:** `offer-accept-confirm->order-chat` (confirm), `offer-accept-confirm->offer-review-list`
  (cancel/dismiss).
- **Mock:** `POST /offer-service/v1/offers/:offerId/accept` (returns conversationId + handoverCode).
- **Decisions:** D11, D71 (pinned accept system message), D69 (confirm sheet w/ consequence copy for
  irreversible accept).

### 8. order-summary-pinned — **missing** — P1
- **Flutter target:** new — either a small route or (preferably) a persistent pinned header widget injected
  into `ChatScreen` and `LiveTrackingScreen`. Today neither shows a pinned authoritative-price summary.
- **Gap:** entire surface missing. Blueprint: pinned accepted price (authoritative) + Jeeber name/rating +
  ETA + tier + item summary + "Pay cash on delivery" reminder, with entry into 1:1 chat + link to tracking.
  `OrderHistoryCard` (DELIVERY tab) shows order rows but not the pinned-price contract; `LiveTrackingScreen`
  has a `DeliveryTrackingPanel` but no pinned price banner.
- **Missing nav edges:** `order-summary-pinned->order-chat`, `order-summary-pinned->order-tracking` (the
  blueprint screen has no `outgoing` array populated, but the lofiOutline declares both entries).
- **Mock:** `GET /delivery-service/v1/delivery/:deliveryId` (price/jeeber/eta/tier), `GET .../requests/:requestId`.
- **Decisions:** D11 (single authoritative pinned price), D71 (persistent order-summary header), D6 (rating).

### 9. order-tracking — **partial** — P0
- **Flutter target:** `lib/features/live_tracking/presentation/live_tracking_screen.dart` (route
  `/orders/:id/tracking`).
- **What exists:** full-bleed map + status panel (`DeliveryTrackingPanel`), matched-Jeeber card, OTP
  at-door card (slides in on `at_door`), "Jeeber is on the way" snack on `in_transit`, 5s poll reconnect.
  Reachable from home In-Progress "Track" and from chat accepted banner.
- **Gap:** (a) **No 4-step Ordered→Picked→In Transit→Delivered stepper** as the blueprint's primary visual
  (D70) — the panel shows status differently; verify/extend to the canonical 4-step stepper. (b) **No
  pinned order-summary header** (price/Jeeber/locked ETA, D11/D18). (c) **No dispute link** →
  `dispute-open-evidence`. (d) **No no-show action sheet** (Reassign → `offer-review-list` / Re-broadcast →
  `waiting-no-coverage`, D88). (e) No auto-advance to `delivered-receipt-confirm`. (f) Blueprint title typo
  "Traking" — app uses correct `trackingTitle` (already fixed).
- **Missing nav edges:** `order-tracking->delivered-receipt-confirm` (auto on delivered),
  `order-tracking->dispute-open-evidence`, `order-tracking->offer-review-list` (no-show reassign),
  `order-tracking->waiting-no-coverage` (no-show re-broadcast), `order-tracking->my-orders` (back),
  `order-tracking->order-chat` (open thread).
- **Mock:** `GET /delivery-service/v1/delivery/:deliveryId`, `POST /delivery-service/v1/delivery/status/transition`
  (SM-1), `GET /geolocation-service/v1/jeeb/geo/route/:deliveryId`, WS `geo:delivery:<id>`.
- **Decisions:** D70 (state stepper), D11/D18 (locked price + ETA authority), D88 (no-show action sheet), D71.

### 10. delivered-receipt-confirm — **divergent** — P0
- **Flutter target:** new route + rewrite of `lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart`
  (built-but-orphaned, divergent contract).
- **What exists:** `DeliveryReceiptScreen` — an itemized receipt card (Goods Cost / Delivery Fee /
  Commission / Total) with hardcoded LBP values + Share/Done. **Unrouted, hardcoded, no l10n.** This is the
  WRONG contract: it models a finance receipt (and exposes "Commission" which is the *Jeeber's* wallet fee,
  not customer-facing), not the customer's receipt confirmation.
- **Gap:** blueprint `delivered-receipt-confirm` is a push-triggered prompt "Did you receive your order?" +
  "Pay $N cash to <Jeeber>" + proof-of-delivery photo (D3) + "Not yet" (→ dispute) + "Confirm" (→ rating /
  auto-complete on timeout). None of that exists; the existing screen must be replaced.
- **Missing nav edges:** `delivered-receipt-confirm->rate-jeeber` (confirm),
  `delivered-receipt-confirm->dispute-open-evidence` (Not yet).
- **Mock:** `POST /delivery-service/v1/delivery/status/transition` (to completed),
  `POST /unified-payment-gateway/v1/payments/cod_jeeb/record` (COD collected); proof photo via chat snapshot
  / delivery detail.
- **Decisions:** D3 (two-sided + proof, auto-complete on timeout), D11 (pay cash line).

### 11. rate-jeeber — **exists** — P1
- **Flutter target:** `lib/features/rating/presentation/rating_screen.dart` (route `/orders/:id/feedback`)
  and `mutual_rating_screen.dart` (route `/orders/:id/mutual-rate`). Note `/orders/:id/rate` redirects to
  `/orders/:id/mutual-rate`; `RatingPromptScreen` is a frozen unreachable placeholder.
- **What exists:** star input (mandatory) + optional comment, audience-parameterised (client rates jeeber
  via `isClient`), ratee name/avatar context. Mutual-rating variant implements the double-blind reveal.
- **Gap:** (a) blueprint `rate-jeeber` on submit returns to `customer-orders-home`; confirm the rating
  screen routes back to `/` (Requests). (b) **Completion-gating / cannot-dismiss** (D56 mandatory) must be
  enforced — verify the back button is suppressed. (c) Cold-start "hide score until N≥5" + first-name-only
  attribution (D58/D59) apply to the *display* side, not this submit screen. (d) Two competing rating routes
  (`/feedback` vs `/mutual-rate`) — reconcile which is canonical for the customer terminal step.
- **Missing nav edges:** `rate-jeeber->customer-orders-home` (verify submit returns to Requests tab).
- **Mock:** `POST /score-taking-service/v1/ratings/jeeb/submit` (idempotent deliveryId+raterId),
  `GET /score-taking-service/v1/ratings/jeeb/:deliveryId/status`.
- **Decisions:** D56 (mandatory to close + auto-close fallback), D6 (per-role), D58/D59 (attribution / cold-start).

### 12. cancel-request-confirm — **divergent** — P1
- **Flutter target:** new confirm-sheet (OMDS) for the **pre-accept free** cancel. Do NOT reuse
  `lib/features/cancellation/presentation/cancellation_screen.dart` — that is a different contract.
- **What exists:** `CancellationScreen` (route `/orders/:id/cancel`) — a reason picker for **active
  deliveries** (post-accept) with role-specific reasons + a success sheet that can charge a fee (→ `/wallet`).
  Note: the blueprint screen data file `_data/cancel-request-confirm.json` is **MISSING** in the design repo;
  contract taken from `blueprint.json` key_elements only.
- **Gap:** blueprint `cancel-request-confirm` is a simple confirm sheet: "Cancel this request?" + consequence
  copy ("free before accept, nothing charged", D69) + Keep request / Cancel request → `customer-orders-home`.
  The existing screen is a post-accept reason-and-fee flow (wrong moment, wrong consequence copy, wrong
  destination). Pre-accept free cancel has no UI.
- **Missing nav edges:** `cancel-request-confirm->customer-orders-home` (confirm cancellation).
- **Mock:** `POST /delivery-service/v1/delivery/cancel` (or request-level cancel); `DELETE
  /offer-service/v1/offers/:offerId` is jeeber-side, not this. Pre-accept request cancel may need a mock
  endpoint — flag if absent (no explicit `requests/:id/cancel` in the inventory).
- **Decisions:** D69 (confirm sheet w/ consequence copy; free pre-accept, nothing charged).

### 13. saved-addresses — **partial** — P2
- **Flutter target:** `lib/features/location/presentation/saved_locations_screen.dart` (route
  `/settings/addresses`).
- **What exists:** list of saved locations with label + category icon + address; add/edit/delete via
  `AddEditLocationSheet`; empty/error/loading states; CRUD backed by saved-locations API; back nav. Strong
  match for the list-manager contract.
- **Gap:** (a) **No default-address indicator** (blueprint requires a default marker). (b) **Entry edge
  mismatch** — blueprint reaches `saved-addresses` from `customer-profile` (Saved addresses row), but the app
  reaches it via `Profile tab → Open Settings → Addresses` (the real customer-profile is orphaned, see
  structural #2). (c) Edit/add opens a bottom sheet, not the blueprint's full `address-detail-form` screen
  (see screen 14).
- **Missing nav edges:** `saved-addresses->address-detail-form` (edit / add — currently a sheet),
  `saved-addresses->customer-profile` (back — currently back to Settings).
- **Mock:** `GET /user-management/users/:userId/saved-locations`, `POST .../saved-locations` (max 10).
- **Decisions:** none specific; D-set general.

### 14. address-detail-form — **divergent** — P2
- **Flutter target:** extend/replace `lib/features/location/presentation/widgets/add_edit_location_sheet.dart`
  (a bottom sheet) into a full form screen, OR add the blueprint fields to the sheet.
- **What exists:** `AddEditLocationSheet` collects **label + category chips + lat/long (+ optional address
  string)** only.
- **Gap:** blueprint `address-detail-form` requires **map pin/preview + label + Building + Floor/apartment +
  Delivery notes + Phone (for COD coordination) + Save**. Building, floor/apartment, delivery-notes, and the
  COD phone field are **all missing**; the current form is a thin label+coordinates capture. Also it is a
  sheet, not a screen with the blueprint's map-preview-first layout.
- **Missing nav edges:** `address-detail-form->saved-addresses` (Save address — currently the sheet pops a
  result back to the list).
- **Mock:** `POST /user-management/users/:userId/saved-locations` (must accept the extra structured fields —
  flag to backenders if the schema lacks building/floor/notes/phone).
- **Decisions:** none specific; COD coordination implied by the cash-on-delivery model.

### 15. customer-profile — **divergent** — P0
- **Flutter target:** route the real `lib/features/customer_profile/presentation/customer_profile_screen.dart`
  (`/profile/customer`) as the **Profile tab body**, replacing the dev-surface `ProfileTab`. Or rebuild the
  Profile tab to the blueprint row set.
- **What exists:** TWO things. (a) `ProfileTab` (the actual bottom-nav Profile body): language selector +
  client↔jeeber role toggle + "Open Settings" row — a **QA/dev surface, not the blueprint profile**. (b)
  `CustomerProfileScreen` (real, blueprint-shaped: header with avatar/name/verified, Register-as-delivery,
  Password & security, Notifications, Reset location, Contact us, Rate app) — but it is **orphaned**, only
  reachable via debug fixture / typed `extra`, and several rows are no-ops or point at `/settings`.
- **Gap:** (a) the blueprint profile is not what the user sees on the Profile tab; (b) missing header
  **wallet chip + notification bell** → edges to `wallet-hub` / `notifications-list`; (c) missing
  **Saved addresses** row → `saved-addresses`; (d) missing **Language (EN/AR)** as a row (it lives in the
  dev ProfileTab instead); (e) missing **Logout / Delete account** row → `logout-delete-account`; (f)
  Register-as-delivery should go to `delivery-onboarding-image-upload`, not `/register`; (g) Contact us /
  Rate app are no-ops (→ `support-ticket` / `rate-the-app`).
- **Missing nav edges:** `customer-profile->delivery-onboarding-image-upload`, `->password-security`,
  `->notification-prefs`, `->language-settings`, `->support-ticket`, `->rate-the-app`,
  `->logout-delete-account`, `->wallet-hub`, `->notifications-list`, `->saved-addresses`.
- **Mock:** `GET /user-management/users/me`, `POST /user-management/users/:userId/role/switch`,
  `PATCH /user-management/users/:userId/available-roles` (register-as-delivery),
  `GET /notification-service/v1/notifications/preferences`.
- **Decisions:** D6 (per-role rating shown), D90 (set-password return), D67/D20 (jeeber onboarding fields).

---

## Priority rollup
- **P0 (blocks core journey):** customer-orders-home, order-chat, order-tracking, delivered-receipt-confirm,
  customer-profile.
- **P1 (major):** request-type-selection, waiting-no-coverage, my-orders, offer-review-list,
  offer-accept-confirm, order-summary-pinned, rate-jeeber, cancel-request-confirm.
- **P2 (polish):** saved-addresses, address-detail-form.

## Backend flags raised
- 5 tiers in blueprint vs 3 in mock (`On-the-Way`, `Eco` absent).
- No notifications-list endpoint consumer (route absent in app; mock `GET /notification-service/v1/notifications` exists but unused).
- `/wallet` is a stub; mock wallet/earnings data exists but customer wallet-hub is unbuilt.
- Pre-accept request cancel: no explicit `requests/:id/cancel` mock route (cancel is delivery-level).
- address-detail-form structured fields (building/floor/notes/phone) — confirm saved-locations schema supports them.
- `_data/cancel-request-confirm.json` missing in design repo (contract from blueprint.json only).

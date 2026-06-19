# 20_GAP — SHARED domain (Principal UX gap analysis)

> Domain: SHARED screens (subset). Author: Principal UX analyst. Date: 2026-06-18.
> Method: blueprint.json + `web/src/screens/_data/<id>.json` contract vs. the Flutter
> inventory (`11_FLUTTER_INVENTORY.md`) and the actual `lib/features/*` code, cross-checked
> against `12_MOCK_INVENTORY.md`, `docs/07_DECISIONS_LOG.md`, and `flow-review/99_LEAD_SYNTHESIS.md`.
> All routes/paths verified by reading `lib/core/router/app_router.dart` in full.

Scope (14 screens): `notifications-list`, `notification-prefs`, `language-settings`,
`location-select`, `location-map-pin`, `password-security`, `logout-delete-account`,
`support-ticket`, `rate-the-app`, `dispute-open-evidence`, `dispute-status`,
`account-status`, `reviews-list`, `jeeber-profile-reviews`.

---

## Cross-cutting facts (load-bearing for this domain)

1. **Router has NO `notifications-list` / inbox route.** `/settings/notifications` is the
   *preferences* screen only (`NotificationPreferencesScreen` → `NotificationPrefsScreen`).
   The mock exposes `GET /notification-service/v1/notifications?userId=` (unconsumed). This
   is the async backbone the lead flagged as under-wired (`99_LEAD_SYNTHESIS.md` T-C).

2. **`notification-prefs` repo hits the WRONG mock path.**
   `lib/features/notification_prefs/data/dio_notification_prefs_repository.dart` targets
   `/users/me/notification-preferences` (legacy Mockoon :3055). The live mock contract is
   `GET|PUT /notification-service/v1/notifications/preferences`. Wiring must be re-pointed.

3. **`escalate` (the app's dispute-open surface) hits a NON-EXISTENT mock path.**
   `dio_escalate_repository.dart` posts `POST /v1/deliveries/{id}/escalate`. No such mock
   route exists (`12_MOCK_INVENTORY.md` gap #4: `/v1/deliveries/*` 404s). The real mock
   dispute API is `compliment-service`: `POST /compliment-service/v1/disputes`,
   `GET /compliment-service/v1/disputes`, `GET|PATCH /.../:disputeId`.

4. **Language lives inline, not as its own screen.** A standalone
   `LanguageSettingsScreen` (`lib/features/language/.../language_settings_screen.dart`,
   `routeName = '/settings/language'`) EXISTS but is **NOT registered** in the router.
   Language is rendered inline inside `SettingsScreen._LanguageSection` and again inside
   `shell/tabs/profile_tab.dart`. The blueprint edge `customer-profile → language-settings`
   has no dedicated target.

5. **Two profile surfaces.** The user-facing Profile tab is `shell/tabs/profile_tab.dart`
   (role/language/settings entry), NOT the parity-capture `CustomerProfileScreen`
   (`/profile/customer`, fixture/dev-seam only in release). The blueprint's `customer-profile`
   row edges (Password & security, Notification prefs, Language, Contact us, Rate app, Logout)
   are split across `profile_tab` → `SettingsScreen`, and most shared targets below are
   reached (if at all) from `SettingsScreen`, not a single profile surface.

6. **No suspended/locked gate exists** anywhere in `lib/` (verified: no `AccountStatus`/
   suspend surface). Mock supports it via admin `PATCH /user-management/admin/users/:id/status`
   (sets `activeRole='suspended'`, `suspendedAt`, `suspendReason`).

---

## Per-screen findings

### notifications-list — MISSING — P0
- **flutter_target:** NEW route `/notifications` → new `NotificationsListScreen`
  (feature `lib/features/notifications/`). Reach from persistent header bell on
  `customer-orders-home`, `customer-profile`, `delivery-requests` (header not yet built —
  coordinate with customer/jeeber domains).
- **gap:** No inbox screen or route at all. Mock `listNotifications` + `markRead` unconsumed.
  Needs typed rows (new offer / offer accepted / status / low balance / fee charged-released /
  refund-penalty / top-up / KYC), per-row deep-link, tier-modulated urgency, empty state,
  inline confirm-receipt action. Deep-link routing governed by D84 (notification deep links).
- **nav_edges_missing:** `notifications-list->delivered-receipt-confirm`,
  `notifications-list->wallet-hub`, `notifications-list->my-orders`,
  `notifications-list->order-chat`, `notifications-list->customer-orders-home`,
  `notifications-list->jeeber-requests-home`, `notifications-list->kyc-rejected`,
  `notifications-list->waiting-no-coverage` (all 8 inbound-from-list edges missing).
- **mock:** `GET /notification-service/v1/notifications?userId=`,
  `PATCH /notification-service/v1/notifications/:id/read`.
- **decisions:** D84 (deep links), D64 (category model parity), R2 (push-only).
- **complexity:** L. **priority:** P0 (async backbone; T-C in lead synthesis).

### notification-prefs — PARTIAL — P1
- **flutter_target:** EXTEND `lib/features/notification_prefs/presentation/notification_prefs_screen.dart`
  (routed at `/settings/notifications`).
- **gap:** Real server-first screen exists (GET on mount, debounced PATCH, optimistic toggle,
  always-on OTP row). Three contract gaps: (a) **repo path wrong** — points at
  `/users/me/notification-preferences`, not the mock's `/notification-service/v1/notifications/preferences`;
  (b) **missing the `wallet` category toggle (D64)** — current topics are offers/chat/statusChanges/
  ratingReminders; blueprint+D64 require offers/order-status/**wallet**/marketing, transactional locked;
  (c) **missing the push-only note (R2)** "no email/SMS fallback". Title also reuses
  `notificationPreferencesTitle` ("Notification Preferences"); blueprint title is "Notifications".
- **nav_edges_missing:** `notification-prefs->customer-profile` (back) — currently pops to
  SettingsScreen, not a customer-profile surface (acceptable via back nav; flag for parity).
- **mock:** `GET /notification-service/v1/notifications/preferences`,
  `PUT /notification-service/v1/notifications/preferences`.
- **decisions:** D64, R2.
- **complexity:** M. **priority:** P1.

### language-settings — DIVERGENT — P1
- **flutter_target:** Register the EXISTING `LanguageSettingsScreen` at `/settings/language`
  (its declared `routeName`) and wire the `customer-profile → language-settings` edge to it;
  OR keep inline and formally fold the edge into SettingsScreen. Decision needed (do not invent).
- **gap:** Functionality is COMPLETE (EN/AR, instant RTL flip via `LocaleCubit`) but exists in
  THREE places: the unrouted standalone screen, `SettingsScreen._LanguageSection`, and
  `profile_tab.dart`. The blueprint models language as its own screen reached from
  `customer-profile`; the app has no such navigable target. Missing: an explicit Apply/confirm
  affordance (blueprint lists "Apply / confirm"; app applies instantly — likely fine, confirm).
- **nav_edges_missing:** `customer-profile->language-settings` (no dedicated route),
  `language-settings->customer-profile` (back).
- **mock:** none (locale is client-side via `LocaleCubit`/prefs).
- **decisions:** none specific; R3 (RTL/i18n) governs behaviour.
- **complexity:** S. **priority:** P1.

### location-select — DIVERGENT — P1
- **flutter_target:** `ClientLocationScreen` at `/client-location` (the create-flow origin
  picker) is the closest match; extend it. (`/location` → `LocationPickerScreen` is a separate
  picker surface — reconcile which is canonical with the customer domain.)
- **gap:** Has Current-Location radio + New-Location (+) → map pin. **Missing the
  "Saved addresses" entry** (blueprint edge `location-select → saved-addresses`, lead synthesis
  Q3: attach saved-addresses from BOTH customer-profile and location-select). Saved-locations
  cards are owner-injected, not wired to `listSavedLocations`. Confirm copy ("Set delivery
  location") and that "Confirm location → order-chat" is wired (current onAddLocation only).
- **nav_edges_missing:** `location-select->saved-addresses`, `location-select->order-chat`
  (confirm), `location-select->location-map-pin` (present via onAddLocation→/capture-location),
  `location-select->request-type-selection` (back present).
- **mock:** `GET /user-management/users/:userId/saved-locations` (for the saved-addresses entry).
- **decisions:** Q3 (lead synthesis — saved-addresses attach points).
- **complexity:** M. **priority:** P1.

### location-map-pin — EXISTS — P2
- **flutter_target:** `CaptureLocationScreen` at `/capture-location`.
- **gap:** Matches the contract: full-screen map under a fixed centre pin + "Pin Location"
  confirm CTA (`capture_location_pin_cta` semantics) returning to the location flow. Map tiles
  are injected (`ofl_geo_capture` wrap pending); dev seam renders a neutral placeholder. Minor:
  current-location detection / address preview is not yet surfaced (blueprint key element).
  Back + confirm edges present (pop to caller).
- **nav_edges_missing:** none (back/confirm both pop to `location-select` per blueprint).
- **mock:** none required for the pin itself; reverse-geocode is out of scope (mock geolocation
  has `geo/ping`/`geo/route` only, no geocode).
- **decisions:** none.
- **complexity:** S. **priority:** P2.

### password-security — MISSING — P1
- **flutter_target:** NEW route `/settings/password` → new `PasswordSecurityScreen`
  (feature can live under `lib/features/settings/` or `lib/features/auth/`). The
  `customer_profile` "Password & security" row currently routes to `/settings` (whole settings),
  not a dedicated password screen.
- **gap:** No screen with current/new/confirm fields, validation, or the social-only
  "Set a password" entry. Blueprint edge `password-security → auth-set-password` (for
  social-only accounts) has no target — and `auth-set-password` itself is also unbuilt
  (auth domain: app auth is a single `/register`). Per D90, in-app set-password returns to
  Profile (not Login).
- **nav_edges_missing:** `customer-profile->password-security`,
  `password-security->auth-set-password`, `password-security->customer-profile` (back/save).
- **mock:** No app-facing password endpoint exists (auth is OTP-only; `/auth/login` is
  admin-only). **Mock gap to raise:** a change/set-password endpoint is needed
  (e.g. `POST /auth-service/auth/password`) — flag for backenders.
- **decisions:** D90 (in-app set-password → Profile).
- **complexity:** M. **priority:** P1.

### logout-delete-account — PARTIAL — P1
- **flutter_target:** EXTEND `SettingsScreen._AccountSection` (delete + sign-out with
  confirm dialogs already implemented) and/or surface as the blueprint's combined confirm
  screen reachable from `account-status`.
- **gap:** Logout + delete-account both exist as destructive confirm dialogs in
  `SettingsScreen` (via `SettingsCubit`/`AccountService` — currently `FakeAccountService` /
  `InMemoryProfileRepository` on the default route). NOT a distinct screen/route, and the
  account-status `sign out` edge has no wiring. On confirm, blueprint routes to `splash`;
  app uses cubit-driven sign-out + banner (no explicit splash route — splash is itself unbuilt).
  Irreversibility/role-suspension warning copy present in dialog bodies.
- **nav_edges_missing:** `account-status->logout-delete-account`,
  `logout-delete-account->splash` (splash route absent).
- **mock:** `POST /auth-service/auth/logout` (clears `jeeb_rt`), `POST /push-notification/v1/devices/unregister`.
  Account *deletion* (status→deleted) has no app-facing mock endpoint — **raise** (only admin
  suspend/reinstate exists).
- **decisions:** D5 (unified USER.status incl. `deleted`; suspension spans both roles).
- **complexity:** M. **priority:** P1.

### support-ticket — MISSING — P1
- **flutter_target:** NEW route `/support` → new `SupportTicketScreen`
  (feature `lib/features/support/`). The `customer_profile` "Contact us" row
  (`CustomerSupportSection.onContactUs`) is a **no-op** today.
- **gap:** No contact-us / ticket screen: needs subject/category selector, message body,
  attach-evidence, link to related order/dispute, submit, and an existing-tickets list. This is
  the D76 in-app support ticket tied to the order/dispute system; it is also the escalation
  target from `dispute-status` and `account-status`.
- **nav_edges_missing:** `customer-profile->support-ticket`, `support-ticket->dispute-open-evidence`,
  `support-ticket->customer-profile` (submit confirm), plus inbound
  `account-status->support-ticket`, `dispute-status->support-ticket`, `kyc-rejected->support-ticket`.
- **mock:** No dedicated support-ticket mock service exists. Closest is `compliment-service`
  disputes. **Mock gap to raise:** a support-ticket endpoint (or reuse disputes with a
  `category=support`). Flag for backenders.
- **decisions:** D76.
- **complexity:** M. **priority:** P1.

### rate-the-app — MISSING — P2
- **flutter_target:** NEW thin handler (no full screen) — invoke native store-review sheet
  (e.g. `in_app_review` package) from the `customer_profile` "Rate the app" row, which is a
  **no-op** today (`CustomerSupportSection.onRateApp`).
- **gap:** Blueprint marks this an empty in-app outline / native OS sheet; only the entry-point
  wiring + return-to-Profile is needed. Currently unwired.
- **nav_edges_missing:** `customer-profile->rate-the-app` (entry), `rate-the-app->customer-profile`
  (dismiss).
- **mock:** none (native OS sheet).
- **decisions:** none.
- **complexity:** S. **priority:** P2.

### dispute-open-evidence — DIVERGENT — P0
- **flutter_target:** EXTEND `EscalateScreen` (`/orders/:id/escalate`) — repoint its repo to
  the real dispute API and align fields; OR build a dedicated `DisputeOpenScreen`. (Note: a
  second, simpler `DisputeScreen` exists at `lib/features/dispute/presentation/dispute_screen.dart`
  but is UNROUTED and hard-codes English category strings — dead/divergent; consolidate.)
- **gap:** `EscalateScreen` covers reason picker + ≤5 photos + comment + submit + confirmation,
  BUT (a) posts to a non-existent `POST /v1/deliveries/{id}/escalate` (must move to
  `POST /compliment-service/v1/disputes`); (b) photo picker is a stub (`_fakePickPhoto`) — needs
  real `image_picker`; (c) **no voice evidence** (D53 requires free photo/voice); (d) no
  auto-attached chat + GPS/status timeline (D53 — chat snapshot via
  `chat-service/.../snapshot`); (e) **no link to Contact-us ticket** (blueprint edge +D76);
  (f) on submit it shows an inline confirmation rather than navigating to `dispute-status`.
- **nav_edges_missing:** `dispute-open-evidence->support-ticket`, `dispute-open-evidence->dispute-status`,
  `dispute-open-evidence->order-chat` (back present via maybePop). Inbound entries from
  `order-chat`/`order-tracking`/`delivered-receipt-confirm` exist as `escalate`.
- **mock:** `POST /compliment-service/v1/disputes`,
  `GET /chat-service/v1/chat/jeeb/conversations/:conversationId/snapshot` (D53 chat snapshot).
- **decisions:** D19 (all disputes manual v1), D53 (photo/voice + auto-attached evidence),
  D2 (fee_refund/penalty on resolution), D54, D76.
- **complexity:** L. **priority:** P0 (money at stake; S-8 in lead synthesis).

### dispute-status — MISSING — P1
- **flutter_target:** NEW route `/disputes/:id` (or `/orders/:id/dispute-status`) → new
  `DisputeStatusScreen` (feature `lib/features/dispute/`). The escalate confirmation view
  is a dead-end today.
- **gap:** No status screen. Needs Open/Resolved status, outcome note when resolved
  (refund or penalty, D2), auto-attached evidence summary (chat + GPS/status timeline, D53),
  link to support ticket (D76), back to order thread. This is the lead-synthesis S-8 fix
  ("nowhere to see status or outcome").
- **nav_edges_missing:** `dispute-status->support-ticket`, `dispute-status->order-chat` (back),
  `dispute-open-evidence->dispute-status` (entry).
- **mock:** `GET /compliment-service/v1/disputes?status=&userId=`,
  `GET /compliment-service/v1/disputes/:disputeId`.
- **decisions:** D2, D19, D53, D76.
- **complexity:** M. **priority:** P1.

### account-status — MISSING — P1
- **flutter_target:** NEW route `/account-status` → new `AccountStatusScreen` AND a router
  redirect gate (alongside the existing onboarding/biometric gates in `app_router.dart`) that
  routes `suspended|locked` users here and BLOCKS all tab access (D5; lead synthesis T-F:
  "a suspended user reaches all tabs unimpeded").
- **gap:** Zero coverage. Needs status banner (suspended/locked), reason copy, Contact-support
  (D76), Sign out, no tab access. Requires a `USER.status` read on session resolve — mock
  carries suspension state (`user.activeRole='suspended'`, `suspendedAt`, `suspendReason`) but
  via admin mutation; `GET /user-management/users/me` must surface it. Splash auto-routes
  suspended users here (`splash->account-status`) — splash itself is unbuilt.
- **nav_edges_missing:** `splash->account-status`, `notifications-list` deep-links N/A,
  `account-status->support-ticket`, `account-status->logout-delete-account`.
- **mock:** `GET /user-management/users/me` (must expose status); suspension set via
  `PATCH /user-management/admin/users/:userId/status` (CMS/test seam).
- **decisions:** D5 (unified status, suspension spans both roles), D76.
- **complexity:** M. **priority:** P1.

### reviews-list — MISSING — P1
- **flutter_target:** NEW route `/reviews` (or `/profile/delivery-man/reviews`) → new
  `ReviewsListScreen` (feature can reuse `delivery_man_profile` widgets). The "View all"
  control on the Jeeber profile is a **no-op** (`onViewAll: () {}`).
- **gap:** No full-reviews list. Needs infinite scroll + skeletons (D73), reviewer first
  name/initial (D58), cold-start hide-score-until-N≥5 + "New" badge (D59), report-a-review
  moderation (D27), back to profile. No mock review-list source exists (score-taking only
  reveals per-delivery ratings on `:deliveryId/status`).
- **nav_edges_missing:** `jeeber-profile-reviews->reviews-list` (View all),
  `reviews-list->jeeber-profile-reviews` (back).
- **mock:** No reviews-list endpoint. **Mock gap to raise:** a per-jeeber reviews list
  (e.g. `GET /score-taking-service/v1/ratings/jeeb/by-jeeber/:jeeberId` paginated). Flag for
  backenders.
- **decisions:** D27 (report/moderation), D57 (immutable), D58 (first-name), D59 (cold-start),
  D73 (infinite scroll/skeletons).
- **complexity:** M. **priority:** P1.

### jeeber-profile-reviews — DIVERGENT — P1
- **flutter_target:** EXTEND `DeliveryManProfileScreen` (`/profile/delivery-man`).
- **gap:** Screen exists (identity header + rating + recent reviews + close X) and is reachable
  from offer review via typed `extra`. Two divergences from contract+decisions: (a) it renders
  **Helpful + Reply** controls (`onHelpful`/`onReply` wired into `DeliveryReviewsList`) which
  **D57 explicitly removed** (reviews are immutable — no engagement controls; the `_data` file
  records `_removedInteractiveElements` for exactly this); (b) **"View all" is a no-op** — must
  navigate to the (missing) `reviews-list`. Also needs cold-start score hiding (D59) and
  first-name attribution (D58) confirmed on the recent-reviews snippet. Data is caller-supplied
  (gateway aggregate); release falls back to `ProfileUnavailableScreen` without typed `extra`.
- **nav_edges_missing:** `jeeber-profile-reviews->reviews-list` (View all),
  `jeeber-profile-reviews->offer-review-list` (Close present via pop).
- **mock:** profile aggregate currently fixture-driven; eventual source
  `GET /user-management/users/:userId` + reviews list (see reviews-list mock gap).
- **decisions:** D57 (remove Helpful/Reply), D58, D59, D73.
- **complexity:** M. **priority:** P1.

---

## Mock gaps to raise with backenders (consolidated)

1. `notification-prefs` repo must repoint to `/notification-service/v1/notifications/preferences`
   (currently `/users/me/notification-preferences`, 404 on live mock).
2. `escalate`/dispute-open must repoint from `POST /v1/deliveries/{id}/escalate` (404) to
   `POST /compliment-service/v1/disputes`.
3. No **password change/set** endpoint (auth is OTP-only) — needed for `password-security`.
4. No **account-deletion** endpoint (only admin suspend/reinstate) — needed for `logout-delete-account`.
5. No **support-ticket** service — needed for `support-ticket` (or extend disputes).
6. No **per-jeeber reviews-list** endpoint — needed for `reviews-list`.
7. `GET /user-management/users/me` should surface `status` (suspended/locked) for the
   `account-status` gate.

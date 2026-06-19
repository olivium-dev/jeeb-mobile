# 20 — Gap Map (Master) — Blueprint ↔ Flutter

> **Phase 1 deliverable (Team Lead integration).** The single consolidated gap table
> across all 62 blueprint screens, reconciling the 5 domain analyses
> (`20_GAP__auth.md`, `20_GAP__customer.md`, `20_GAP__jeeber-onboarding.md`,
> `20_GAP__jeeber-fulfil-money.md`, `20_GAP__shared.md`) + the design mapping
> (`22_DESIGN_NOTES.md`). Source of truth: `jeeb-mind-map/web/blueprint.json` (62 screens,
> 188 edges) + per-screen `_data/<id>.json`. Decisions = `jeeb-mind-map/docs/07_DECISIONS_LOG.md`
> + `flow-review/99_LEAD_SYNTHESIS.md`. Flutter ground truth = `11_FLUTTER_INVENTORY.md`
> (router read in full). Mock ground truth = `12_MOCK_INVENTORY.md`.
>
> Companion files: `21_NAV_PLAN.md` (routes to add + edges to wire), `30_BACKLOG.md`
> (dependency-ordered work items JM-###, the buildable unit of work). Verified 2026-06-18.

## How to read this

- **flutter_status** — `exists` (faithful to contract) · `partial` (real screen, missing
  contract elements) · `divergent` (real screen, wrong contract/placement/CTA) · `missing`
  (no implementation, or built-but-orphaned with no route/caller).
- **flutter target** — the file(s) to build/extend. "NEW" = create from scratch.
  "orphaned" = the widget exists in `lib/` but has no route and no caller.
- **gap** — the delta to close (terse; full prose in the per-domain files).
- **Cx** — complexity S/M/L. **Pri** — P0 / P1 / P2.
- **JM** — the backlog work-item id(s) in `30_BACKLOG.md` that build this screen.
- **decisions** — governing `Dnn` / `Gnn` / `Qnn` / `Rn` ids (cite, never re-litigate).

## Coverage summary (62 screens)

| flutter_status | count | screens |
|---|---|---|
| **exists** (faithful) | **4** | `walkthrough`, `rate-jeeber`, `delivery-order-chat`, `feedback-rate-delivery` |
| **partial** (real, gaps) | **13** | `social-login`, `phone-otp-verification`, `biometric-unlock`, `customer-orders-home`, `request-type-selection`, `order-chat`, `my-orders`, `order-tracking`, `saved-addresses`, `delivery-onboarding-image-upload`, `kyc-pending-status`, `jeeber-requests-home`, `delivery-requests`, `jeeber-mark-delivered`, `notification-prefs`, `location-map-pin` |
| **divergent** (real, wrong contract) | **14** | `splash`, `sign-up`, `waiting-no-coverage`, `delivered-receipt-confirm`, `cancel-request-confirm`, `address-detail-form`, `customer-profile`, `delivery-register-prompt`, `delivery-onboarding-personal-details`, `delivery-onboarding-service-area`, `kyc-identity`, `kyc-rejected`, `offer-composer`, `earnings-fees-dashboard`, `language-settings`, `location-select`, `logout-delete-account`, `dispute-open-evidence`, `jeeber-profile-reviews` |
| **missing** (none / orphaned) | **(remainder)** | `login`, `social-collision-prompt`, `verify-code`, `recover-password`, `auth-set-password`, `offer-review-list`, `offer-accept-confirm`, `order-summary-pinned`, `onboarding-funding`, `offer-kyc-gate`, `offer-insufficient-balance`, `jeeber-pending-offers`, `wallet-hub`, `wallet-activity-list`, `wallet-charge-info`, `transaction-detail`, `notifications-list`, `password-security`, `support-ticket`, `rate-the-app`, `dispute-status`, `account-status`, `reviews-list` |

**Authoritative tallies (each screen counted once, by its closest status):**

| status | # | of 62 |
|---|---|---|
| exists | **4** | 6% |
| partial | **16** | 26% |
| divergent | **19** | 31% |
| missing | **23** | 37% |
| **total** | **62** | 100% |

> Read this as: **only 4 screens are usable as-is.** 35 screens have *some* real Flutter
> (partial/divergent) — most of the work there is re-pointing CTAs/contracts, not greenfield.
> 23 screens are net-new builds (8 of which are "built-but-orphaned" widgets needing a route
> + caller: `offer-review-list`/`ClientOffersScreen`, `waiting-no-coverage`/`NoOfferTimeoutScreen`,
> `delivered-receipt-confirm`/`DeliveryReceiptScreen`, `dispute`/`DisputeScreen`).
>
> **By priority:** P0 = 20 screens · P1 = 36 screens · P2 = 6 screens.
> (P2: `walkthrough`, `saved-addresses`, `address-detail-form`, `location-map-pin`, `rate-the-app`.
> `location-map-pin` is `exists`/P2 — effectively done.)

---

## DOMAIN: AUTH (8 screens + 2 shared auth-flow screens)

> Cross-cutting blockers from `12_MOCK_INVENTORY.md`: **B1** app auth never reaches `:4010`
> (mock-gateway rewrite keys on `/auth/...` not `/v1/auth/...` — CTO brief §4). **B2** `/auth/social`
> has no `:4010` handler (app posts `/api/auth/social`). **B3** no app-client email/password,
> signup-by-email, recovery-code, or set-password mock routes (`/auth-service/auth/login` is
> admin-only). **B4** OTP length mismatch (app 6-digit vs mock `'1234'` 4-digit). These are
> foundation work (Phase 2) — gate the auth wave.
>
> **Open decision AUTH-OD-1 (BLOCKING):** blueprint is **email-first** sign-up
> (Name/Email/Password → phone-OTP); Flutter `/register` is **phone-first** (phone → OTP).
> This inverts the whole auth funnel. See §"Product questions" at end. Until resolved, login /
> sign-up / recover / set-password screens cannot be finalized.

| screen | status | flutter target | gap | Cx | Pri | JM | decisions |
|---|---|---|---|---|---|---|---|
| `splash` | divergent | `lib/app/branded_splash.dart` + `app_router.dart` `_firstRunRedirect` | Cosmetic 1.3s host, NO session check / auto-routing. Need session-aware branch: first-run→walkthrough, logged-in→last-used tab (D75), biometric→biometric-unlock, logged-out→login, suspended→account-status. Only onboarding→/register branch exists. | S | P1 | JM-006 | D79, D85, D75, D23, D8 |
| `walkthrough` | exists | `lib/features/onboarding/.../onboarding_screen.dart` (`/onboarding`) | Faithful 3-slide PageView + EN/AR toggle. Only delta: destination `/register`(phone-OTP) vs blueprint `sign-up`; route named `onboarding` not `walkthrough` (cosmetic). Resolves once AUTH-OD-1 decided. | S | P2 | JM-010 | D79, G14 |
| `login` | missing | NEW `/login` → `LoginScreen` under `lib/features/auth/` (reuse `auth/social/`) | No email/password login exists. Build email+password (eye toggle), Continue, Forgot pwd link, social row, Sign-up link, D23 biometric affordance. Blocked by AUTH-OD-1, B1, B3. | M | P0 | JM-007 | D22, D23, D65, D85 |
| `sign-up` | divergent | `lib/features/registration/.../registration_screen.dart` (`/register`) — extend OR new screen ahead of OTP | Flutter is phone-FIRST; blueprint email-FIRST (Name/Email/Password+strength → phone-OTP, G8). Missing all email-first fields, strength hint, Login link, FB button, collision edge. Architectural inversion (AUTH-OD-1). | M | P0 | JM-008 | D8, D21, D22, D65, G8 |
| `phone-otp-verification` | partial | `lib/features/registration/.../otp_verification_screen.dart` — reuse, re-parent | Best auth screen (6-digit OTP, resend, lockout). Divergence is PLACEMENT: primary entry vs step-after-signup; returning users hit it with no biometric/refresh bypass (D23). OTP length B4; never reaches mock B1. | S | P0 | JM-009 | D8, G8, D23 |
| `social-login` | partial | `lib/features/auth/social/` — extend providers + post-auth routing | Real native Google/Apple exists. Missing: Facebook provider; post-social phone-OTP enforcement (G8); collision (D22); posts `/api/auth/social` (B2). | M | P1 | JM-018 | D8, D22, G8 |
| `social-collision-prompt` | missing | NEW sheet/dialog under `lib/features/auth/` | No collision UX. D22: block 2nd method, link/continue→login, different-email→sign-up. Depends on signup/social 409 (B2/B3). | S | P1 | JM-019 | D22 |
| `recover-password` | missing | NEW `/recover` → screen under `lib/features/auth/` | No forgot-password entry. Email field, Recover→verify-code, Sign-up link, Back-to-sign-in→login. Mock B3. | S | P1 | JM-020 | D85 |
| `verify-code` | missing | NEW `/recover/verify` → screen (reuse `OmdsOtpInput`+countdown) | No email recovery-code step (distinct from phone-OTP — must NOT reuse `/auth/otp/verify`, that anchors phone). Verify→auth-set-password. Mock B3. | M | P1 | JM-021 | D90, D85 |
| `auth-set-password` | missing | NEW `/set-password` w/ `mode(recovery\|in-app-social)` param | No set/confirm-password UI. New+Re-type (eye), validation. D90 dual exit: recovery→login, in-app-social→customer-profile. Also reached from `password-security`. Mock B3. | M | P1 | JM-022 | D65, D90, D23 |
| `biometric-unlock` | partial | `lib/features/biometric_auth/.../biometric_lock_screen.dart` (`/lock`) — replace placeholder; lift logic from `lib/features/biometric_login/` | Route exists but screen is "coming soon" placeholder; `BiometricLockCubit` is no-op stub (always emits disabled) so the lock gate never engages. A more-complete unrouted `BiometricPromptScreen` exists. D23 skip-OTP path unrealized. | M | P0 | JM-005 | D23, D8, D79 |

---

## DOMAIN: CUSTOMER (15 screens)

> The **core P0 customer journey** = `customer-orders-home` → (new order) `request-type-selection`
> → `location-select` → `order-chat` (compose=broadcast) → `waiting-no-coverage` → offers →
> `offer-review-list` → `offer-accept-confirm` → `order-chat` (pinned) → `order-tracking` →
> `delivered-receipt-confirm` → `rate-jeeber`. Most pieces exist as partial/divergent; the gap
> is **re-pointing CTAs to the blueprint graph** + 4 net-new gates (offer-accept-confirm,
> order-summary-pinned, cancel-request-confirm sheet, delivered-receipt rewrite).

| screen | status | flutter target | gap | Cx | Pri | JM | decisions |
|---|---|---|---|---|---|---|---|
| `customer-orders-home` | partial | `lib/features/home_client/.../client_home_screen.dart` (Requests tab) | Real sub-tabs + FAB + Track. Missing: persistent header wallet chip + bell (no edges to wallet-hub/notifications-list); Pending sub-tab opens chat not waiting-state; search is placeholder; New Order → `/request-type` not compose. | M | P0 | JM-023 | D82, D70, D84 |
| `request-type-selection` | partial | `lib/features/request_type/.../request_type_screen.dart` (`/request-type`) | Tier radios + Continue → summary-card (divergent). Should go location-select → order-chat (compose). Mock 3 tiers vs blueprint 5 (On-the-Way, Eco missing). | M | P1 | JM-024 | D14 |
| `order-chat` | partial | `lib/features/chat/.../chat_screen.dart` via `chat_detail_screen.dart` (`/chat/:id`) | Real WhatsApp thread + offer bubbles + accepted banner. Missing: pinned order-summary strip (D71/D11); compose-request→broadcast entry; links to order-summary-pinned/dispute; inline accept has no confirm consequence. | L | P0 | JM-025 | D83, D71, D11, D70 |
| `waiting-no-coverage` | divergent | rewrite/extend `lib/features/no_offer_timeout/.../no_offer_timeout_screen.dart` (orphaned, English-only) | Exists but unrouted, no l10n, only captures tier-upgrade. Missing real wait state (N notified + countdown), no-coverage variant, one-tap re-target (D48), live offers transition, free pre-accept cancel. | M | P1 | JM-026 | D48, D69 |
| `my-orders` | partial | `lib/features/home_client/.../tabs/replies_tab.dart` (Replies sub-tab) | Real reply cards. But Check-Offers → `/chat/:id` not standalone offer-review-list; no Accept→offer-accept-confirm edge. | S | P1 | JM-027 | D82, D11 |
| `offer-review-list` | missing | wire orphaned `lib/features/client_offers/.../client_offers_screen.dart` to NEW `/requests/:id/offers` | Fully built, NO route/caller. Needs route + entry edge; per-card "Pay $X cash" (D11); name→jeeber-profile-reviews; Accept→offer-accept-confirm (not inline). | M | P1 | JM-028 | D11, D6, D58, D59 |
| `offer-accept-confirm` | missing | NEW OMDS confirm bottom sheet from offer-review-list / in-chat accept | No consequence sheet — both accept paths fire immediately. Need "Accept X's offer?" + "Pay $N cash" + "Other offers close" + Confirm (capture fee, close losers) → order-chat. The D11/D71 comprehension gate. | S | P1 | JM-029 | D11, D71, D69 |
| `cancel-request-confirm` | divergent | NEW OMDS confirm sheet (do NOT reuse `cancellation/.../cancellation_screen.dart`) | `CancellationScreen` is post-accept reason picker that may charge a fee → wrong moment/consequence/destination. Need simple pre-accept "Cancel this request?" (free, D69) → customer-orders-home. **No `_data` JSON — contract from blueprint.json only.** | S | P1 | JM-030 | D69 |
| `order-summary-pinned` | missing | NEW pinned-price header widget injected into ChatScreen + LiveTrackingScreen | No pinned authoritative-price summary anywhere. Pinned price + Jeeber rating + ETA + tier + item + "Pay cash" reminder; entry to chat + tracking link. | M | P1 | JM-031 | D11, D71, D6 |
| `order-tracking` | partial | `lib/features/live_tracking/.../live_tracking_screen.dart` (`/orders/:id/tracking`) | Real map + panel + OTP card + poll. Missing: canonical 4-step stepper (D70) as primary; pinned summary header; dispute link; no-show action sheet (D88); auto-advance to delivered-receipt-confirm. | L | P0 | JM-032 | D70, D11, D18, D88, D71 |
| `delivered-receipt-confirm` | divergent | NEW route + rewrite `lib/features/delivery_receipt/.../delivery_receipt_screen.dart` (orphaned, wrong contract) | Existing screen is an itemized finance receipt exposing Commission — wrong contract, hardcoded LBP, unrouted. Need push prompt "Did you receive?" + "Pay $N cash to <Jeeber>" + proof photo (D3) + Not yet(→dispute) + Confirm(→rating). | M | P0 | JM-033 | D3, D11 |
| `rate-jeeber` | exists | `lib/features/rating/.../rating_screen.dart` + `mutual_rating_screen.dart` | Mandatory star + optional comment, audience-parameterised. Verify: submit→customer-orders-home; completion-gating (D56, suppress back); reconcile `/feedback` vs `/mutual-rate` canonical. | S | P1 | JM-034 | D56, D6, D58, D59 |
| `customer-profile` | divergent | route real `lib/features/customer_profile/.../customer_profile_screen.dart` (`/profile/customer`) as Profile tab body, replacing dev-surface `shell/tabs/profile_tab.dart` | Profile tab is QA/dev surface (role toggle + Open Settings). Real blueprint profile is orphaned (debug fixture only). Missing all rows: wallet chip+bell, Saved addresses, Language, Logout/Delete, Register-as-delivery→onboarding (not /register), Contact us / Rate app no-ops. | L | P0 | JM-035 | D6, D90, D67, D20 |
| `saved-addresses` | partial | `lib/features/location/.../saved_locations_screen.dart` (`/settings/addresses`) | Real CRUD list. Missing default indicator; entry-edge mismatch (reached via Settings not customer-profile); edit opens sheet not address-detail-form screen. | S | P2 | JM-049 | — |
| `address-detail-form` | divergent | extend/replace `location/.../widgets/add_edit_location_sheet.dart` into a full form | Sheet collects label+category+lat/long only. Missing map preview, Building, Floor/apt, Delivery notes, COD Phone — and it's a sheet not the blueprint's map-preview-first screen. | M | P2 | JM-050 | — |

---

## DOMAIN: JEEBER-ONBOARDING (KYC funnel + offering — 13 screens)

> **The KYC chain is broken & vehicle-fields violate D20/D51.** The Jeeber wizard
> (`DmOnboardingScreen`) and KYC wizard (`KycWizardScreen`) both bake in a **Vehicle field**
> (D20 violation) and the service-area step has a **distance slider** (D51 violation). The
> chain photo → personal → service-area → kyc-identity → onboarding-funding → kyc-pending
> is NOT wired (each step submits to a Fake gateway & pops). **D38 (KYC gates offering)** is
> entirely unenforced — the "make offer" CTA fires unconditionally with no gate.

| screen | status | flutter target | gap | Cx | Pri | JM | decisions |
|---|---|---|---|---|---|---|---|
| `delivery-requests` | partial | `shell/tabs/dashboard_tab.dart` → `JeeberHomeScreen` (tab, not route) | Defining behavior — branch on KYC status (register-prompt vs feed) — NOT implemented off real status (only a debug dev-seam flag). Header wallet chip + bell absent. Availability toggle exists. | M | P0 | JM-036 | D38, D67 |
| `delivery-register-prompt` | divergent | inline `jeeber_home/.../widgets/jeeber_unregistered_view.dart` — promote to gate keyed off `user.kycStatus` OR dedicated route | Unregistered hero + Register CTA exist but switch driven ONLY by debug flag, not real KYC/role (D38). KYC-pending/not-approved branch absent; header chip/bell absent. | M | P0 | JM-036 | D38, D67 |
| `delivery-onboarding-image-upload` | partial | `DmOnboardingScreen` photo step | Photo upload + gated Continue match. Step-1 back pops instead of →register-prompt; image-upload→kyc-identity alt edge not honored (wizard submits to Fake & pops). | S | P1 | JM-039 | D67 |
| `delivery-onboarding-personal-details` | divergent | `DmOnboardingScreen` address step | **D20 VIOLATION:** renders Vehicle number field (widget + `setVehicleNumber` + state + submission DTO). Remove vehicle field across all 4 layers. State/Country/Street/Address otherwise OK. | S | P0 | JM-037 | D20, D67 |
| `delivery-onboarding-service-area` | divergent | `DmOnboardingScreen` service-area step | **D51 VIOLATION:** distance-preference slider (1–150 km). Remove static radius slider → home-base map-pin only (matching uses live location, home base fallback). Push location-map-pin; chain Continue → kyc-identity. | M | P0 | JM-038 | D51, D67 |
| `kyc-identity` | divergent | `KycWizardScreen` (`/profile/kyc`) id+selfie steps | **D20 VIOLATION:** wizard bakes a Vehicle step (`KycWizardStep.vehicle` + `VehicleType`/`vehicleRegistration` on submission). Remove it. Not chained from onboarding; submits to own status not onboarding-funding. KYC gateway calls `/v1/kyc/*` (mock uses form-builder + user-management/kyc). | L | P0 | JM-040 | D20, D52, D67 |
| `onboarding-funding` | missing | NEW `/jeeber/onboarding/funding` or final wizard step | Entire screen absent. Explain fixed non-refundable starter credit usable post-KYC (D42), reserve-10%-per-offer (D1), Top-up → wallet-charge-info (no in-app pay, D92/D93), Continue → kyc-pending (top-up allowed pre-approval D38/D39). | M | P0 | JM-041 | D28, D42, D1, D38, D39, D92, D93 |
| `kyc-pending-status` | partial | `KycStatusView` (`KycWizardStep.status`) | Pending/Approved/Rejected bodies exist. Missing outgoing links: approved→jeeber-requests-home/wallet-hub/wallet-charge-info, rejected→kyc-rejected; "top-up allowed while pending" note. Today both just pop to Profile. | M | P1 | JM-042 | D38, D39, D52, D67 |
| `kyc-rejected` | divergent | extract route / make rejected view honor edges | Rejected state's primary CTA is "resubmit" — CONTRADICTS D52/D87 (rejection is FINAL, appeal via support only). Replace with Appeal-via-support → support-ticket + Back-to-Profile → customer-profile. | S | P1 | JM-043 | D52, D87, D7 |
| `offer-kyc-gate` | missing | NEW interstitial — offering currently not KYC-gated at all | Entire gate absent. Unapproved Jeeber tapping "make offer" must hit "Get approved to start sending offers" + status + CTA→kyc-identity + top-up-allowed note + register link. Without it the **D38 core invariant is broken.** | M | P0 | JM-044 | D38, D67 |
| `offer-composer` | divergent | `OfferSubmissionScreen` (`/jeeber/requests/:id/offer`) | Bare price+ETA+note. Missing the entire **structured-economics layer (G3)**: exact 10% fee line (D37/D44), "you earn (cash)" net line (D44), "reserved/charged-if-win/released-if-not" (D1), ETA dropdown bounded by tier SLA (D14), order ref header, insufficient-balance branch. On send goes to chat not feed. | L | P0 | JM-045 | D1, D14, D15, D37, D43, D44, D45, D18, D54 |
| `offer-insufficient-balance` | missing | NEW sheet/inline on OfferSubmissionScreen | Entire flow absent. Inline "Not enough — top up to bid" + shortfall sheet + Top-up → wallet-charge-info + draft preserved & auto-sent after charge lands. Depends on offer-service 402 path + wallet balance source (both mock-missing). | M | P1 | JM-046 | D43, D92, D93, D1 |
| `jeeber-pending-offers` | missing | NEW screen OR Pending-Response sub-tab of Jeeber feed | No list of submitted offers awaiting decision. Per-row price+ETA+"Awaiting customer decision" + Withdraw (D15). **No `_data` JSON — contract from blueprint.json only.** | M | P1 | JM-047 | D15, D67 |
| `jeeber-requests-home` | partial | `JeeberHomeScreen` State 3 + `JeeberFeedTabView` (Dashboard tab) | Search + tab strip + request rows + open-chat exist. make-offer path NOT KYC-gated (→ offer-kyc-gate, JM-044). Pending/Replies tabs lack real data (→ jeeber-pending-offers, JM-047). | M | P1 | JM-048 | D38, D67 |

---

## DOMAIN: JEEBER-FULFIL & MONEY (wallet, fees, fulfilment — 9 screens)

> **The entire wallet model is missing.** `/wallet` is a "coming soon" Scaffold; there is no
> header wallet chip (D33). Wallet-hub / activity-list / charge-info / transaction-detail are all
> net-new and **gate every money CTA** in the jeeber domain (offer reserve, insufficient-balance
> top-up, onboarding-funding, kyc-pending). **The mock has NO wallet balance/ledger/transaction
> endpoint** (wallet-service is earnings-only) — flag for backenders. Economics must be expressed
> as **fee-only** (D41/D44): COD is paid directly to the Jeeber; only the 10% fee moves through
> the wallet.

| screen | status | flutter target | gap | Cx | Pri | JM | decisions |
|---|---|---|---|---|---|---|---|
| `wallet-hub` | missing | NEW screen replacing `/wallet` stub; new `lib/features/wallet/`; + header wallet chip in shell (D33) | Entirely missing. Need balance + gift-credit badge (post-KYC, D42), **affordability state card** (D43, not a capacity number — fixes S-10 false-green), reserved-now line (sum of live reserves, D1), +Top up → wallet-charge-info (D92/D93), "How fees work", typed activity preview, KYC-pending banner, states healthy/low/empty/all-reserved (D30), block money offline (D35). | L | P0 | JM-053 | D1, D41, D43, D44, D42, D33, D92, D93, D35, D30 |
| `wallet-charge-info` | missing | NEW `/wallet/charge-info` static info screen | Missing. Static, no-payment instructional screen (D92/D93): charge at authorized store, give phone/ID, pay cash, balance auto-updates, 10% fees from pre-charged balance. NO card/amount/directory. Unblocks +Top up CTAs everywhere. No network call. | S | P1 | JM-054 | D92, D93, D1, D41 |
| `wallet-activity-list` | missing | NEW `/wallet/activity` in wallet feature | Missing. Full ledger: infinite scroll + skeletons (D73), typed rows (Reserve/Fee-won/Released/Refund/Penalty/Top up/Gift) w/ amount+sign+icon+ref; tap → transaction-detail. **Mock has no ledger endpoint.** | M | P1 | JM-055 | D41, D1, D37, D2, D30, D73 |
| `transaction-detail` | missing | NEW `/wallet/transactions/:id` in wallet feature | Missing. Per-type detail: Reserve / Fee-won (exact 10% + pinned price, D37) / Released(+reason) / Refund-Penalty(+dispute link, D2) / Top up / Gift; link to order summary + dispute. **No transaction-by-id endpoint.** | M | P1 | JM-056 | D37, D1, D2, D41 |
| `earnings-fees-dashboard` | divergent | `EarningsDashboardScreen` (Earnings tab) | Real earnings screen but frames economics as gross/commission/**net-payout** (platform-takes-a-cut model). Blueprint (D41/D44) is fee-only: "Total cash earned (net, off-wallet COD)" + "Total platform fees paid (captured 10%)" + net-per-offer + member-since. Missing edges to wallet-hub/wallet-activity-list. App calls `/v1/wallet/jeeb/earnings*` vs mount `/wallet-service/v1/...` — confirm rewrite. | M | P1 | JM-052 | D44, D41, D37, D33 |
| `jeeber-mark-delivered` | partial | extend `ActiveDeliveryJeeberScreen` (`/jeeber/deliveries/:id/active`) + chat `ConfirmDeliveryActionSheet` | D70 4-step stepper exists & advances via transition API. Missing: proof-of-delivery photo (D3), optional note, "customer confirms + pays cash" copy. Nav divergence: on done → OTP handover, NOT feedback-rate-delivery (blueprint's sole edge) — mandatory rating not chained. | M | P0 | JM-051 | D70, D3, D56 |
| `delivery-order-chat` | exists | `/chat/:id` → `ChatDetailScreen` → role-aware `ChatScreen` | Faithful. "Start delivery" → `/jeeber/deliveries/:id/active` satisfies the single edge to jeeber-mark-delivered. Confirm in nav plan the chat→milestone edge resolves to active route. | S | P1 | JM-051 | D83, D70, D36 |
| `feedback-rate-delivery` | exists | `/orders/:id/feedback?mode=jeeber` + `/orders/:id/mutual-rate?mode=jeeber` | Mandatory star + optional feedback (D6/D56). Two fixes: (a) `RatingScreen` renders a close (X) — D56 forbids skip on mandatory path (mutual-rating is compliant terminal); (b) wire submit → delivery-requests (Dashboard tab). | S | P1 | JM-034 | D6, D56, D31 |

---

## DOMAIN: SHARED (notifications, settings, support, dispute, reviews, location — 17 screens)

> Auth-flow shared screens (`splash`, `biometric-unlock`) are tabled under **AUTH** above.
> Location screens (`location-select`, `location-map-pin`) feed the customer create-flow.

| screen | status | flutter target | gap | Cx | Pri | JM | decisions |
|---|---|---|---|---|---|---|---|
| `notifications-list` | missing | NEW `/notifications` → `NotificationsListScreen` (`lib/features/notifications/`); header bell entry | No inbox screen/route (`/settings/notifications` is prefs only). Mock listNotifications/markRead unconsumed. Typed rows + per-row deep-link (D84) + urgency + empty + inline confirm-receipt. (Lead-synthesis T-C: async backbone under-wired.) | L | P0 | JM-057 | D84, D64, R2 |
| `notification-prefs` | partial | extend `notification_prefs/.../notification_prefs_screen.dart` (`/settings/notifications`) | Real server-first screen. Gaps: repo path wrong (`/users/me/notification-preferences` vs mock `/notification-service/v1/notifications/preferences`); missing wallet + marketing categories (D64 requires offers/order-status/wallet/marketing, transactional locked); push-only note (R2); title. | M | P1 | JM-058 | D64, R2 |
| `language-settings` | divergent | register existing `language/.../language_settings_screen.dart`; wire customer-profile edge | Functionality complete (EN/AR + RTL via LocaleCubit) but exists in 3 places, none navigable. Blueprint models it as its own screen from customer-profile. | S | P1 | JM-059 | R3 |
| `password-security` | missing | NEW `/settings/password` → `PasswordSecurityScreen` | No current/new/confirm screen, no social-only "Set a password" entry. Edge → auth-set-password (D90, returns to Profile in-app). customer-profile row currently → whole /settings. | M | P1 | JM-061 | D90 |
| `logout-delete-account` | partial | extend `SettingsScreen._AccountSection` (dialogs exist); surface from account-status | Logout + delete confirm dialogs exist on default route (not a distinct screen). account-status sign-out edge unwired. On confirm blueprint → splash (unbuilt); app uses cubit sign-out + banner. | M | P1 | JM-062 | D5 |
| `support-ticket` | missing | NEW `/support` → `SupportTicketScreen` (`lib/features/support/`) | No contact-us/ticket screen. Subject/category + body + attach + link to order/dispute + submit + tickets list (D76). Escalation target from dispute-status/account-status/kyc-rejected. **No support-ticket mock service** (closest: compliment-service disputes). | M | P1 | JM-063 | D76 |
| `rate-the-app` | missing | NEW thin handler (native store-review sheet, e.g. `in_app_review`) from customer-profile row | Blueprint is an empty in-app outline / native OS sheet; only entry wiring + return-to-Profile. Currently no-op. | S | P2 | JM-064 | — |
| `dispute-open-evidence` | divergent | extend `EscalateScreen` (`/orders/:id/escalate`); consolidate dead `dispute/.../dispute_screen.dart` | Covers reason + ≤5 photos + comment + submit. But: posts non-existent `/v1/deliveries/{id}/escalate` (must use `POST /compliment-service/v1/disputes`); photo picker stubbed; no voice evidence (D53); no auto-attached chat + GPS/status timeline (D53 snapshot); no Contact-us link (D76); inline confirmation instead of → dispute-status. | L | P0 | JM-060 | D19, D53, D2, D54, D76 |
| `dispute-status` | missing | NEW `/disputes/:id` → `DisputeStatusScreen` | No status screen (escalate confirmation is a dead-end). Open/Resolved + outcome (refund/penalty, D2) + auto-attached evidence summary (D53) + support link (D76) + back to thread. (Lead-synthesis S-8.) | M | P1 | JM-065 | D2, D19, D53, D76 |
| `account-status` | missing | NEW `/account-status` → `AccountStatusScreen` + router redirect gate | Zero coverage. Status banner + reason + Contact-support (D76) + Sign out + **NO tab access** (D5; lead-synthesis T-F: suspended user reaches all tabs). Requires `USER.status` read on session resolve; mock carries suspension via admin mutation — getMe must surface it. | M | P1 | JM-066 | D5, D76 |
| `reviews-list` | missing | NEW `/reviews` (or `/profile/delivery-man/reviews`) → `ReviewsListScreen` (reuse delivery_man_profile widgets) | No full-reviews list ("View all" is a no-op). Infinite scroll + skeletons (D73), reviewer first name (D58), cold-start hide<5 + New badge (D59), report-a-review (D27). **No mock reviews-list source.** | M | P1 | JM-068 | D27, D57, D58, D59, D73 |
| `jeeber-profile-reviews` | divergent | extend `DeliveryManProfileScreen` (`/profile/delivery-man`) | Screen exists (identity + rating + recent reviews + close X). Divergences: renders Helpful/Reply controls D57 removed (immutable reviews); "View all" no-op → must → reviews-list. Confirm cold-start hide (D59) + first-name (D58). Release falls back to ProfileUnavailable without typed extra. | M | P1 | JM-067 | D57, D58, D59, D73 |
| `location-select` | divergent | extend `ClientLocationScreen` (`/client-location`); reconcile vs `/location` `LocationPickerScreen` | Has Current-Location radio + New-Location → map. Missing Saved-addresses entry (edge → saved-addresses; lead-synthesis Q3). Saved cards owner-injected not wired to listSavedLocations. Confirm copy + confirm→order-chat. | M | P1 | JM-024 | Q3 |
| `location-map-pin` | exists | `CaptureLocationScreen` (`/capture-location`) | Matches contract (full-screen map + fixed pin + Pin-Location CTA). Minor: current-location detection / address preview not surfaced. | S | P2 | JM-024 | — |

> **Shared screens deferred to AUTH section** (counted once there): `splash` (JM-006),
> `biometric-unlock` (JM-005). `phone-otp-verification` blueprint role is `shared` but lives in
> the auth funnel (JM-009).

---

## Reconciliation notes (duplicates / overlaps resolved across domains)

1. **`jeeber-mark-delivered` + `delivery-order-chat` → one work item JM-051.** Both are the
   jeeber fulfilment surface; the chat's "Start delivery" CTA and the active-delivery stepper
   are the same coupled unit (D83 splits the surface intentionally). The only real work is
   proof-photo + the `→ feedback-rate-delivery` edge.
2. **`delivery-requests` + `delivery-register-prompt` → one work item JM-036.** The DELIVERY tab
   *is* the KYC-status branch (register-prompt vs feed). Cannot build one without the other; the
   gate is the deliverable.
3. **`rate-jeeber` (customer) + `feedback-rate-delivery` (jeeber) → one work item JM-034.** Same
   `RatingScreen`/`MutualRatingScreen` parameterised by `mode`. Both fixes (remove skip on
   mandatory path D56; wire submit → correct tab) land together.
4. **`location-select` + `location-map-pin` → one work item JM-024 (with request-type-selection).**
   The customer create-flow location leg is a single chain; `location-map-pin` is already
   `exists`. JM-024 owns request-type→location-select→map-pin→order-chat wiring.
5. **`saved-addresses` + `address-detail-form` → JM-049 / JM-050** kept separate (different
   complexity, both P2) but in the same wave; JM-050 depends on JM-049.
6. **Wallet cluster (`wallet-hub`/`wallet-charge-info`/`wallet-activity-list`/`transaction-detail`)**
   is 4 items JM-053..JM-056. `wallet-hub` (JM-053) + `wallet-charge-info` (JM-054) are the P0/
   unblocking core (every money CTA routes to charge-info); activity-list + transaction-detail
   are the P1 follow-on (and depend on a mock ledger that does not yet exist).
7. **`cancel-request-confirm` vs `cancellation_screen.dart`:** explicitly DO NOT reuse — different
   contract (pre-accept free confirm vs post-accept reason picker that charges). New sheet (JM-030).
8. **`dispute-open-evidence` consolidation:** extend `EscalateScreen`, retire the dead unrouted
   `DisputeScreen` (English-only). One item JM-060.

---

## Mock contract gaps that gate work (from `12_MOCK_INVENTORY.md`, surfaced here)

| ref | gap | gates JM | owner |
|---|---|---|---|
| **B1** | App auth never reaches `:4010` (rewrite keys `/auth/...` not `/v1/auth/...`) | JM-007/008/009/018 | foundation (Phase 2) |
| **B2** | `POST /auth-service/auth/social` undefined; app posts `/api/auth/social` | JM-018, JM-019 | backenders |
| **B3** | No app-client email/pwd login, email-signup, recovery-code, set-password routes | JM-007/008/020/021/022 | backenders |
| **B4** | OTP length mismatch (app 6-digit vs mock 4-digit `'1234'`) | JM-009 | backenders |
| **W1** | **No wallet balance / affordability / reserved-now endpoint** (wallet-service is earnings-only) | JM-053, JM-046 | backenders |
| **W2** | **No wallet ledger endpoint** (paginated typed rows) | JM-055 | backenders |
| **W3** | **No wallet transaction-by-id endpoint** | JM-056 | backenders |
| **O1** | offer-service has no insufficient-balance 402 path (only 409 duplicate) | JM-046 | backenders |
| **K1** | KYC gateway calls `/v1/kyc/*`; mock uses form-builder-service + user-management/kyc | JM-040 | backenders / reconcile in app |
| **D1m** | No proof-of-delivery photo upload sink (D3) | JM-033, JM-051 | backenders |
| **S1** | No support-ticket service (closest: compliment-service disputes) | JM-063 | backenders |
| **R1m** | No reviews-list source (score-taking only reveals per-delivery on `:deliveryId/status`) | JM-068 | backenders |
| **U1** | getMe must surface `status` (suspended/locked) + role-level `kycStatus` (D5/D38) | JM-066, JM-036 | backenders |
| **T1** | Tier catalog returns 3 tiers; blueprint has 5 (On-the-Way, Eco missing) | JM-024 | backenders |

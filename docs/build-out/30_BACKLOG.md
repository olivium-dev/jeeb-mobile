# 30 — Backlog (Prioritized, Dependency-Ordered)

> **Phase 1 deliverable (Team Lead + POs).** One work item per **buildable unit** (a screen or a
> tightly-coupled cluster). Each item has a stable id `JM-###`, acceptance criteria written
> **Given/When/Then** so QA can author a Maestro flow keyed by `Semantics(identifier:)`
> (CTO brief §6.6 — assert on identifiers, never visible text; i18n-safe), the mock endpoints it
> touches, governing decisions, complexity, priority, dependencies (other JM ids), and a **WAVE**.
> Companions: `20_GAP_MAP.md` (per-screen gap), `21_NAV_PLAN.md` (routes/edges).
>
> **Wave rule (CTO brief §7):** a wave's items can run **in parallel** (different feature files);
> shared-file edits (`app_router.dart`, `injection_container.dart`, l10n, `shell_screen.dart`) are
> **batched centrally per wave** by one integrator first. Waves are ordered by dependency:
> **W0** foundation (auth + biometric + session/status gates) → **W1** core customer journey →
> **W2** jeeber onboarding/offering → **W3** wallet/money → **W4** shared (notifications/support/
> dispute/reviews/settings). P0 items front-load; a P1/P2 with no dependents may slot into any
> wave at/after its prerequisites.

## Identifier convention (for QA)
`<screen-id>_<element>` e.g. `login_email_field`, `offer_composer_send_cta`,
`wallet_hub_topup_cta`, `kyc_gate_start_cta`. Tab targets: `shell_tab_<id>` (requests/delivery/
profile/dashboard/earnings). Bottom sheets carry `<screen-id>_sheet_<element>`.

## Wave summary

| wave | theme | items | parallelism |
|---|---|---|---|
| **W0** | Foundation: auth funnel, biometric gate, session+status routing | JM-001..010 | after foundation/mock fixes B1–B4 land |
| **W1** | Core customer journey (request → offer → track → receipt → rate) + profile tab | JM-023..035 | depends on W0 (shell+session) |
| **W2** | Jeeber onboarding + KYC-gates-offering + offer composer | JM-036..048 | depends on W0; offer-composer depends on W3 wallet model |
| **W3** | Wallet + money (hub, charge-info, ledger, txn, earnings) | JM-051..056 | depends on W0; unblocks W2 money CTAs |
| **W4** | Shared: notifications, support, dispute, account-status, reviews, settings | JM-057..068 | depends on W1/W3 targets |

> **Note on W2↔W3 ordering:** `wallet-hub` + `wallet-charge-info` (JM-053/054, W3) must land
> **before** the offer composer's money lines (JM-045) and insufficient-balance (JM-046, W2) can
> be completed, because every "+ Top up" CTA routes to `wallet-charge-info`. Schedule W3's
> JM-053/054 in parallel with W2's onboarding items, gating only JM-045/046 on them. The wave
> numbers below reflect that: JM-053/054 are tagged W2.5 (run alongside W2).

---

## WAVE 0 — Foundation (auth + gates)

> **Gate:** mock blockers **B1** (`/v1/auth/...` rewrite), **B3** (app-client login/signup/recover/
> set-password routes), **B4** (OTP length), **U1** (getMe surfaces `status`+role `kycStatus`)
> must be fixed by foundation/backenders first (tracked in Phase 2). **AUTH-OD-1** (email-first vs
> phone-first) must be answered before JM-007/008 finalize — see §Blocking questions.

### JM-001 — Auth funnel architecture decision spike (AUTH-OD-1)
- **Type:** decision/spike (not a screen). **Blueprint:** `sign-up`, `login`, `phone-otp-verification`.
- **Output:** PO ruling on email-first (blueprint) vs phone-first (current Flutter) + the resulting
  route shape (`/sign-up` new vs extend `/register`). Records in `07_DECISIONS_LOG` style note.
- **AC:** Given the ruling, When recorded, Then JM-007/008/010 unblock with a deterministic target.
- **Cx:** S · **Pri:** P0 · **Deps:** — · **Wave:** W0 (FIRST).

### JM-005 — Biometric Unlock (replace placeholder + real cubit)
- **Blueprint:** `biometric-unlock` · **Target:** `/lock` → real `BiometricLockScreen`; lift logic from `lib/features/biometric_login/`; make `BiometricLockCubit` real.
- **AC:**
  - Given a returning logged-in user with biometric enabled, When the app cold-starts, Then `splash` routes to `/lock` and `biometric_unlock_prompt` is shown (no OTP) [D23].
  - Given the lock screen, When `biometric_unlock_authenticate_cta` succeeds, Then route to the last-used tab (`shell`) [D23/D75].
  - Given biometric fails/declined, When `biometric_unlock_use_password_link` is tapped, Then route to `/login` [JM-007].
- **Mock:** `POST /auth-service/auth/refresh`. **Decisions:** D23, D8, D79. **Cx:** M · **Pri:** P0 · **Deps:** JM-006, JM-007 · **Wave:** W0.

### JM-006 — Session-aware Splash routing
- **Blueprint:** `splash` · **Target:** `app_router.dart` `_firstRunRedirect` + `branded_splash.dart` (no UI dwell, D79/D85).
- **AC:**
  - Given first launch (onboarding incomplete), When app starts, Then route to `walkthrough` (`/onboarding`).
  - Given a logged-in customer, When app starts, Then route to the last-used tab → Requests (`shell`) [D75].
  - Given a logged-in jeeber, Then route to DELIVERY tab.
  - Given biometric enabled, Then route to `/lock` [JM-005].
  - Given logged-out returning user, Then route to `/login` [JM-007].
  - Given `getMe.status == suspended`, Then route to `/account-status` [D5, JM-066].
- **Mock:** `GET /user-management/users/me`, `POST /auth-service/auth/refresh`. **Decisions:** D79, D85, D75, D23, D8. **Cx:** S · **Pri:** P1 (P0-shaped — front-load) · **Deps:** JM-007, JM-005, JM-066 (status branch) · **Wave:** W0.

### JM-007 — Login (email/password)
- **Blueprint:** `login` · **Target:** NEW `/login` → `LoginScreen` (`lib/features/auth/`); reuse `auth/social/`.
- **AC:**
  - Given the login screen, When valid creds entered in `login_email_field`+`login_password_field` and `login_continue_cta` tapped, Then route to Requests tab (`shell`).
  - Given `login_password_visibility_toggle`, When tapped, Then password masking flips.
  - When `login_forgot_password_link` tapped → `/recover` [JM-020]; `login_signup_link` → sign-up [JM-008]; `login_social_<provider>` → social flow [JM-018].
  - Given biometric-enrolled returning user, Then `login_biometric_affordance` is shown [D23].
- **Mock:** `POST /auth-service/auth/login` (B3 — add app-client route), `POST /auth-service/auth/refresh`, `POST /push-notification/v1/devices/register`. **Decisions:** D22, D23, D65, D85. **Cx:** M · **Pri:** P0 · **Deps:** JM-001, B1, B3 · **Wave:** W0.

### JM-008 — Sign Up (email-first, decision-gated)
- **Blueprint:** `sign-up` · **Target:** extend `/register` OR new `/sign-up` (per JM-001).
- **AC:**
  - Given the sign-up screen, When `signup_name_field`+`signup_email_field`+`signup_password_field` filled and `signup_submit_cta` tapped, Then route to `phone-otp-verification` (phone required, G8).
  - Given `signup_password_strength_hint` reflects entered password; `signup_password_visibility_toggle` flips masking.
  - When `signup_login_link` → `/login`; social row → social flow; on email collision → `social-collision-prompt` [JM-019, D22].
  - Email is NOT verified at this step [D21].
- **Mock:** find-or-create-by-email signup route (B3), `POST /auth-service/auth/otp/request`. **Decisions:** D8, D21, D22, D65, G8. **Cx:** M · **Pri:** P0 · **Deps:** JM-001, JM-009, B3 · **Wave:** W0.

### JM-009 — Phone OTP Verification (re-parent + returning-user bypass)
- **Blueprint:** `phone-otp-verification` · **Target:** reuse `otp_verification_screen.dart`; re-parent behind sign-up/social; add D23 bypass.
- **AC:**
  - Given a fresh sign-up, When 6-digit OTP entered in `phone_otp_input` and `phone_otp_verify_cta` tapped, Then route to Requests tab (account active).
  - Given resend countdown, When `phone_otp_resend_cta` tapped after countdown, Then a new code is requested.
  - Given a returning logged-in user with biometric, Then this screen is bypassed (no per-login OTP) [D23].
  - OTP length contract matches mock [B4].
- **Mock:** `POST /auth-service/auth/otp/request`, `POST /auth-service/auth/otp/verify`. **Decisions:** D8, G8, D23. **Cx:** S · **Pri:** P0 · **Deps:** B1, B4 · **Wave:** W0.

### JM-010 — Walkthrough destination + naming
- **Blueprint:** `walkthrough` · **Target:** `onboarding_screen.dart`.
- **AC:** Given last slide, When `walkthrough_get_started_cta` (or Skip) tapped, Then route to sign-up (per JM-001). **Mock:** —. **Decisions:** D79, G14. **Cx:** S · **Pri:** P2 · **Deps:** JM-001 · **Wave:** W0.

### JM-018 — Social Login (FB + post-auth routing)
- **Blueprint:** `social-login` · **Target:** extend `lib/features/auth/social/`.
- **AC:**
  - Given a social sign-in success with no phone on file, Then route to `phone-otp-verification` (G8) — NOT straight home.
  - Given a Facebook provider button `social_login_facebook_cta` is present alongside Google/Apple.
  - Given a 409 collision, Then route to `social-collision-prompt` [D22, JM-019].
- **Mock:** `POST /auth-service/auth/social` (B2 — define; reconcile app's `/api/auth/social`). **Decisions:** D8, D22, G8. **Cx:** M · **Pri:** P1 · **Deps:** JM-009, JM-019, B2 · **Wave:** W0.

### JM-019 — Social/Email Collision Prompt
- **Blueprint:** `social-collision-prompt` · **Target:** NEW sheet/dialog under `lib/features/auth/`.
- **AC:** Given a collision (email registered via another method), Then show `social_collision_sheet`; `social_collision_continue_cta` → `/login`; `social_collision_other_email_cta` → sign-up [D22]. **Mock:** depends on 409 from signup/social (B2/B3). **Decisions:** D22. **Cx:** S · **Pri:** P1 · **Deps:** JM-018, JM-008 · **Wave:** W0.

### JM-020 — Recover Password (request code)
- **Blueprint:** `recover-password` · **Target:** NEW `/recover`.
- **AC:** Given `recover_email_field` filled, When `recover_submit_cta` tapped, Then route to `/recover/verify` (code emailed) [JM-021]; `recover_signup_link`/`recover_back_to_signin_link` wired. **Mock:** request-recovery-code route (B3). **Decisions:** D85. **Cx:** S · **Pri:** P1 · **Deps:** JM-021, B3 · **Wave:** W0.

### JM-021 — Verify Recovery Code
- **Blueprint:** `verify-code` · **Target:** NEW `/recover/verify` (reuse `OmdsOtpInput`+countdown).
- **AC:** Given a recovery code entered in `verify_code_input`, When `verify_code_submit_cta` tapped, Then route to `/set-password?mode=recovery` [JM-022]; wrong/expired shows error; `verify_code_resend_cta` re-requests. (Distinct from phone-OTP — must NOT anchor phone.) **Mock:** recovery-code verify route (B3). **Decisions:** D90, D85. **Cx:** M · **Pri:** P1 · **Deps:** JM-022, B3 · **Wave:** W0.

### JM-022 — Set Password (dual exit)
- **Blueprint:** `auth-set-password` · **Target:** NEW `/set-password?mode=recovery|in-app-social`.
- **AC:** Given `setpw_new_field`+`setpw_confirm_field` match & valid, When `setpw_submit_cta` tapped: if mode=recovery → `/login`; if mode=in-app-social → `customer-profile` [D90]. Mismatch/strength validation enforced; both eye toggles work. **Mock:** set-password route (B3), `POST /auth-service/auth/refresh`. **Decisions:** D65, D90, D23. **Cx:** M · **Pri:** P1 · **Deps:** JM-021, B3 · **Wave:** W0.

---

## WAVE 1 — Core customer journey

> **Gate:** W0 shell+session landed. The journey backbone is P0; address-manager (JM-049/050) is
> P2 and may defer to a later wave.

### JM-035 — Customer Profile tab (real screen + all rows)
- **Blueprint:** `customer-profile` · **Target:** route real `CustomerProfileScreen` as Profile tab body, replace `shell/tabs/profile_tab.dart` dev surface.
- **AC:**
  - Given the Profile tab, When opened, Then the real profile (avatar, name, per-role rating, `customer_profile_wallet_chip`, `customer_profile_bell`) renders (not the QA dev surface).
  - Each row navigates: `customer_profile_register_delivery_row` → `delivery-onboarding-image-upload` (NOT /register) [JM-039]; `..._password_row` → `password-security` [JM-061]; `..._notifications_row` → `notification-prefs`; `..._language_row` → `language-settings` [JM-059]; `..._contact_row` → `support-ticket` [JM-063]; `..._rate_app_row` → native sheet [JM-064]; `..._logout_row` → logout/delete confirm [JM-062]; `..._addresses_row` → `saved-addresses` [JM-049]; wallet chip/row → `wallet-hub` [JM-053]; bell → `notifications-list` [JM-057].
- **Mock:** `GET /user-management/users/me`, `POST /user-management/users/:userId/role/switch`, `PATCH /user-management/users/:userId/available-roles`, `GET /notification-service/v1/notifications/preferences`. **Decisions:** D6, D90, D67, D20. **Cx:** L · **Pri:** P0 · **Deps:** JM-006 · **Wave:** W1 (targets cross-wave; rows light up as targets land).

### JM-023 — Requests Tab (home) header + sub-tabs
- **Blueprint:** `customer-orders-home` · **Target:** `client_home_screen.dart`.
- **AC:**
  - Given the Requests tab, Then `orders_home_wallet_chip` → `wallet-hub` [JM-053] and `orders_home_bell` → `notifications-list` [JM-057] are present.
  - Given a pending request row, When tapped, Then route to `waiting-no-coverage` (not chat) [JM-026].
  - Given `orders_home_new_order_fab` tapped, Then route to `request-type-selection` [JM-024].
- **Mock:** `GET /delivery-service/v1/requests?status=pending|offers-received|active`. **Decisions:** D82, D70, D84. **Cx:** M · **Pri:** P0 · **Deps:** JM-026, JM-053, JM-057 · **Wave:** W1.

### JM-024 — Create-flow location leg (tier → location-select → map-pin → order-chat)
- **Blueprint:** `request-type-selection`, `location-select`, `location-map-pin` · **Target:** `request_type_screen.dart`, `client_location_screen.dart`, `capture_location_screen.dart`.
- **AC:**
  - Given a tier selected (`request_type_<tier>_radio`), When `request_type_continue_cta` tapped, Then route to `location-select` [not /request-summary].
  - Given `location_select_saved_addresses_row`, When tapped, Then route to `saved-addresses` [Q3, JM-049].
  - Given `location_select_new_location_cta`, Then route to `location-map-pin`; `capture_location_pin_cta` confirms back.
  - Given a location confirmed, When `location_select_confirm_cta` tapped, Then route to `order-chat` (compose) [JM-025].
  - Tier catalog shows 5 tiers (Flash/Express/Standard/On-the-Way/Eco) [T1 mock fix].
- **Mock:** `GET /delivery-service/v1/tiers`, `GET /user-management/users/:userId/saved-locations`. **Decisions:** D14, Q3. **Cx:** M · **Pri:** P1 · **Deps:** JM-025, JM-049 · **Wave:** W1.

### JM-025 — Order Chat (compose=broadcast, pinned summary, dispute link)
- **Blueprint:** `order-chat` · **Target:** `chat_screen.dart` via `chat_detail_screen.dart`.
- **AC:**
  - Given the chat compose state, When the first message is sent via `order_chat_composer_send`, Then the request broadcasts and routes to `waiting-no-coverage` [JM-026].
  - Given an accepted order, Then `order_chat_pinned_summary` strip shows locked price/ETA/tier/ref [D71/D11] and `order_chat_view_summary_link` → `order-summary-pinned` [JM-031].
  - Given an active order, Then `order_chat_open_dispute` → `dispute-open-evidence` [JM-060].
- **Mock:** `POST /chat-service/v1/chat/jeeb/conversations`, `.../by-request/:requestId`, `.../:conversationId`, `.../messages` (GET/POST), `.../snapshot`. **Decisions:** D83, D71, D11, D70. **Cx:** L · **Pri:** P0 · **Deps:** JM-026, JM-031 · **Wave:** W1.

### JM-026 — Waiting / No-Coverage state
- **Blueprint:** `waiting-no-coverage` · **Target:** rewrite orphaned `no_offer_timeout_screen.dart` → `/requests/:id/waiting`.
- **AC:**
  - Given a broadcast request, Then `waiting_notified_count` + `waiting_countdown` render; no-coverage variant shows when 0 notified.
  - When offers arrive, Then transition live → `waiting_review_offers_cta` → `offer-review-list` [JM-028] / Replies sub-tab.
  - `waiting_retarget_cta` → `request-type-selection` reusing original content [D48]; `waiting_cancel_cta` → `cancel-request-confirm` (free pre-accept) [JM-030, D69].
- **Mock:** `POST /matching/v1/matching/find-jeebers`, `POST /matching/v1/matching/broadcast`, `GET /delivery-service/v1/requests?status=pending`, `GET /offer-service/v1/offers?requestId=`. **Decisions:** D48, D69. **Cx:** M · **Pri:** P1 · **Deps:** JM-028, JM-030 · **Wave:** W1.

### JM-027 — Replies sub-tab CTAs
- **Blueprint:** `my-orders` · **Target:** `replies_tab.dart`.
- **AC:** Given a reply card, When `replies_check_offers_cta` tapped, Then route to `offer-review-list` [JM-028, not /chat/:id]; `replies_accept_cta` → `offer-accept-confirm` [JM-029]. **Mock:** `GET /delivery-service/v1/requests?status=offers-received`. **Decisions:** D82, D11. **Cx:** S · **Pri:** P1 · **Deps:** JM-028, JM-029 · **Wave:** W1.

### JM-028 — Offer Review (route the orphaned ClientOffersScreen)
- **Blueprint:** `offer-review-list` · **Target:** wire `client_offers_screen.dart` to NEW `/requests/:id/offers`.
- **AC:**
  - Given offers for a request, When the route opens, Then per-Jeeber `offer_card_<id>` shows price/ETA/rating + "Pay $X cash on delivery" [D11]; sort controls `offer_review_sort_<key>` work.
  - When `offer_card_<id>_name` tapped → `jeeber-profile-reviews` [JM-067]; `offer_card_<id>_accept_cta` → `offer-accept-confirm` [JM-029, not inline accept]; `offer_review_cancel_cta` → `cancel-request-confirm` [JM-030].
- **Mock:** `GET /offer-service/v1/offers?requestId=`, `POST /offer-service/v1/offers/:offerId/accept`. **Decisions:** D11, D6, D58, D59. **Cx:** M · **Pri:** P1 · **Deps:** JM-029, JM-067 · **Wave:** W1.

### JM-029 — Accept Offer Confirmation sheet
- **Blueprint:** `offer-accept-confirm` · **Target:** NEW OMDS confirm bottom sheet.
- **AC:** Given an offer chosen, When the accept sheet shows, Then `offer_accept_sheet` displays "Accept X's offer?" + "Pay $N cash on delivery" + "Other offers will close" [D11/D71]; `offer_accept_confirm_cta` captures the fee, closes losers, routes to `order-chat`; `offer_accept_cancel_cta` → back to `offer-review-list`. **Mock:** `POST /offer-service/v1/offers/:offerId/accept`. **Decisions:** D11, D71, D69. **Cx:** S · **Pri:** P1 · **Deps:** JM-025 · **Wave:** W1.

### JM-030 — Cancel Request Confirm sheet (pre-accept, free)
- **Blueprint:** `cancel-request-confirm` (no `_data` JSON — contract from blueprint.json) · **Target:** NEW OMDS confirm sheet (do NOT reuse `cancellation_screen.dart`).
- **AC:** Given a pre-accept request, When `cancel_request_sheet` shows, Then it states "free before accept, nothing charged" [D69]; `cancel_request_confirm_cta` → `customer-orders-home`; `cancel_request_keep_cta` dismisses. **Mock:** `POST /delivery-service/v1/delivery/cancel`. **Decisions:** D69. **Cx:** S · **Pri:** P1 · **Deps:** — · **Wave:** W1.

### JM-031 — Order Summary + Pinned Price (header widget)
- **Blueprint:** `order-summary-pinned` · **Target:** pinned-price header widget injected into chat + tracking (optional `/orders/:id/summary` route).
- **AC:** Given an accepted order, Then `order_summary_pinned` shows accepted price + Jeeber name/rating + ETA + tier + item summary + "Pay cash on delivery"; `order_summary_open_chat` → `order-chat`; `order_summary_track` → `order-tracking`. **Mock:** `GET /delivery-service/v1/delivery/:deliveryId`, `GET /delivery-service/v1/requests/:requestId`. **Decisions:** D11, D71, D6. **Cx:** M · **Pri:** P1 · **Deps:** JM-025, JM-032 · **Wave:** W1.

### JM-032 — Order Tracking (4-step stepper + no-show sheet + auto-advance)
- **Blueprint:** `order-tracking` · **Target:** `live_tracking_screen.dart`.
- **AC:**
  - Given an active delivery, Then `tracking_stepper` shows Ordered→Picked→In Transit→Delivered [D70] as the primary visual + `order_summary_pinned` header [JM-031].
  - When the Jeeber marks delivered, Then auto-advance to `delivered-receipt-confirm` [JM-033].
  - `tracking_dispute_cta` → `dispute-open-evidence`; `tracking_noshow_sheet` → reassign (`offer-review-list`) / re-broadcast (`waiting-no-coverage`) [D88].
- **Mock:** `GET /delivery-service/v1/delivery/:deliveryId`, `POST /delivery-service/v1/delivery/status/transition`, `GET /geolocation-service/v1/jeeb/geo/route/:deliveryId`. **Decisions:** D70, D11, D18, D88, D71. **Cx:** L · **Pri:** P0 · **Deps:** JM-031, JM-033 · **Wave:** W1.

### JM-033 — Confirm Receipt (Customer) — rewrite
- **Blueprint:** `delivered-receipt-confirm` · **Target:** NEW `/orders/:id/receipt` rewriting orphaned `delivery_receipt_screen.dart` (wrong contract today).
- **AC:** Given a delivered push, When the prompt shows, Then `receipt_prompt` reads "Did you receive your order?" + "Pay $N cash to <Jeeber>" + proof-of-delivery photo [D3]; `receipt_confirm_cta` → `rate-jeeber` (or auto-complete on timeout); `receipt_not_yet_cta` → `dispute-open-evidence`. NO commission/finance line shown (customer-facing). **Mock:** `POST /delivery-service/v1/delivery/status/transition`, `POST /unified-payment-gateway/v1/payments/cod_jeeb/record`, proof-photo sink (D1m). **Decisions:** D3, D11. **Cx:** M · **Pri:** P0 · **Deps:** JM-034 · **Wave:** W1.

### JM-034 — Rating (mutual; remove skip; wire submit) [customer + jeeber]
- **Blueprint:** `rate-jeeber` + `feedback-rate-delivery` · **Target:** `rating_screen.dart` + `mutual_rating_screen.dart`.
- **AC:**
  - Given the mandatory rating, Then there is NO dismiss/skip control on the mandatory path; back is suppressed [D56].
  - Given a customer submit, When `rating_submit_cta` tapped, Then route to `customer-orders-home`.
  - Given a jeeber submit (`?mode=jeeber`), Then route to the DELIVERY/Dashboard tab.
  - Reconcile `/feedback` vs `/mutual-rate` as the canonical terminal (mutual is compliant).
- **Mock:** `POST /score-taking-service/v1/ratings/jeeb/submit`, `GET .../jeeb/:deliveryId/status`. **Decisions:** D56, D6, D58, D59, D31. **Cx:** S · **Pri:** P1 · **Deps:** — · **Wave:** W1.

### JM-049 — Saved Addresses Manager (default + entry edge)
- **Blueprint:** `saved-addresses` · **Target:** `saved_locations_screen.dart` (`/settings/addresses`).
- **AC:** Given saved addresses, Then `saved_address_default_badge` marks the default; `saved_address_add_cta`/`saved_address_<id>_edit` → `address-detail-form` [JM-050]; reachable from `customer-profile` (and `location-select`). **Mock:** `GET/POST /user-management/users/:userId/saved-locations`. **Decisions:** —. **Cx:** S · **Pri:** P2 · **Deps:** JM-050, JM-035 · **Wave:** W1 (or defer).

### JM-050 — Address Detail Form (full screen)
- **Blueprint:** `address-detail-form` · **Target:** promote `add_edit_location_sheet.dart` → `/settings/addresses/edit`.
- **AC:** Given the form, Then it has map pin/preview + label + Building + Floor/apt + Delivery notes + COD Phone; `address_form_save_cta` → `saved-addresses`. **Mock:** `POST /user-management/users/:userId/saved-locations`. **Decisions:** —. **Cx:** M · **Pri:** P2 · **Deps:** JM-049 · **Wave:** W1 (or defer).

---

## WAVE 2 — Jeeber onboarding + offering (KYC gates offering)

> **Gate:** W0 (shell/session) + **U1** (getMe surfaces role `kycStatus`). D20/D51 violations are
> the first fixes. Offer composer money lines (JM-045) + insufficient-balance (JM-046) gate on
> W2.5 wallet (JM-053/054).

### JM-036 — DELIVERY Tab KYC gate (register-prompt vs feed)
- **Blueprint:** `delivery-requests` + `delivery-register-prompt` · **Target:** `dashboard_tab.dart` → `JeeberHomeScreen`; key the switch off real `user.kycStatus` (remove dev-seam flag).
- **AC:**
  - Given a not-registered/KYC-not-approved user, When the DELIVERY tab opens, Then `delivery_register_prompt` shows; `delivery_register_now_cta` → `delivery-onboarding-image-upload` [D38, JM-039].
  - Given a KYC-approved user, Then the feed (`jeeber-requests-home`) shows.
  - `delivery_tab_wallet_chip` → `wallet-hub` [JM-053]; `delivery_tab_bell` → `notifications-list` [JM-057].
- **Mock:** `GET /user-management/users/:userId/kyc`, `GET /delivery-service/v1/requests`. **Decisions:** D38, D67. **Cx:** M · **Pri:** P0 · **Deps:** JM-039, U1 · **Wave:** W2.

### JM-037 — Remove Vehicle field from onboarding personal-details (D20)
- **Blueprint:** `delivery-onboarding-personal-details` · **Target:** `dm_onboarding_address_step.dart` + cubit + state + `DmOnboardingSubmission`.
- **AC:** Given the personal-details step, Then NO `dm_onboarding_address_vehicle_number_field` exists (removed across widget, `setVehicleNumber`, state, DTO) [D20]; State/Country/Street/Address remain; `dm_onboarding_continue` → service-area. **Mock:** `POST /form-builder-service/v1/templates/jeeb_jeeber_v1/submit`. **Decisions:** D20, D67. **Cx:** S · **Pri:** P0 · **Deps:** — · **Wave:** W2.

### JM-038 — Service-Area home-base pin (remove distance slider, D51) + chain to KYC
- **Blueprint:** `delivery-onboarding-service-area` · **Target:** `dm_onboarding_service_area_step.dart` + remove `dm_onboarding_distance_slider.dart`.
- **AC:** Given the service-area step, Then NO distance slider (removed, D51); a home-base `service_area_map_pin` is required; `service_area_select_location` → `location-map-pin`; `dm_onboarding_continue` → `kyc-identity` [JM-040] (not Fake gateway). **Mock:** `POST /matching/v1/matching/find-jeebers`. **Decisions:** D51, D67. **Cx:** M · **Pri:** P0 · **Deps:** JM-040 · **Wave:** W2.

### JM-039 — Onboarding photo step nav fixes
- **Blueprint:** `delivery-onboarding-image-upload` · **Target:** `dm_onboarding_photo_step.dart`.
- **AC:** Given step 1, Then `dm_onboarding_back` → `delivery-register-prompt` (not maybePop); `dm_onboarding_continue` chains through the wizard (not Fake submit+pop). **Mock:** —. **Decisions:** D67. **Cx:** S · **Pri:** P1 · **Deps:** JM-036 · **Wave:** W2.

### JM-040 — KYC Identity (remove Vehicle step, D20) + chain to funding
- **Blueprint:** `kyc-identity` · **Target:** `KycWizardScreen` id+selfie steps; remove `KycWizardStep.vehicle`/`kyc_vehicle_step.dart`/`VehicleType`/`vehicleRegistration`.
- **AC:** Given the KYC wizard, Then NO vehicle step [D20]; gov-ID front/back + selfie present; chained from service-area; `kyc_submit_cta` → `onboarding-funding` [JM-041] (not the standalone status view). Reconcile gateway paths to mock (K1). **Mock:** `GET/POST /form-builder-service/v1/templates/jeeb_jeeber_v1`, `POST /user-management/users/:userId/kyc-link`. **Decisions:** D20, D52, D67. **Cx:** L · **Pri:** P0 · **Deps:** JM-041, JM-038, K1 · **Wave:** W2.

### JM-041 — Onboarding Funding (starter credit explainer)
- **Blueprint:** `onboarding-funding` · **Target:** NEW `/jeeber/onboarding/funding` (or wizard step).
- **AC:** Given KYC submitted, Then `funding_explainer` describes fixed non-refundable starter credit usable post-KYC [D42] + reserve-10%-per-offer [D1]; `funding_topup_cta` → `wallet-charge-info` [JM-054, D92/D93]; `funding_continue_cta` → `kyc-pending-status` (top-up allowed pre-approval) [D38/D39]. **Mock:** `GET /wallet-service/v1/jeeb/earnings`. **Decisions:** D28, D42, D1, D38, D39, D92, D93. **Cx:** M · **Pri:** P0 · **Deps:** JM-040, JM-042, JM-054 · **Wave:** W2.

### JM-042 — KYC Pending/Result status links
- **Blueprint:** `kyc-pending-status` · **Target:** `KycStatusView`.
- **AC:** Given approved, Then `kyc_status_feed_cta` → `jeeber-requests-home`, `kyc_status_wallet_cta` → `wallet-hub`, `kyc_status_topup_cta` → `wallet-charge-info`; given rejected, `kyc_status_view_rejection` → `kyc-rejected` [JM-043]; "top-up allowed while pending" note shown. **Mock:** `GET /user-management/users/:userId/kyc`. **Decisions:** D38, D39, D52, D67. **Cx:** M · **Pri:** P1 · **Deps:** JM-043, JM-053, JM-054 · **Wave:** W2.

### JM-043 — KYC Rejected (appeal-only, D52/D87)
- **Blueprint:** `kyc-rejected` · **Target:** extract dedicated screen/state from `KycStatusView`.
- **AC:** Given rejection (FINAL), Then NO resubmit CTA [D52/D87]; `kyc_rejected_appeal_cta` → `support-ticket` [JM-063]; `kyc_rejected_back_cta` → `customer-profile`. **Mock:** `GET /user-management/users/:userId/kyc`. **Decisions:** D52, D87, D7. **Cx:** S · **Pri:** P1 · **Deps:** JM-063 · **Wave:** W2.

### JM-044 — Offering KYC Gate (D38 invariant)
- **Blueprint:** `offer-kyc-gate` · **Target:** NEW interstitial `/jeeber/offer-gate`.
- **AC:** Given an unapproved Jeeber taps "make offer", Then route through `offer_kyc_gate` (not the composer); `gate_start_kyc_cta` → `kyc-identity`; `gate_register_link` → `delivery-register-prompt`; `gate_back_cta` → `jeeber-requests-home`; "top-up still allowed" note shown. Given an approved Jeeber, Then the gate is skipped → composer directly. **Mock:** `GET /user-management/users/:userId/kyc`. **Decisions:** D38, D67. **Cx:** M · **Pri:** P0 · **Deps:** JM-048 · **Wave:** W2.

### JM-045 — Structured Offer Composer (economics layer, G3)
- **Blueprint:** `offer-composer` · **Target:** `OfferSubmissionScreen`.
- **AC:**
  - Given the composer, Then `offer_composer_fee_line` shows exact 10% [D37/D44], `offer_composer_net_line` shows "you earn (cash)" net-per-offer [D44], `offer_composer_reserve_note` shows "reserved now / charged if win / released if not" [D1].
  - `offer_composer_eta_dropdown` is bounded by the tier SLA band [D14] (not free integer minutes); `offer_composer_order_ref` header shows "Your offer · ORD-…".
  - When `offer_composer_send_cta` tapped with sufficient balance, Then 10% reserved and route to `jeeber-requests-home` (not chat).
  - When insufficient balance, Then route to `offer-insufficient-balance` [JM-046].
- **Mock:** `POST /offer-service/v1/offers`, `GET /delivery-service/v1/tiers`. **Decisions:** D1, D14, D15, D37, D43, D44, D45, D18, D54. **Cx:** L · **Pri:** P0 · **Deps:** JM-044, JM-046, JM-053 · **Wave:** W2 (money lines gate on W2.5 wallet).

### JM-046 — Insufficient Balance to Offer (sheet)
- **Blueprint:** `offer-insufficient-balance` · **Target:** NEW sheet on `OfferSubmissionScreen`.
- **AC:** Given a send with insufficient balance, Then `insufficient_balance_sheet` shows needed-vs-available; `insufficient_topup_cta` → `wallet-charge-info` [D92/D93]; draft preserved + auto-sent after the store charge lands; `insufficient_keep_editing_cta` → composer. **Mock:** `POST /offer-service/v1/offers` (add 402 path, O1), wallet balance source (W1m). **Decisions:** D43, D92, D93, D1. **Cx:** M · **Pri:** P1 · **Deps:** JM-045, JM-054, O1, W1m · **Wave:** W2.

### JM-047 — Jeeber Pending Offers (submitted-offers list + withdraw)
- **Blueprint:** `jeeber-pending-offers` (no `_data` JSON) · **Target:** Pending-Response sub-tab of feed (or `/jeeber/pending-offers`).
- **AC:** Given submitted offers awaiting decision, Then each `pending_offer_<id>` row shows price+ETA+"Awaiting customer decision" + `pending_offer_<id>_withdraw_cta` [D15]; back → `delivery-requests`. **Mock:** `GET /offer-service/v1/offers?jeeberId=`, `DELETE /offer-service/v1/offers/:offerId`. **Decisions:** D15, D67. **Cx:** M · **Pri:** P1 · **Deps:** JM-048 · **Wave:** W2.

### JM-048 — Delivery Feed (route make-offer through gate)
- **Blueprint:** `jeeber-requests-home` · **Target:** `JeeberHomeScreen` State 3 + `JeeberFeedTabView`.
- **AC:** Given a request row, When `feed_make_offer_cta` tapped: if unapproved → `offer-kyc-gate` [JM-044], if approved → `offer-composer` [JM-045]; Pending/Replies tabs backed by real data [JM-047]. **Mock:** `GET /delivery-service/v1/requests?status=`, `GET /offer-service/v1/offers?jeeberId=`, `POST /geolocation-service/v1/availability`. **Decisions:** D38, D67. **Cx:** M · **Pri:** P1 · **Deps:** JM-044, JM-045, JM-047 · **Wave:** W2.

---

## WAVE 2.5 / 3 — Wallet + money

> **Gate:** mock **W1m** (balance/affordability/reserved-now), **W2m** (ledger), **W3m** (txn-by-id)
> must be defined by backenders. JM-053/054 run alongside W2 (unblock its money CTAs); JM-055/056
> follow once the ledger exists. JM-051/052 (fulfilment/earnings) are W2/W3.

### JM-053 — Wallet Hub (balance, affordability, reserved-now, states)
- **Blueprint:** `wallet-hub` · **Target:** REPLACE `/wallet` stub → `WalletHubScreen` (`lib/features/wallet/`) + header wallet chip in shell (D33).
- **AC:**
  - Given the wallet, Then `wallet_available_balance` + `wallet_gift_badge` (post-KYC, D42) + `wallet_affordability_card` (state copy "enough to bid"/"top up", NOT a capacity number, D43) + `wallet_reserved_now` (sum of live reserves, D1) render.
  - `wallet_topup_cta` → `wallet-charge-info` [JM-054]; `wallet_how_fees_work` explainer; `wallet_earnings_row` → `earnings-fees-dashboard`; `wallet_see_all_activity` → `wallet-activity-list`.
  - State variants healthy/low/empty/all-reserved [D30]; KYC-pending banner; money actions blocked offline [D35].
- **Mock:** wallet balance/affordability/reserved-now (**W1m — define**), `GET /wallet-service/v1/jeeb/earnings`. **Decisions:** D1, D41, D43, D44, D42, D33, D92, D93, D35, D30. **Cx:** L · **Pri:** P0 · **Deps:** JM-054, W1m · **Wave:** W2.5.

### JM-054 — Wallet Charge Info (static, no payment)
- **Blueprint:** `wallet-charge-info` · **Target:** NEW `/wallet/charge-info` static screen.
- **AC:** Given the info screen, Then it explains: charge at authorized store, give phone/ID, pay cash, balance auto-updates, 10% fees from pre-charged balance [D92/D93]; NO card/amount/directory; `charge_info_back_cta` → `wallet-hub`. No network call. **Mock:** —. **Decisions:** D92, D93, D1, D41. **Cx:** S · **Pri:** P1 (unblocks many CTAs — front-load) · **Deps:** — · **Wave:** W2.5.

### JM-055 — Wallet Activity List (typed ledger)
- **Blueprint:** `wallet-activity-list` · **Target:** NEW `/wallet/activity`.
- **AC:** Given the ledger, Then `wallet_activity_row_<id>` typed rows (Reserve/Fee-won/Released/Refund/Penalty/Top up/Gift) show amount+sign+icon+ref; infinite scroll + skeletons [D73]; tap → `transaction-detail` [JM-056]. **Mock:** wallet ledger (**W2m — define**). **Decisions:** D41, D1, D37, D2, D30, D73. **Cx:** M · **Pri:** P1 · **Deps:** JM-053, JM-056, W2m · **Wave:** W3.

### JM-056 — Transaction Detail (per-type)
- **Blueprint:** `transaction-detail` · **Target:** NEW `/wallet/transactions/:id`.
- **AC:** Given a transaction, Then `txn_detail` shows per-type copy (Fee-won = exact 10% + pinned price [D37]; Refund/Penalty + dispute link [D2]); `txn_detail_order_link` → `order-summary-pinned`; `txn_detail_dispute_link` → `dispute-open-evidence`. **Mock:** wallet txn-by-id (**W3m — define**). **Decisions:** D37, D1, D2, D41. **Cx:** M · **Pri:** P1 · **Deps:** JM-055, W3m · **Wave:** W3.

### JM-052 — Earnings & Fees Dashboard (fee-only reframe)
- **Blueprint:** `earnings-fees-dashboard` · **Target:** `EarningsDashboardScreen` (Earnings tab).
- **AC:** Given the dashboard, Then it frames economics fee-only [D41/D44]: `earnings_total_cash` ("net, off-wallet COD") + `earnings_fees_paid` ("captured 10%") + net-per-offer + member-since (NOT gross/commission/net-payout); `earnings_wallet_link` → `wallet-hub`, `earnings_activity_link` → `wallet-activity-list`. Confirm earnings path rewrite (`/v1/wallet/jeeb/earnings*` vs `/wallet-service/v1/...`). **Mock:** `GET /wallet-service/v1/jeeb/earnings`, `.../earnings/export`. **Decisions:** D44, D41, D37, D33. **Cx:** M · **Pri:** P1 · **Deps:** JM-053 · **Wave:** W3.

### JM-051 — Mark Delivered (proof photo + rating chain) [jeeber fulfilment]
- **Blueprint:** `jeeber-mark-delivered` + `delivery-order-chat` · **Target:** `ActiveDeliveryJeeberScreen` + `DeliveryStatusStepper` + chat `ConfirmDeliveryActionSheet`.
- **AC:**
  - Given the active delivery, Then `mark_delivered_proof_photo` capture [D3] + optional note + "customer confirms receipt + pays cash" copy present.
  - When `mark_delivered_cta` reaches done, Then route to `feedback-rate-delivery` [JM-034, D56] — NOT OTP handover.
  - The chat "Start delivery" CTA resolves to `/jeeber/deliveries/:id/active` (confirm in nav).
- **Mock:** `POST /delivery-service/v1/delivery/status/transition`, proof-photo sink (D1m). **Decisions:** D70, D3, D56. **Cx:** M · **Pri:** P0 · **Deps:** JM-034, D1m · **Wave:** W2 (or W3).

---

## WAVE 4 — Shared (notifications, support, dispute, account, reviews, settings)

> **Gate:** the deep-link targets these screens point to (W1/W2/W3) must exist. Mock **S1**
> (support service), **R1m** (reviews source), **D1m** (proof sink) tracked for backenders.

### JM-057 — Notifications List (inbox + deep-link dispatch)
- **Blueprint:** `notifications-list` · **Target:** NEW `/notifications` (`lib/features/notifications/`); header bell entry.
- **AC:** Given notifications, Then typed `notif_row_<id>` (offer/accepted/status/low-balance/fee/refund-penalty/topup/KYC) with timestamp; `notif_row_<id>` tap dispatches per D84: offers→`my-orders`, wallet→`wallet-hub`, dispute/offer_accepted→`order-chat`, marketing→`customer-orders-home`, kyc_approved→`jeeber-requests-home`, kyc_rejected→`kyc-rejected`, request_expired→`waiting-no-coverage`, confirm-receipt inline→`delivered-receipt-confirm`; empty state; mark-read. **Mock:** `GET /notification-service/v1/notifications?userId=`, `PATCH .../:id/read`. **Decisions:** D84, D64, R2. **Cx:** L · **Pri:** P0 · **Deps:** JM-053, JM-033, JM-026, JM-043 (targets) · **Wave:** W4.

### JM-058 — Notification Preferences (categories + repo path)
- **Blueprint:** `notification-prefs` · **Target:** `notification_prefs_screen.dart` (`/settings/notifications`).
- **AC:** Given prefs, Then categories = offers/order-status/wallet/marketing with transactional locked [D64]; repo path = `/notification-service/v1/notifications/preferences`; push-only note [R2]; `notif_prefs_<category>_toggle` debounced PATCH; `notif_prefs_back` → `customer-profile`. **Mock:** `GET/PUT /notification-service/v1/notifications/preferences`. **Decisions:** D64, R2. **Cx:** M · **Pri:** P1 · **Deps:** JM-035 · **Wave:** W4.

### JM-059 — Language Settings (register + wire)
- **Blueprint:** `language-settings` · **Target:** register `language_settings_screen.dart` at `/settings/language`; wire `customer-profile` edge.
- **AC:** Given the language screen, When `language_arabic_option` tapped, Then instant RTL flip; `language_back` → `customer-profile`. **Mock:** —. **Decisions:** R3. **Cx:** S · **Pri:** P1 · **Deps:** JM-035 · **Wave:** W4.

### JM-060 — Dispute (open + evidence) [repoint + extend]
- **Blueprint:** `dispute-open-evidence` · **Target:** extend `EscalateScreen` (`/orders/:id/escalate`); retire dead `dispute_screen.dart`.
- **AC:** Given a dispute, Then `dispute_reason`+`dispute_photos` (real image_picker, ≤5)+`dispute_voice` evidence [D53]+auto-attached chat+GPS/status timeline [D53 snapshot]; `dispute_submit_cta` posts to `POST /compliment-service/v1/disputes` and routes to `dispute-status` [JM-065]; `dispute_support_link` → `support-ticket` [D76]; `dispute_back` → `order-chat`. **Mock:** `POST /compliment-service/v1/disputes`, `GET .../conversations/:conversationId/snapshot`. **Decisions:** D19, D53, D2, D54, D76. **Cx:** L · **Pri:** P0 · **Deps:** JM-065, JM-063 · **Wave:** W4 (P0 — can start once chat snapshot exists).

### JM-065 — Dispute Status
- **Blueprint:** `dispute-status` · **Target:** NEW `/disputes/:id`.
- **AC:** Given a dispute, Then `dispute_status_state` (Open/Resolved) + outcome note (refund/penalty, D2) + evidence summary [D53]; `dispute_status_support` → `support-ticket`; `dispute_status_back` → `order-chat`. **Mock:** `GET /compliment-service/v1/disputes?status=&userId=`, `GET .../:disputeId`. **Decisions:** D2, D19, D53, D76. **Cx:** M · **Pri:** P1 · **Deps:** JM-060, JM-063 · **Wave:** W4.

### JM-063 — Support Ticket / Contact Us
- **Blueprint:** `support-ticket` · **Target:** NEW `/support` (`lib/features/support/`).
- **AC:** Given support, Then `support_category`+`support_body`+`support_attach`+`support_order_link`; `support_submit_cta` → confirmation → `customer-profile`; `support_dispute_link` → `dispute-open-evidence`; reachable from account-status/dispute-status/kyc-rejected [D76]. **Mock:** support-ticket service (**S1 — define**). **Decisions:** D76. **Cx:** M · **Pri:** P1 · **Deps:** S1 · **Wave:** W4.

### JM-064 — Rate the App (native sheet)
- **Blueprint:** `rate-the-app` · **Target:** thin handler (`in_app_review`) from customer-profile row.
- **AC:** Given the Rate-app row, When `customer_profile_rate_app_row` tapped, Then native store-review sheet invoked; returns to Profile. **Mock:** —. **Decisions:** —. **Cx:** S · **Pri:** P2 · **Deps:** JM-035 · **Wave:** W4.

### JM-061 — Password & Security
- **Blueprint:** `password-security` · **Target:** NEW `/settings/password`.
- **AC:** Given the screen, Then current/new/confirm fields + validation; social-only accounts show `password_set_entry` → `auth-set-password?mode=in-app-social` [D90]; `password_back` → `customer-profile`. **Mock:** —. **Decisions:** D90. **Cx:** M · **Pri:** P1 · **Deps:** JM-022, JM-035 · **Wave:** W4.

### JM-062 — Logout / Delete Account (surface from account-status; route to splash)
- **Blueprint:** `logout-delete-account` · **Target:** extend `SettingsScreen._AccountSection`; entry from `account-status`.
- **AC:** Given the confirm, When `logout_confirm_cta`/`delete_confirm_cta` tapped, Then session cleared and route to `splash` (`/`→first-run gate) [D5]; reachable from `account-status` [JM-066]. **Mock:** `POST /auth-service/auth/logout`, `POST /push-notification/v1/devices/unregister`. **Decisions:** D5. **Cx:** M · **Pri:** P1 · **Deps:** JM-066 · **Wave:** W4.

### JM-066 — Account Status (suspended/locked) + router gate
- **Blueprint:** `account-status` · **Target:** NEW `/account-status` + redirect gate in `app_router.dart`.
- **AC:** Given `getMe.status ∈ {suspended,locked}`, When the app resolves session, Then the router forces `/account-status` and blocks ALL tab access [D5]; `account_status_support_cta` → `support-ticket`; `account_status_signout_cta` → `logout-delete-account`. **Mock:** `GET /user-management/users/me` (must surface status, U1), `PATCH /user-management/admin/users/:userId/status`. **Decisions:** D5, D76. **Cx:** M · **Pri:** P1 (P0-shaped — gates session integrity) · **Deps:** JM-063, JM-062, U1 · **Wave:** W4 (gate logic in W0 if status branch needed by splash).

### JM-067 — Jeeber Profile Reviews (remove Helpful/Reply; wire View-all)
- **Blueprint:** `jeeber-profile-reviews` · **Target:** `DeliveryManProfileScreen` (`/profile/delivery-man`).
- **AC:** Given the profile, Then NO Helpful/Reply controls [D57]; `profile_view_all_reviews` → `reviews-list` [JM-068]; cold-start hide score until N≥5 [D59] + first-name attribution [D58]; `profile_close` → `offer-review-list`. **Mock:** `GET /user-management/users/:userId`. **Decisions:** D57, D58, D59, D73. **Cx:** M · **Pri:** P1 · **Deps:** JM-068 · **Wave:** W4.

### JM-068 — All Reviews list
- **Blueprint:** `reviews-list` · **Target:** NEW `/profile/delivery-man/reviews`.
- **AC:** Given reviews, Then infinite scroll + skeletons [D73]; reviewer first name [D58]; cold-start hide<5 + New badge [D59]; `review_<id>_report_cta` [D27]; `reviews_back` → `jeeber-profile-reviews`. **Mock:** reviews-list source (**R1m — define**). **Decisions:** D27, D57, D58, D59, D73. **Cx:** M · **Pri:** P1 · **Deps:** JM-067, R1m · **Wave:** W4.

---

## Blocking product questions (genuinely block work — cite why)

> Everything else has a deterministic answer in the blueprint/decisions. These three are NOT
> answered by the spec and block specific items. **Do not invent — escalate to PO.**

1. **AUTH-OD-1 — Email-first vs phone-first auth funnel.** Blueprint `sign-up` is email-first
   (Name/Email/Password → phone-OTP, G8); Flutter `/register` is phone-first (phone → OTP). This
   inverts the entire auth funnel and determines whether `/sign-up` is a new route or `/register`
   is extended. **Blocks:** JM-007, JM-008, JM-010 (and the `walkthrough → sign-up` destination).
   *Why genuinely blocking:* the decisions log (D8/D21/D22/G8) fixes the email + phone *fields* but
   not the *order*; the Flutter app already shipped phone-first, so this is a re-architecture call
   a PO must make, not an implementation detail.

2. **Wallet data contract (W1m/W2m/W3m) — does the mock get a real wallet model?** The mock
   wallet-service is **earnings-only**: no balance/affordability/reserved-now endpoint, no typed
   ledger, no transaction-by-id, and offer-service emits no reserve/capture/release rows. **Blocks:**
   JM-053 (affordability + reserved-now), JM-046 (insufficient-balance 402), JM-055, JM-056.
   *Why genuinely blocking:* the affordability state (D43) and reserved-now line (D1) are not
   cosmetic — they encode the core money invariant. Building wallet screens against no data source
   means inventing the wire format, which would later diverge from the real backend. Backenders
   must define these (flagged W1m–W3m, O1 in `20_GAP_MAP.md`). Wallet UI shells can start, but
   data-bound ACs cannot pass.

3. **`order-summary-pinned` — standalone screen or pinned header widget?** The design notes (§4)
   raise this; the blueprint models it as a screen with its own edges (chat ↔ tracking ↔
   transaction-detail), but functionally it is a pinned strip on chat + tracking. **Blocks** the
   route decision only (JM-031) — and `transaction-detail → order-summary-pinned` (JM-056) needs a
   navigable target if it is widget-only. *Why blocking (narrowly):* it changes whether JM-031 adds
   a route. Recommended default (pinned widget + optional route for the deep-link) is in the nav
   plan, but a PO should confirm so JM-056's link target is fixed.

> **Non-blocking design questions** (proceed with the noted default, confirm async): chat module
> OMDS tier (P3 backlog vs core — proceed as core customer surface); no `OmdsAmount`/
> `OmdsBottomNavBar` components (build local widgets per `22_DESIGN_NOTES.md`); tier-card accent
> approach. The 5-vs-3 tier catalog (T1) is a mock data fix, not a product question (blueprint
> fixes 5 tiers).

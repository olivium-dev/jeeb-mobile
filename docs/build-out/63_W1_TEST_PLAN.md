# 63 — Wave 1 Test Plan (Core Customer Journey)

> **Author:** Senior Principal QA Engineer (Sonnet, test-first). **Date:** 2026-06-18.
> **Status:** ALL W1 flows are RED (test-first). They become GREEN when each JM item ships,
> required seam seeds exist, and mock fixes T1 + D1m land.
>
> **Authority:** `30_BACKLOG.md` (W1 ACs) · `62_SEAM_HARNESS.md` (seam contract) ·
> `21_NAV_PLAN.md` (routes/edges) · `00_CTO_BRIEF.md` (§6.6 id-only assertions) ·
> `50_EXECUTION_PLAN.md` (W1 gate + pipeline).
>
> **Run recipe (copy-paste):**
> ```bash
> export JAVA_HOME="$(/usr/libexec/java_home)"
> ~/.maestro/bin/maestro --device emulator-5554 test \
>   -e APP_ID=app.jeeb.mobile.dev \
>   .maestro/flows/<flow>.yaml
> ```
> The `--device emulator-5554` flag is REQUIRED — an iPhone sim is also attached.
> The `--include-tags w1` suite form:
> ```bash
> ~/.maestro/bin/maestro --device emulator-5554 test \
>   -e APP_ID=app.jeeb.mobile.dev \
>   --include-tags w1 \
>   .maestro/flows/
> ```

---

## 1. Flow → JM Item Mapping

| JM Item | Flow File | Brief |
|---------|-----------|-------|
| JM-023 | `jm-023-requests-home.yaml` | Requests tab home: header chip+bell, pending row → waiting, FAB → create flow |
| JM-024 | `jm-024-create-flow.yaml` | Create flow: tier → location-select → map-pin → order-chat (5 tiers) |
| JM-025 | `jm-025-order-chat.yaml` | Order chat: compose+broadcast → waiting, pinned summary, dispute link |
| JM-026 | `jm-026-waiting-no-coverage.yaml` | Waiting/no-coverage: count+countdown, offers → review, retarget, cancel |
| JM-027 | `jm-027-replies-sub-tab.yaml` | Replies sub-tab: check-offers → offer list, accept → accept sheet |
| JM-028 | `jm-028-offer-review.yaml` | Offer review: cards+sort, tap name → profile, accept → sheet, cancel → sheet |
| JM-029 | `jm-029-accept-offer-confirm.yaml` | Accept sheet: content, confirm → chat, cancel → offer list |
| JM-030 | `jm-030-cancel-request-confirm.yaml` | Cancel sheet: free note, confirm → home, keep → dismiss |
| JM-031 | `jm-031-order-summary-pinned.yaml` | Pinned summary widget: fields, open-chat, track → tracking, visible in both contexts |
| JM-032 | `jm-032-order-tracking.yaml` | Tracking: 4-step stepper, auto-advance to receipt, dispute, no-show sheet |
| JM-033 | `jm-033-confirm-receipt.yaml` | Receipt confirm: content+no-commission, confirm → rating, not-yet → dispute |
| JM-034 | `jm-034-rating.yaml` | Rating: no skip, customer submit → home, jeeber submit → dashboard |
| JM-035 | `jm-035-customer-profile.yaml` | Customer profile: real screen, all row navigations, wallet+bell AP-9 guard |
| JM-049 | `jm-049-saved-addresses.yaml` | Saved addresses: default badge, add/edit → form, dual entry points |
| JM-050 | `jm-050-address-detail-form.yaml` | Address form: all fields, save → saved-addresses |

---

## 2. Full Semantics Identifier Contract (grouped by screen)

Engineers must implement `Semantics(identifier: '<id>')` on every widget listed below.
Convention: `<screen-id>_<element>` per `30_BACKLOG.md §Identifier convention`.
**Coined identifiers** (AC implied but not named) are marked **[COINED]** — review with tech lead before implementation.

### 2.1 Customer Orders Home / Requests Tab (JM-023)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `orders_home_wallet_chip` | Wallet chip in header | → wallet-hub (JM-053, guarded cross-wave) |
| `orders_home_bell` | Bell icon in header | → notifications-list (JM-057, guarded cross-wave) |
| `orders_home_new_order_fab` | New order FAB | → request-type-selection |
| `orders_home_request_row_0` | First request list row (index 0) | **[COINED]** — AC says "pending request row"; coins index-0 variant for seeded fixture. `orders_home_request_row_<n>` pattern |
| `orders_home_replies_tab` | Replies sub-tab chip | **[COINED]** — JM-027 AC names Replies sub-tab; this is the tap target on the Requests tab |

### 2.2 Request Type Selection (JM-024)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `request_type_flash_radio` | Flash tier radio | T1: all 5 tiers required |
| `request_type_express_radio` | Express tier radio | T1 |
| `request_type_standard_radio` | Standard tier radio | T1 |
| `request_type_on_the_way_radio` | On-the-Way tier radio | T1 |
| `request_type_eco_radio` | Eco tier radio | T1 |
| `request_type_continue_cta` | Continue button | → location-select |

### 2.3 Location Select (JM-024)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `location_select_saved_addresses_row` | Saved addresses row | → saved-addresses (JM-049, Q3) |
| `location_select_new_location_cta` | New location CTA | → location-map-pin |
| `location_select_confirm_cta` | Confirm location button | → order-chat |

### 2.4 Location Map Pin (JM-024)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `capture_location_pin_cta` | Confirm pin button | Returns to location-select |

### 2.5 Order Chat (JM-025)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `order_chat_composer_input` | Message input field | **[COINED]** — AC names `order_chat_composer_send`; the text field needs its own id for inputText |
| `order_chat_composer_send` | Send button | Broadcasts first message |
| `order_chat_pinned_summary` | Pinned summary strip | Visible on accepted order; signature id for accepted state |
| `order_chat_view_summary_link` | View summary link on strip | → order-summary-pinned (JM-031) |
| `order_chat_open_dispute` | Dispute link/button | Active on accepted/active orders → dispute-open-evidence |

### 2.6 Waiting / No-Coverage (JM-026)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `waiting_notified_count` | Number of jeebers notified | Signature id for broadcast state |
| `waiting_countdown` | Countdown timer | Visible in broadcast state |
| `waiting_no_coverage_state` | No-coverage variant root | **[COINED]** — AC says "no-coverage variant shows when 0 notified"; coins the state container id |
| `waiting_review_offers_cta` | Review offers button | Appears when offers arrive; → offer-review-list |
| `waiting_retarget_cta` | Re-target CTA | → request-type-selection (D48) |
| `waiting_cancel_cta` | Cancel request CTA | → cancel-request-confirm sheet (D69) |

### 2.7 Replies Sub-tab (JM-027)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `replies_check_offers_cta` | Check offers button on reply card | → offer-review-list (not /chat/:id) |
| `replies_accept_cta` | Accept button on reply card | → offer-accept-confirm sheet |

### 2.8 Offer Review List (JM-028)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `offer_review_list_root` | Screen root | Signature id for offer-review-list route |
| `offer_card_0` | First offer card container | **[COINED]** — AC says `offer_card_<id>`; coins index-0 for seeded fixture; full pattern `offer_card_<jeeber-id>` |
| `offer_card_0_price` | Price on first card | **[COINED]** — AC says cards show price; no explicit id given |
| `offer_card_0_eta` | ETA on first card | **[COINED]** |
| `offer_card_0_cash_on_delivery_label` | "Pay $X cash on delivery" label | **[COINED]** — D11: must show cash on delivery copy |
| `offer_card_0_name` | Jeeber name tap target | → jeeber-profile-reviews |
| `offer_card_0_accept_cta` | Accept button on first card | → offer-accept-confirm sheet |
| `offer_review_sort_price` | Sort by price control | **[COINED]** — AC says `offer_review_sort_<key>`; coins `price` as primary key; pattern `offer_review_sort_<key>` |
| `offer_review_cancel_cta` | Cancel request CTA | → cancel-request-confirm sheet |

### 2.9 Offer Accept Confirm Sheet (JM-029)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `offer_accept_sheet` | Sheet root | Signature id for accept-confirm sheet |
| `offer_accept_jeeber_name` | Jeeber name on sheet | **[COINED]** — AC says "Accept X's offer?"; no explicit id |
| `offer_accept_price_label` | "Pay $N cash on delivery" label | **[COINED]** — AC says "Pay $N cash on delivery" [D11] |
| `offer_accept_other_offers_note` | "Other offers will close" note | **[COINED]** — AC says "Other offers will close" [D71] |
| `offer_accept_confirm_cta` | Confirm button | Captures fee; routes to order-chat |
| `offer_accept_cancel_cta` | Cancel button | → back to offer-review-list |

### 2.10 Cancel Request Confirm Sheet (JM-030)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `cancel_request_sheet` | Sheet root | Signature id for cancel-request sheet |
| `cancel_request_free_note` | "Free before accept, nothing charged" copy | **[COINED]** — AC says it "states free before accept, nothing charged" [D69]; coins the element id |
| `cancel_request_confirm_cta` | Confirm cancel button | → customer-orders-home |
| `cancel_request_keep_cta` | Keep request / dismiss button | Dismisses sheet |

### 2.11 Order Summary Pinned Widget (JM-031)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `order_summary_pinned` | Pinned summary widget root | Injected in chat + tracking; signature id |
| `order_summary_price` | Accepted price display | **[COINED]** — AC says "accepted price" [D11] |
| `order_summary_jeeber_name` | Jeeber name + rating | **[COINED]** |
| `order_summary_eta` | ETA display | **[COINED]** |
| `order_summary_tier` | Tier label | **[COINED]** |
| `order_summary_cash_label` | "Pay cash on delivery" label | **[COINED]** — AC says "Pay cash on delivery" |
| `order_summary_open_chat` | Chat CTA on summary | → order-chat |
| `order_summary_track` | Track CTA on summary | → order-tracking |

### 2.12 Order Tracking (JM-032)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `tracking_stepper` | 4-step stepper widget | Signature id for tracking screen |
| `tracking_step_ordered` | Step 1: Ordered | **[COINED]** — AC says "Ordered→Picked→In Transit→Delivered" [D70] |
| `tracking_step_picked` | Step 2: Picked | **[COINED]** |
| `tracking_step_in_transit` | Step 3: In Transit | **[COINED]** |
| `tracking_step_delivered` | Step 4: Delivered | **[COINED]** |
| `tracking_dispute_cta` | Dispute CTA | → dispute-open-evidence |
| `tracking_noshow_cta` | No-show CTA | Opens no-show sheet [D88] |
| `tracking_noshow_sheet` | No-show sheet root | **[COINED]** — AC says "tracking_noshow_sheet" |
| `tracking_noshow_reassign_cta` | Reassign CTA on no-show sheet | → offer-review-list [D88] |
| `tracking_noshow_rebroadcast_cta` | Re-broadcast CTA on no-show sheet | → waiting-no-coverage [D88] |

### 2.13 Delivered Receipt Confirm (JM-033)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `receipt_prompt` | Screen root | Signature id for `/orders/:id/receipt` |
| `receipt_cash_to_jeeber_label` | "Pay $N cash to <Jeeber>" copy | **[COINED]** — AC says "Pay $N cash to <Jeeber>" [D11] |
| `receipt_proof_photo` | Proof-of-delivery photo | **[COINED]** — AC says "proof-of-delivery photo" [D3] |
| `receipt_confirm_cta` | Confirm receipt button | → rate-jeeber |
| `receipt_not_yet_cta` | Not yet button | → dispute-open-evidence |
| `receipt_no_commission_line` | Commission/fee line | Must NOT be visible (AC4 negative assertion) [D11] |

### 2.14 Rating Screen (JM-034)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `rating_root` | Screen root | Signature id; present on both /feedback and /mutual-rate |
| `rating_submit_cta` | Submit rating button | Customer → home; Jeeber → dashboard |
| `rating_skip_cta` | Skip/dismiss control | Must NOT be visible on mandatory path [D56] |

### 2.15 Customer Profile Tab (JM-035)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `customer_profile_wallet_chip` | Wallet chip in header | → wallet-hub (guarded, AP-9); also destination for JM-022 in-app-social exit (from W0 plan) |
| `customer_profile_bell` | Bell icon in header | → notifications-list (guarded, AP-9) |
| `customer_profile_avatar` | Profile avatar | **[COINED]** — AC says "avatar" renders |
| `customer_profile_name` | Profile name display | **[COINED]** |
| `customer_profile_rating` | Per-role rating display | **[COINED]** — AC says "per-role rating" [D6] |
| `customer_profile_register_delivery_row` | Register as delivery row | → delivery-onboarding-image-upload (NOT /register) |
| `customer_profile_password_row` | Password & security row | → password-security (JM-061, W4) |
| `customer_profile_notifications_row` | Notifications row | → notification-prefs (JM-058, W4) |
| `customer_profile_language_row` | Language row | → language-settings (JM-059, W4) |
| `customer_profile_contact_row` | Contact/support row | → support-ticket (JM-063, W4) |
| `customer_profile_rate_app_row` | Rate the app row | → native store-review sheet (JM-064, W4) |
| `customer_profile_logout_row` | Logout row | → logout confirm (JM-062, W4) |
| `customer_profile_addresses_row` | Saved addresses row | → saved-addresses (JM-049) |

### 2.16 Saved Addresses (JM-049)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `saved_address_add_cta` | Add new address CTA | → address-detail-form; also signature id for the screen |
| `saved_address_default_badge` | Default address badge | **[COINED]** — AC says `saved_address_default_badge` |
| `saved_address_0_edit` | Edit button on first address | **[COINED]** — AC says `saved_address_<id>_edit`; coins index-0 for seeded fixture; pattern `saved_address_<n>_edit` |

### 2.17 Address Detail Form (JM-050)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `address_form_save_cta` | Save address button | → saved-addresses; signature id for form screen |
| `address_form_map_pin` | Map pin / preview widget | **[COINED]** — AC says "map pin/preview" |
| `address_form_label` | Label text field | **[COINED]** |
| `address_form_building` | Building text field | **[COINED]** |
| `address_form_floor_apt` | Floor/apt text field | **[COINED]** |
| `address_form_delivery_notes` | Delivery notes field | **[COINED]** |
| `address_form_cod_phone` | COD phone field | **[COINED]** |

### 2.18 Shell Navigation (used across flows — existing + W1 additions)

| Identifier | Widget | Notes |
|------------|--------|-------|
| `shell_tab_requests` | Requests tab | Customer home (from W0 plan) |
| `shell_tab_profile` | Profile tab | Customer profile tab |
| `shell_tab_dashboard` | Dashboard tab | Jeeber home (from W0 plan §3 note) |

### 2.19 Cross-wave destination ids asserted in W1 (target screens built in other waves)

| Identifier | Screen | Built in |
|------------|--------|----------|
| `dm_onboarding_continue` | Delivery onboarding | W2 (JM-039) |
| `dispute_reason` | Dispute open evidence | W4 (JM-060) |
| `profile_view_all_reviews` | Jeeber profile reviews | W4 (JM-067) |
| `password_back` | Password security | W4 (JM-061) |
| `notif_prefs_back` | Notification prefs | W4 (JM-058) |
| `language_back` | Language settings | W4 (JM-059) |
| `support_submit_cta` | Support ticket | W4 (JM-063) |
| `logout_confirm_cta` | Logout confirm | W4 (JM-062) |

---

## 3. Navigation Assertion Matrix

| Flow | Tapped / Triggered | Expected Destination ID | JM Dep / Notes |
|------|--------------------|------------------------|----------------|
| jm-023 | `orders_create_request_button` | `location_select_confirm_cta` | JM-024 AC1a (S3) |
| jm-023 | `orders_home_request_row_0` (pending) | `waiting_notified_count` | JM-026; needs pending_request seed |
| jm-023 | `orders_home_wallet_chip` | `shell_tab_requests` (AP-9 root survives) | JM-053 (W2.5 guard) |
| jm-023 | `orders_home_bell` | `shell_tab_requests` (AP-9 root survives) | JM-057 (W4 guard) |
| jm-024 | `orders_create_request_button` | `location_select_confirm_cta` + `compose_tier_row` | JM-024 AC1a (S3) |
| jm-024 | `request_type_continue_cta` (tier selected, dev-seam entry) | `location_select_confirm_cta` | JM-024 AC1b |
| jm-024 | `location_select_saved_addresses_row` | `saved_address_add_cta` | JM-049 |
| jm-024 | `location_select_new_location_cta` | `capture_location_pin_cta` | JM-024 |
| jm-024 | `capture_location_pin_cta` | `location_select_confirm_cta` (back) | JM-024 |
| jm-024 | `location_select_confirm_cta` | `order_chat_composer_send` | JM-025 |
| jm-025 | `order_chat_composer_send` (first msg) | `waiting_notified_count` | JM-026 |
| jm-025 | `order_chat_view_summary_link` | `order_summary_pinned` | JM-031 |
| jm-025 | `order_chat_open_dispute` | `dispute_reason` | JM-060 (W4) |
| jm-026 | `waiting_review_offers_cta` | `offer_review_list_root` | JM-028 |
| jm-026 | `waiting_retarget_cta` | `request_type_continue_cta` | JM-024 (D48) |
| jm-026 | `waiting_cancel_cta` | `cancel_request_sheet` | JM-030 |
| jm-027 | `replies_check_offers_cta` | `offer_review_list_root` | JM-028 (not /chat/:id) |
| jm-027 | `replies_accept_cta` | `offer_accept_sheet` | JM-029 |
| jm-028 | `offer_card_0_name` | `profile_view_all_reviews` | JM-067 (W4) |
| jm-028 | `offer_card_0_accept_cta` | `offer_accept_sheet` | JM-029 (not inline) |
| jm-028 | `offer_review_cancel_cta` | `cancel_request_sheet` | JM-030 |
| jm-029 | `offer_accept_confirm_cta` | `order_chat_pinned_summary` | JM-025 (D11/D71) |
| jm-029 | `offer_accept_cancel_cta` | `offer_review_list_root` | JM-028 |
| jm-030 | `cancel_request_confirm_cta` | `orders_home_new_order_fab` | JM-023 |
| jm-030 | `cancel_request_keep_cta` | `cancel_request_sheet` NOT visible | Sheet dismissed |
| jm-031 | `order_summary_open_chat` | `order_chat_pinned_summary` | JM-025 |
| jm-031 | `order_summary_track` | `tracking_stepper` | JM-032 |
| jm-032 | Delivery → delivered (seam) | `receipt_prompt` (auto-advance) | JM-033 |
| jm-032 | `tracking_dispute_cta` | `dispute_reason` | JM-060 (W4) |
| jm-032 | `tracking_noshow_reassign_cta` | `offer_review_list_root` | JM-028 (D88) |
| jm-032 | `tracking_noshow_rebroadcast_cta` | `waiting_notified_count` | JM-026 (D88) |
| jm-033 | `receipt_confirm_cta` | `rating_submit_cta` | JM-034 |
| jm-033 | `receipt_not_yet_cta` | `dispute_reason` | JM-060 (W4) |
| jm-034 | `rating_submit_cta` (customer) | `orders_home_new_order_fab` | JM-023 |
| jm-034 | `rating_submit_cta` (jeeber) | `shell_tab_dashboard` | Shell jeeber tab |
| jm-035 | `customer_profile_register_delivery_row` | `dm_onboarding_continue` | JM-039 (W2, NOT /register) |
| jm-035 | `customer_profile_addresses_row` | `saved_address_add_cta` | JM-049 |
| jm-035 | `customer_profile_password_row` | `password_back` | JM-061 (W4) |
| jm-035 | `customer_profile_notifications_row` | `notif_prefs_back` | JM-058 (W4) |
| jm-035 | `customer_profile_language_row` | `language_back` | JM-059 (W4) |
| jm-035 | `customer_profile_contact_row` | `support_submit_cta` | JM-063 (W4) |
| jm-035 | `customer_profile_logout_row` | `logout_confirm_cta` | JM-062 (W4) |
| jm-035 | `customer_profile_wallet_chip` | `shell_tab_profile` (AP-9) | JM-053 (W2.5 guard) |
| jm-035 | `customer_profile_bell` | `shell_tab_profile` (AP-9) | JM-057 (W4 guard) |
| jm-049 | `saved_address_add_cta` | `address_form_save_cta` | JM-050 |
| jm-049 | `saved_address_0_edit` | `address_form_save_cta` | JM-050 |
| jm-050 | `address_form_save_cta` | `saved_address_add_cta` | JM-049 |

---

## 4. Required Test-Data / Seam State (Contract for Backender/Seam Owner)

> **Seam key `jeeb.seam.journey` does NOT exist yet.** All entries below marked **[FLAG]**
> are new seam values that must be added to:
> 1. `MainActivity.kt` `seamKeys` whitelist
> 2. `DevSeamConfig.dart` (`JourneySeed` enum + typed field)
> 3. `SessionSeamBootstrap.seed()` (journey seed branch)
> 4. Mock fixture data in `jeeb-mock-backend/src/fixtures/` for `user-client-001` and/or
>    `user-jeeber-002` as appropriate.
>
> The `jeeb.seam.session=customer_logged_in` base seed already exists (§62_SEAM_HARNESS.md).
> Journey seeds are layered on top of the session seed.

### 4.1 Consolidated new seam keys needed for W1

| Seam Key | Value | What it seeds | Affected Flows | Priority |
|----------|-------|---------------|----------------|----------|
| `jeeb.seam.journey` | `pending_request` | 1 request in state=`pending` for `user-client-001`, notified_count>0, with a `request_id` constant (e.g. `req-client-001-pending`) | jm-023, jm-026, jm-030 | **P0** |
| `jeeb.seam.journey` | `pending_request_no_coverage` | 1 request in state=`pending` for `user-client-001`, notified_count=0 (no nearby jeebers) | jm-026 (AC1b) | P1 |
| `jeeb.seam.journey` | `offers_received` | 1 request in state=`offers-received` for `user-client-001` WITH >=2 offers from distinct mock jeebers, each with price/ETA/mock-jeeber-name/rating; `request_id` = `req-client-001-offers` | jm-026, jm-027, jm-028, jm-029 | **P0** |
| `jeeb.seam.journey` | `order_accepted` | 1 request in state=`accepted`, 1 delivery in state=`accepted` (or `in_transit`), 1 conversation with `conversation_id` for `user-client-001`; pinned summary fields populated (price, jeeber name, ETA, tier) | jm-025, jm-029, jm-031 | **P0** |
| `jeeb.seam.journey` | `active_delivery` | 1 delivery in state=`active`/`in_transit` for `user-client-001`; tracking stepper data available; `delivery_id` constant (e.g. `del-client-001-active`) | jm-025, jm-032 | **P0** |
| `jeeb.seam.journey` | `delivery_marked_done` | 1 delivery transitioning to/already in state=`delivered` for `user-client-001`; receipt_prompt should show on app startup; proof photo URL in mock response | jm-032, jm-033, jm-034 | **P0** |
| `jeeb.seam.journey` | `jeeber_rating_pending` | 1 delivery in state=`delivered` for `user-jeeber-002` with rating not yet submitted; app starts at rating screen in jeeber mode | jm-034 (AC3) | P1 |
| `jeeb.seam.journey` | `has_saved_addresses` | >=1 saved address with `is_default=true` for `user-client-001` in mock saved-locations fixture | jm-049 | P2 |

### 4.2 Mock endpoint fixes (backender contract)

| Fix Ref | Description | Gates |
|---------|-------------|-------|
| **T1** | `GET /delivery-service/v1/tiers` must return exactly 5 tiers: Flash, Express, Standard, On-the-Way, Eco | jm-024 AC5 |
| **D1m** | Proof-photo upload sink (endpoint to POST proof photo from receipt screen) | jm-033 (receipt proof photo) |

### 4.3 Stable mock fixture IDs (seam owner must pick and document)

The following stable IDs must be documented in `jeeb-mock-backend/src/fixtures/seed.ts`
so flows can reference them if deep-linking is needed:

| ID Constant | Description |
|-------------|-------------|
| `req-client-001-pending` | Seeded pending request for user-client-001 |
| `req-client-001-offers` | Seeded offers-received request for user-client-001 |
| `req-client-001-accepted` | Seeded accepted request for user-client-001 |
| `del-client-001-active` | Seeded active delivery for user-client-001 |
| `del-client-001-delivered` | Seeded delivered delivery for user-client-001 |
| `del-jeeber-002-delivered` | Seeded delivered delivery for user-jeeber-002 (for rating) |
| `offer-001` / `offer-002` | Two seeded offers against req-client-001-offers |

---

## 5. Coined Identifiers Summary

All identifiers coined by QA (AC implied but not named by the backlog item). Engineers must
implement `Semantics(identifier: '<id>')` exactly as written. Review with tech lead before
implementation.

| Coined Identifier | Screen / JM | Reason Coined |
|-------------------|-------------|---------------|
| `orders_home_request_row_0` | Requests home / JM-023 | AC says "pending request row"; coins index-0 for list item pattern |
| `orders_home_replies_tab` | Requests home / JM-027 | JM-027 AC names Replies sub-tab; the tap target on the home tab is not explicitly named |
| `order_chat_composer_input` | Order chat / JM-025 | AC names `order_chat_composer_send` only; the text input needs its own id for flow inputText |
| `waiting_no_coverage_state` | Waiting / JM-026 | AC says "no-coverage variant shows when 0 notified"; no explicit id given |
| `offer_card_0` | Offer review / JM-028 | AC says `offer_card_<id>`; coins index-0 for seeded fixture |
| `offer_card_0_price` | Offer review / JM-028 | AC says cards show price; no explicit id |
| `offer_card_0_eta` | Offer review / JM-028 | AC says cards show ETA; no explicit id |
| `offer_card_0_cash_on_delivery_label` | Offer review / JM-028 | D11: "Pay $X cash on delivery" copy; no id named |
| `offer_card_0_name` | Offer review / JM-028 | AC says `offer_card_<id>_name`; coins index-0 |
| `offer_card_0_accept_cta` | Offer review / JM-028 | AC says `offer_card_<id>_accept_cta`; coins index-0 |
| `offer_review_sort_price` | Offer review / JM-028 | AC says `offer_review_sort_<key>`; coins `price` as primary sort key |
| `offer_accept_jeeber_name` | Accept sheet / JM-029 | AC says "Accept X's offer?"; no element id named |
| `offer_accept_price_label` | Accept sheet / JM-029 | AC says "Pay $N cash on delivery" [D11]; no id |
| `offer_accept_other_offers_note` | Accept sheet / JM-029 | AC says "Other offers will close" [D71]; no id |
| `cancel_request_free_note` | Cancel sheet / JM-030 | AC says "free before accept, nothing charged" [D69]; no id |
| `order_summary_price` | Order summary widget / JM-031 | AC says "accepted price"; no id |
| `order_summary_jeeber_name` | Order summary widget / JM-031 | AC says "Jeeber name/rating"; no id |
| `order_summary_eta` | Order summary widget / JM-031 | AC says "ETA"; no id |
| `order_summary_tier` | Order summary widget / JM-031 | AC says "tier"; no id |
| `order_summary_cash_label` | Order summary widget / JM-031 | AC says "Pay cash on delivery"; no id |
| `tracking_step_ordered` | Order tracking / JM-032 | AC says "Ordered→Picked→In Transit→Delivered" [D70]; no step ids |
| `tracking_step_picked` | Order tracking / JM-032 | Same |
| `tracking_step_in_transit` | Order tracking / JM-032 | Same |
| `tracking_step_delivered` | Order tracking / JM-032 | Same |
| `tracking_noshow_sheet` | Order tracking / JM-032 | AC says "tracking_noshow_sheet"; named in AC but no element sub-ids given |
| `tracking_noshow_reassign_cta` | Order tracking / JM-032 | AC says "reassign" and "re-broadcast" from no-show sheet; coins cta ids [D88] |
| `tracking_noshow_rebroadcast_cta` | Order tracking / JM-032 | Same |
| `receipt_cash_to_jeeber_label` | Receipt confirm / JM-033 | AC says "Pay $N cash to <Jeeber>"; no id |
| `receipt_proof_photo` | Receipt confirm / JM-033 | AC says "proof-of-delivery photo" [D3]; no id |
| `receipt_no_commission_line` | Receipt confirm / JM-033 | AC says "NO commission/finance line shown"; coined for negative assertion |
| `rating_root` | Rating / JM-034 | AC says "reconcile /feedback vs /mutual-rate"; root id confirms route reachable |
| `customer_profile_avatar` | Customer profile / JM-035 | AC says "avatar" renders; no id named |
| `customer_profile_name` | Customer profile / JM-035 | AC says "name" renders; no id named |
| `customer_profile_rating` | Customer profile / JM-035 | AC says "per-role rating" [D6]; no id named |
| `saved_address_default_badge` | Saved addresses / JM-049 | AC names this; included for completeness |
| `saved_address_0_edit` | Saved addresses / JM-049 | AC says `saved_address_<id>_edit`; coins index-0 |
| `address_form_map_pin` | Address form / JM-050 | AC says "map pin/preview"; no id |
| `address_form_label` | Address form / JM-050 | AC says "label" field; no id |
| `address_form_building` | Address form / JM-050 | AC says "Building"; no id |
| `address_form_floor_apt` | Address form / JM-050 | AC says "Floor/apt"; no id |
| `address_form_delivery_notes` | Address form / JM-050 | AC says "Delivery notes"; no id |
| `address_form_cod_phone` | Address form / JM-050 | AC says "COD Phone"; no id |

---

## 6. Mock Blockers / Seam Blockers (flows remain RED until these land)

| Ref | Type | Affects | Description |
|-----|------|---------|-------------|
| **T1** | Mock (backender) | jm-024 AC5 | `GET /delivery-service/v1/tiers` must return 5 tiers |
| **D1m** | Mock (backender) | jm-033 AC1 | Proof-photo upload sink endpoint |
| `jeeb.seam.journey=pending_request` | Seam (app + mock) | jm-023, jm-026, jm-030 | 1 pending request seeded for user-client-001 |
| `jeeb.seam.journey=pending_request_no_coverage` | Seam (app + mock) | jm-026 AC1b | 1 pending request, 0 jeebers found |
| `jeeb.seam.journey=offers_received` | Seam (app + mock) | jm-026, jm-027, jm-028, jm-029 | 1 offers-received request with >=2 offers |
| `jeeb.seam.journey=order_accepted` | Seam (app + mock) | jm-025, jm-031, jm-029 | Request accepted + conversation + delivery seeded |
| `jeeb.seam.journey=active_delivery` | Seam (app + mock) | jm-025, jm-032 | Active/in-transit delivery seeded |
| `jeeb.seam.journey=delivery_marked_done` | Seam (app + mock) | jm-032, jm-033, jm-034 | Delivery in delivered state; receipt prompt shows |
| `jeeb.seam.journey=jeeber_rating_pending` | Seam (app + mock) | jm-034 AC3 | Delivered delivery for user-jeeber-002 awaiting rating |
| `jeeb.seam.journey=has_saved_addresses` | Seam (app + mock) | jm-049 | >=1 saved address with default for user-client-001 |

---

## 7. W1 EXIT Checklist (entry gate to W2 full merge)

- [ ] All 15 W1 JM items have `signoffs/JM-###.md` = SIGNED (JM-049/050 may be PARTIAL-defer)
- [ ] `--include-tags w1` suite GREEN on `jeeb_test`
- [ ] `--include-tags w0` still GREEN (regression)
- [ ] `flutter analyze` clean + `flutter test` green on wave/w1 branch
- [ ] All W1 routes/edges nav-honest (every `goNamed` target registered)
- [ ] T1 closed or AC5 of jm-024 PARTIAL-parked
- [ ] D1m closed or receipt proof AC PARTIAL-parked
- [ ] All `jeeb.seam.journey` seeds implemented or dependent ACs PARTIAL-parked
- [ ] No leading-underscore ids, no fixed sleeps, id-only assertions throughout
- [ ] `order_summary_pinned` widget confirmed visible in both chat + tracking contexts (JM-031 AC4)
- [ ] `rating_skip_cta` NOT visible on mandatory rating path (JM-034 AC1, D56)
- [ ] `receipt_no_commission_line` NOT visible on receipt screen (JM-033 AC4, D11)

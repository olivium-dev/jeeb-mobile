# 67 — W3 + W4 Test Plan

> **Author:** Senior Principal QA Engineer (Sonnet). **Date:** 2026-06-19.
> **Status:** RED (all flows test-first; GREEN when each JM ships + its seed exists).
>
> This document is the authoritative test-plan for Wave 3 (JM-052, 055, 056) and Wave 4
> (JM-057..068). It records: the flow file per item, every Semantics identifier it asserts on,
> the nav assertion (what id must appear after a tap), and the REQUIRED seam/mock seed that must
> exist before the flow can turn GREEN. Companion: `30_BACKLOG.md` (ACs), `62_SEAM_HARNESS.md`
> (seam contract), `21_NAV_PLAN.md` (routes), `42_GUARDRAILS_MOCK.md §4` (mock-fix register).
>
> **Identifier grammar:** `<screen-id>_<element>` (`30_BACKLOG §"Identifier convention"`).
> Coined identifiers (implied-but-unnamed in the ACs) are flagged **[COINED]**.
> AP-9 guards (unbuilt target screens at time of authoring) are noted per row.

---

## Master table

| JM | Flow file | Wave | Role | Route / entry |
|---|---|---|---|---|
| JM-052 | `jm-052-earnings-dashboard.yaml` | W3 | jeeber | Earnings tab (`shell_tab_earnings`) |
| JM-055 | `jm-055-wallet-activity.yaml` | W3 | jeeber | `/wallet/activity` |
| JM-056 | `jm-056-transaction-detail.yaml` | W3 | jeeber | `/wallet/transactions/:id` |
| JM-057 | `jm-057-notifications-list.yaml` | W4 | shared | `/notifications` |
| JM-058 | `jm-058-notification-prefs.yaml` | W4 | shared | `/settings/notifications` |
| JM-059 | `jm-059-language-settings.yaml` | W4 | shared | `/settings/language` |
| JM-060 | `jm-060-dispute-open-evidence.yaml` | W4 | shared | `/orders/:id/escalate` |
| JM-061 | `jm-061-password-security.yaml` | W4 | shared | `/settings/password` |
| JM-062 | `jm-062-logout-delete.yaml` | W4 | shared | sheet from profile logout row / account-status |
| JM-063 | `jm-063-support-ticket.yaml` | W4 | shared | `/support` |
| JM-064 | `jm-064-rate-the-app.yaml` | W4 | shared | native (from profile row) |
| JM-065 | `jm-065-dispute-status.yaml` | W4 | shared | `/disputes/:id` |
| JM-066 | `jm-066-account-status.yaml` | W4 | shared | `/account-status` (router gate) |
| JM-067 | `jm-067-jeeber-profile-reviews.yaml` | W4 | shared | `/profile/delivery-man` |
| JM-068 | `jm-068-reviews-list.yaml` | W4 | shared | `/profile/delivery-man/reviews` |

---

## JM-052 — Earnings & Fees Dashboard

**Flow:** `.maestro/flows/jm-052-earnings-dashboard.yaml`
**Seam:** `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved` + `jeeb.seam.wallet_state=sufficient`; navigate via `shell_tab_earnings`.

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `shell_tab_dashboard` | JM-036 ACs | `extendedWaitUntil` | landing after seam |
| `shell_tab_earnings` | W2 seam §3 | `tapOn` | bottom-nav tab |
| `earnings_total_cash` | JM-052 AC | `extendedWaitUntil` | "net, off-wallet COD" label |
| `earnings_fees_paid` | JM-052 AC | `assertVisible` | "captured 10%" label |
| `earnings_net_per_offer` | JM-052 AC | `assertVisible` | **[COINED]** net-per-offer line (D44) |
| `earnings_member_since` | JM-052 AC | `assertVisible` | **[COINED]** member-since chip |
| `earnings_gross_payout` | JM-052 AC | `assertNotVisible` | **[COINED]** MUST NOT exist (D41/D44) |
| `earnings_commission_line` | JM-052 AC | `assertNotVisible` | **[COINED]** MUST NOT exist (D44) |
| `earnings_net_payout` | JM-052 AC | `assertNotVisible` | **[COINED]** MUST NOT exist (D44) |
| `earnings_wallet_link` | JM-052 AC | `tapOn` | → wallet-hub |
| `wallet_available_balance` | JM-053 ACs | `extendedWaitUntil` | confirms wallet-hub landed |
| `earnings_activity_link` | JM-052 AC | `tapOn` | AP-9: W3 target unbuilt |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `shell_tab_earnings` | `earnings_total_cash` | confirms tab navigated |
| `earnings_wallet_link` | `wallet_available_balance` | wallet-hub (JM-053) |
| `earnings_activity_link` | `earnings_total_cash` | AP-9: hub survives; swap to `wallet_activity_root` when JM-055 ships |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.session=jeeber_logged_in` | existing | session | Seam harness |
| `jeeb.seam.kyc_status=approved` | existing | KYC gate | W2 seam |
| `jeeb.seam.wallet_state=sufficient` | existing | wallet mock | W2 seam |
| `GET /wallet-service/v1/jeeb/earnings` | existing mock | earnings data | Backend |
| `GET /wallet-service/v1/jeeb/earnings/export` | existing mock | export | Backend |

---

## JM-055 — Wallet Activity List

**Flow:** `.maestro/flows/jm-055-wallet-activity.yaml`
**Seam:** `jeeber_logged_in` + `kyc_status=approved` + `wallet_state=sufficient` + `journey=jeeber_wallet_ledger` + `jeeb.route=/wallet/activity`

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `wallet_activity_root` | JM-055 AC | `extendedWaitUntil` | screen root |
| `wallet_activity_row_ledger-row-reserve-001` | JM-055 AC | `assertVisible` / `tapOn` | per-id pattern; seeded Reserve row |
| `wallet_activity_row_ledger-row-fee-001` | JM-055 AC | `assertVisible` | seeded Fee-won row |
| `wallet_activity_skeleton` | JM-055 AC [COINED] | screenshot | **[COINED]** loading skeleton (D73) |
| `wallet_activity_empty` | JM-055 AC [COINED] | `assertVisible` | empty state |
| `txn_detail` | JM-056 ACs | `extendedWaitUntil` | confirms txn-detail landed |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `wallet_activity_row_ledger-row-reserve-001` | `txn_detail` | transaction-detail (JM-056) |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.journey=jeeber_wallet_ledger` | **NEW W3** | AC1/2/3 | Backend + seam |
| `POST /__mock/seed/journey { "journey": "jeeber_wallet_ledger" }` | mock seed | ledger rows | Backend |
| `GET /wallet-service/v1/jeeb/wallet/ledger` (W2m) | **mock-fix W2m** | all ledger ACs | Backend |
| Stable ids: `ledger-row-reserve-001`, `ledger-row-fee-001`, `ledger-row-released-001` | mock data | row taps | Backend |

---

## JM-056 — Transaction Detail

**Flow:** `.maestro/flows/jm-056-transaction-detail.yaml`
**Seam:** `jeeber_logged_in` + `kyc_status=approved` + `wallet_state=sufficient` + `journey=jeeber_wallet_fee_txn` + `jeeb.route=/wallet/transactions/txn-fee-001` (AC1/2/4); `journey=jeeber_wallet_refund_txn` + `/wallet/transactions/txn-refund-001` (AC3/5)

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `txn_detail` | JM-056 AC | `extendedWaitUntil` | screen root |
| `txn_detail_type_label` | JM-056 AC [COINED] | `assertVisible` | **[COINED]** per-type label chip |
| `txn_detail_amount` | JM-056 AC [COINED] | `assertVisible` | **[COINED]** amount + sign |
| `txn_detail_order_ref` | JM-056 AC [COINED] | `assertVisible` | **[COINED]** order reference |
| `txn_detail_fee_percentage_label` | JM-056 AC [COINED] | `assertVisible` | **[COINED]** "10%" (D37, fee-won) |
| `txn_detail_pinned_price` | JM-056 AC [COINED] | `assertVisible` | **[COINED]** accepted price (D37) |
| `txn_detail_order_link` | JM-056 AC | `tapOn` | AP-9: order-summary optional route |
| `txn_detail_dispute_link` | JM-056 AC | `assertVisible` / `tapOn` | Refund/Penalty type (D2); AP-9 |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `txn_detail_order_link` | `txn_detail` | AP-9: order-summary-pinned route (CTO-D3) unconfirmed; root survives |
| `txn_detail_dispute_link` | `txn_detail` | AP-9: JM-060 W4 not yet shipped; root survives |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.journey=jeeber_wallet_fee_txn` | **NEW W3** | AC1/2/4 | Backend + seam |
| `jeeb.seam.journey=jeeber_wallet_refund_txn` | **NEW W3** | AC3/5 | Backend + seam |
| `GET /wallet-service/v1/jeeb/wallet/transactions/:id` (W3m) | **mock-fix W3m** | all ACs | Backend |
| Stable ids: `txn-fee-001`, `txn-refund-001` | mock data | route pins | Backend |

---

## JM-057 — Notifications List

**Flow:** `.maestro/flows/jm-057-notifications-list.yaml`
**Seam:** `customer_logged_in` + `journey=has_notifications` + `jeeb.route=/notifications` (most ACs); `jeeber_logged_in` + `kyc_status=rejected` + `journey=has_notifications_jeeber` (kyc_rejected AC)

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `notif_list_root` | JM-057 AC [COINED] | `extendedWaitUntil` | **[COINED]** screen root |
| `notif_row_notif-offers-001` | JM-057 AC | `assertVisible` / `tapOn` | offers-type row |
| `notif_row_notif-wallet-001` | JM-057 AC | `assertVisible` / `tapOn` | wallet-type row |
| `notif_row_notif-status-001` | JM-057 AC | `assertVisible` | order-status-type row |
| `notif_row_notif-kyc-approved-001` | JM-057 AC | `assertVisible` / `tapOn` | kyc_approved jeeber row |
| `notif_row_notif-kyc-rejected-001` | JM-057 AC | `assertVisible` / `tapOn` | kyc_rejected jeeber row |
| `notif_list_empty` | JM-057 AC [COINED] | `assertVisible` | **[COINED]** empty state |
| `orders_home_bell` | JM-023 ACs | `tapOn` | bell entry from shell |
| `kyc_rejected_root` | JM-043 ACs | `extendedWaitUntil` | kyc_rejected deep-link target |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `notif_row_notif-offers-001` | `shell_tab_requests` | D84: offers → my-orders |
| `notif_row_notif-wallet-001` | `wallet_available_balance` | D84: wallet → wallet-hub |
| `notif_row_notif-kyc-approved-001` | `shell_tab_dashboard` | D84: kyc_approved → jeeber feed |
| `notif_row_notif-kyc-rejected-001` | `kyc_rejected_root` | D84: kyc_rejected → kyc-rejected |
| `orders_home_bell` | `notif_list_root` | AC5: bell entry |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.journey=has_notifications` | **NEW W4** | AC1/2a/2b/3/4/5 | Backend + seam |
| `jeeb.seam.journey=has_notifications_jeeber` | **NEW W4** | AC2c/2d | Backend + seam |
| `GET /notification-service/v1/notifications?userId=` | existing mock | data | Backend |
| `PATCH /notification-service/v1/notifications/:id/read` | existing mock | mark-read | Backend |
| Stable ids: `notif-offers-001`, `notif-wallet-001`, `notif-status-001`, `notif-kyc-approved-001`, `notif-kyc-rejected-001` | mock data | row taps | Backend |

---

## JM-058 — Notification Preferences

**Flow:** `.maestro/flows/jm-058-notification-prefs.yaml`
**Seam:** `customer_logged_in` + `jeeb.route=/settings/notifications`

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `notif_prefs_root` | JM-058 AC [COINED] | `extendedWaitUntil` | **[COINED]** screen root |
| `notif_prefs_offers_toggle` | JM-058 AC | `assertVisible` | offers category (D64) |
| `notif_prefs_order_status_toggle` | JM-058 AC | `assertVisible` | order-status category |
| `notif_prefs_wallet_toggle` | JM-058 AC | `assertVisible` | wallet category |
| `notif_prefs_marketing_toggle` | JM-058 AC | `assertVisible` / `tapOn` | marketing (debounceable) |
| `notif_prefs_transactional_lock_icon` | JM-058 AC [COINED] | `assertVisible` | **[COINED]** locked indicator (D64) |
| `notif_prefs_push_only_note` | JM-058 AC [COINED] | `assertVisible` | **[COINED]** push-only static note (R2) |
| `notif_prefs_back` | JM-058 AC | `tapOn` | → customer-profile |
| `customer_profile_wallet_chip` | JM-035 ACs | `extendedWaitUntil` | confirms profile landed |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `notif_prefs_back` | `customer_profile_wallet_chip` | back to profile (JM-035) |
| `notif_prefs_marketing_toggle` | `notif_prefs_root` | no nav; root survives |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `GET /notification-service/v1/notifications/preferences` | existing mock | prefs data | Backend |
| `PUT /notification-service/v1/notifications/preferences` | existing mock | PATCH | Backend |

---

## JM-059 — Language Settings

**Flow:** `.maestro/flows/jm-059-language-settings.yaml`
**Seam:** `customer_logged_in` + `jeeb.route=/settings/language`

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `language_settings_root` | JM-059 AC [COINED] | `extendedWaitUntil` | **[COINED]** screen root |
| `language_english_option` | JM-059 AC [COINED] | `assertVisible` | **[COINED]** English option tile |
| `language_arabic_option` | JM-059 AC | `assertVisible` / `tapOn` | Arabic option (R3) |
| `language_back` | JM-059 AC | `tapOn` | → customer-profile |
| `customer_profile_wallet_chip` | JM-035 ACs | `extendedWaitUntil` | back target |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `language_arabic_option` | `language_settings_root` | RTL flip; root survives |
| `language_back` | `customer_profile_wallet_chip` | back to profile |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| (none — purely local preference, no mock) | — | — | — |

---

## JM-060 — Dispute Open Evidence

**Flow:** `.maestro/flows/jm-060-dispute-open-evidence.yaml`
**Seam:** `customer_logged_in` + `journey=order_accepted` + `jeeb.route=/orders/del-client-001-active/escalate`

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `dispute_root` | JM-060 AC [COINED] | `extendedWaitUntil` | **[COINED]** screen root |
| `dispute_reason` | JM-060 AC | `assertVisible` / `tapOn` + `inputText` | reason field |
| `dispute_photos` | JM-060 AC | `assertVisible` | image picker (≤5, D53) |
| `dispute_voice` | JM-060 AC | `assertVisible` | voice evidence (D53) |
| `dispute_auto_attach_note` | JM-060 AC [COINED] | `assertVisible` | **[COINED]** auto-attach note (D53) |
| `dispute_submit_cta` | JM-060 AC | `assertVisible` / `tapOn` | → dispute-status |
| `dispute_support_link` | JM-060 AC | `tapOn` | → support-ticket (D76) |
| `dispute_back` | JM-060 AC | `tapOn` | → order-chat |
| `dispute_status_state` | JM-065 ACs | `extendedWaitUntil` | post-submit target |
| `support_root` | JM-063 AC [COINED] | `extendedWaitUntil` | support link target |
| `order_chat_composer_send` | JM-025 ACs | `extendedWaitUntil` | back target |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `dispute_submit_cta` | `dispute_status_state` | POST /compliment-service/v1/disputes → JM-065 |
| `dispute_support_link` | `support_root` | D76 → JM-063 |
| `dispute_back` | `order_chat_composer_send` | back to order-chat |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.journey=order_accepted` | existing W1 | active order + conversation | W1 seam |
| `POST /compliment-service/v1/disputes` | existing mock | submit | Backend |
| `GET /chat-service/.../snapshot` | existing mock | auto-attach timeline | Backend |
| JM-065 shipped | screen dep | submit target | Eng |
| JM-063 shipped | screen dep | support link | Eng |

---

## JM-061 — Password & Security

**Flow:** `.maestro/flows/jm-061-password-security.yaml`
**Seam:** `customer_logged_in` + `jeeb.route=/settings/password` (standard); `customer_logged_in` + `jeeb.seam.account_type=social_only` + `/settings/password` (AC4)

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `password_security_root` | JM-061 AC [COINED] | `extendedWaitUntil` | **[COINED]** screen root |
| `password_current_field` | JM-061 AC [COINED] | `assertVisible` | **[COINED]** current password |
| `password_new_field` | JM-061 AC [COINED] | `assertVisible` / `tapOn` + `inputText` | **[COINED]** new password |
| `password_confirm_field` | JM-061 AC [COINED] | `assertVisible` / `tapOn` + `inputText` | **[COINED]** confirm |
| `password_new_visibility_toggle` | JM-061 AC [COINED] | `tapOn` | **[COINED]** eye icon new |
| `password_confirm_visibility_toggle` | JM-061 AC [COINED] | `tapOn` | **[COINED]** eye icon confirm |
| `password_submit_cta` | JM-061 AC [COINED] | `tapOn` | **[COINED]** save button |
| `password_mismatch_error` | JM-061 AC [COINED] | `extendedWaitUntil` | **[COINED]** inline mismatch error |
| `password_strength_error` | JM-061 AC [COINED] | `assertVisible` | **[COINED]** strength error |
| `password_set_entry` | JM-061 AC [COINED] | `assertVisible` / `tapOn` | **[COINED]** social-only entry (D90) |
| `password_back` | JM-061 AC | `tapOn` | → customer-profile |
| `setpw_new_field` | JM-022 ACs | `extendedWaitUntil` | in-app-social set-password target |
| `customer_profile_wallet_chip` | JM-035 ACs | `extendedWaitUntil` | back target |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `password_set_entry` | `setpw_new_field` | D90 → auth-set-password?mode=in-app-social |
| `password_back` | `customer_profile_wallet_chip` | back to profile |
| `password_submit_cta` (mismatched) | `password_mismatch_error` | validation stays on screen |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.account_type=social_only` | **NEW W4** | AC4 (social-only variant) | Backend + seam |
| `POST /__mock/seed/account { "type": "social_only" }` | mock seed | no-password state | Backend |

---

## JM-062 — Logout / Delete Account

**Flow:** `.maestro/flows/jm-062-logout-delete.yaml`
**Seam:** `customer_logged_in` (navigate profile→logout row) for AC1/2/3; `suspended` for AC4

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `shell_tab_requests` | seam harness | `extendedWaitUntil` | customer landing |
| `shell_tab_profile` | seam harness | `tapOn` | navigate to profile |
| `customer_profile_wallet_chip` | JM-035 ACs | `extendedWaitUntil` | profile confirm |
| `customer_profile_logout_row` | JM-035 ACs | `tapOn` | entry CTA |
| `logout_delete_sheet` | JM-062 AC [COINED] | `extendedWaitUntil` | **[COINED]** sheet root |
| `logout_confirm_cta` | JM-062 AC | `assertVisible` / `tapOn` | logout button |
| `delete_confirm_cta` | JM-062 AC | `assertVisible` / `tapOn` | delete button |
| `login_root` | seam harness §5 | `extendedWaitUntil` | post-logout landing (D5) |
| `account_status_root` | JM-066 ACs | `extendedWaitUntil` | suspended entry |
| `account_status_signout_cta` | JM-066 ACs | `tapOn` | entry from account-status |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `logout_confirm_cta` | `login_root` | session cleared → splash → /login (D5) |
| `delete_confirm_cta` | `login_root` | session cleared → splash → /login (D5) |
| `account_status_signout_cta` | `logout_delete_sheet` | AC4: entry from account-status |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `POST /auth-service/auth/logout` | existing mock | logout | Backend |
| `POST /push-notification/v1/devices/unregister` | existing mock | deregister | Backend |
| JM-066 shipped | screen dep | AC4 entry | Eng |

---

## JM-063 — Support Ticket

**Flow:** `.maestro/flows/jm-063-support-ticket.yaml`
**Seam:** `customer_logged_in` + `jeeb.route=/support` (AC1/2/3); `suspended` (AC4); `jeeber_logged_in` + `kyc_status=rejected` + `jeeb.route=/kyc/rejected` (AC6)

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `support_root` | JM-063 AC [COINED] | `extendedWaitUntil` | **[COINED]** screen root |
| `support_category` | JM-063 AC | `assertVisible` / `tapOn` | category picker |
| `support_body` | JM-063 AC | `assertVisible` / `tapOn` + `inputText` | body text field |
| `support_attach` | JM-063 AC | `assertVisible` | attach CTA |
| `support_order_link` | JM-063 AC | `assertVisible` | order reference link |
| `support_submit_cta` | JM-063 AC | `assertVisible` / `tapOn` | submit |
| `support_confirmation` | JM-063 AC [COINED] | `extendedWaitUntil` | **[COINED]** confirmation state |
| `support_confirmation_back_cta` | JM-063 AC [COINED] | `tapOn` | **[COINED]** back from confirmation |
| `support_dispute_link` | JM-063 AC | `tapOn` | AP-9: JM-060 W4 guard |
| `account_status_root` | JM-066 ACs | `extendedWaitUntil` | AC4 entry |
| `account_status_support_cta` | JM-066 ACs | `tapOn` | AC4 tap |
| `kyc_rejected_root` | JM-043 ACs | `extendedWaitUntil` | AC6 entry |
| `kyc_rejected_appeal_cta` | JM-043 ACs | `tapOn` | AC6 tap |
| `customer_profile_wallet_chip` | JM-035 ACs | `extendedWaitUntil` | back-to-profile after confirmation |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `support_submit_cta` | `support_confirmation` | → confirmation state |
| `support_confirmation_back_cta` | `customer_profile_wallet_chip` | → customer-profile |
| `support_dispute_link` | `support_root` | AP-9: root survives (JM-060 not yet shipped) |
| `account_status_support_cta` | `support_root` | AC4: entry from account-status |
| `kyc_rejected_appeal_cta` | `support_root` | AC6: entry from kyc-rejected |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `POST /support-service/v1/tickets` (S1) | **mock-fix S1** | all submit ACs | Backend |
| JM-066 shipped | screen dep | AC4 | Eng |
| JM-043 shipped | screen dep | AC6 | Eng |

---

## JM-064 — Rate the App

**Flow:** `.maestro/flows/jm-064-rate-the-app.yaml`
**Seam:** `customer_logged_in`; navigate via profile tab

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `shell_tab_requests` | seam harness | `extendedWaitUntil` | landing |
| `shell_tab_profile` | seam harness | `tapOn` | navigate |
| `customer_profile_wallet_chip` | JM-035 ACs | `extendedWaitUntil` | profile confirm |
| `customer_profile_rate_app_row` | JM-035 ACs | `assertVisible` / `tapOn` | rate-app row |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `customer_profile_rate_app_row` | `customer_profile_wallet_chip` | OS native sheet (may not appear on emulator); root survives |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| (none — in_app_review; no network) | — | — | — |

---

## JM-065 — Dispute Status

**Flow:** `.maestro/flows/jm-065-dispute-status.yaml`
**Seam:** `customer_logged_in` + `journey=has_open_dispute` + `jeeb.route=/disputes/dispute-client-001`

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `dispute_status_state` | JM-065 AC | `extendedWaitUntil` | Open/Resolved state chip |
| `dispute_status_outcome_note` | JM-065 AC [COINED] | `assertVisible` | **[COINED]** refund/penalty outcome (D2) |
| `dispute_status_evidence_summary` | JM-065 AC [COINED] | `assertVisible` | **[COINED]** evidence list (D53) |
| `dispute_status_support` | JM-065 AC | `tapOn` | → support-ticket |
| `dispute_status_back` | JM-065 AC | `tapOn` | → order-chat |
| `support_root` | JM-063 AC [COINED] | `extendedWaitUntil` | support link target |
| `order_chat_composer_send` | JM-025 ACs | `extendedWaitUntil` | back target |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `dispute_status_support` | `support_root` | D76 → JM-063 |
| `dispute_status_back` | `order_chat_composer_send` | → order-chat (JM-025) |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.journey=has_open_dispute` | **NEW W4** | all ACs | Backend + seam |
| `POST /__mock/seed/journey { "journey": "has_open_dispute" }` | mock seed | dispute rows | Backend |
| `GET /compliment-service/v1/disputes/:disputeId` | existing mock | dispute data | Backend |
| Stable id: `dispute-client-001` | mock data | route pin | Backend |
| JM-060 shipped | screen dep | prior step | Eng |
| JM-063 shipped | screen dep | support link | Eng |

---

## JM-066 — Account Status

**Flow:** `.maestro/flows/jm-066-account-status.yaml`
**Seam:** `jeeb.seam.session=suspended` (seeds `seam.account_blocked=true` → `/account-status`)

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `account_status_root` | seam harness §5 / JM-066 AC | `extendedWaitUntil` | screen root |
| `account_status_support_cta` | JM-066 AC | `assertVisible` / `tapOn` | → support-ticket |
| `account_status_signout_cta` | JM-066 AC | `assertVisible` / `tapOn` | → logout sheet |
| `shell_tab_requests` | seam harness §5 | `assertNotVisible` | tab access BLOCKED (D5) |
| `shell_tab_profile` | seam harness §5 | `assertNotVisible` | tab access BLOCKED (D5) |
| `support_root` | JM-063 AC [COINED] | `extendedWaitUntil` | support link target |
| `logout_delete_sheet` | JM-062 AC [COINED] | `extendedWaitUntil` | signout target |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `account_status_support_cta` | `support_root` | D76 → JM-063 |
| `account_status_signout_cta` | `logout_delete_sheet` | → JM-062 sheet |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.session=suspended` | existing W0 | router gate | Seam harness |
| JM-066 screen body (W4) | screen dep | full ACs | Eng |
| JM-063 shipped | screen dep | AC2 | Eng |
| JM-062 shipped | screen dep | AC3 | Eng |

---

## JM-067 — Jeeber Profile Reviews

**Flow:** `.maestro/flows/jm-067-jeeber-profile-reviews.yaml`
**Seam:** `customer_logged_in` + `journey=offers_received` (AC1/2/4); `customer_logged_in` + `journey=jeeber_cold_start_profile` + route pin (AC3)

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `replies_check_offers_cta` | JM-027 ACs | `tapOn` | entry to offer-review-list |
| `offer_review_root` | JM-028 AC [COINED] | `extendedWaitUntil` | **[COINED]** offer-review-list root |
| `offer_card_offer-001_name` | JM-028 ACs | `tapOn` | tap jeeber name |
| `profile_first_name_attribution` | JM-067 AC [COINED] | `extendedWaitUntil` | **[COINED]** first-name-only (D58) |
| `profile_review_helpful_cta` | JM-067 AC [COINED] | `assertNotVisible` | **[COINED]** MUST NOT exist (D57) |
| `profile_review_reply_cta` | JM-067 AC [COINED] | `assertNotVisible` | **[COINED]** MUST NOT exist (D57) |
| `profile_view_all_reviews` | JM-067 AC | `assertVisible` / `tapOn` | → reviews-list |
| `profile_rating_score` | JM-067 AC [COINED] | `assertNotVisible` | **[COINED]** hidden when <5 (D59, AC3) |
| `profile_close` | JM-067 AC | `tapOn` | → offer-review-list |
| `reviews_root` | JM-068 AC [COINED] | `extendedWaitUntil` | **[COINED]** reviews-list root |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `offer_card_offer-001_name` | `profile_first_name_attribution` | → jeeber profile |
| `profile_view_all_reviews` | `reviews_root` | → JM-068 |
| `profile_close` | `offer_review_root` | → offer-review-list (JM-028) |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.journey=offers_received` | existing W1 | AC1/2/4 | W1 seam |
| `jeeb.seam.journey=jeeber_cold_start_profile` | **NEW W4** | AC3 (cold-start <5) | Backend + seam |
| `POST /__mock/seed/journey { "journey": "jeeber_cold_start_profile" }` | mock seed | reviewCount=2 | Backend |
| `GET /user-management/users/:userId` | existing mock | profile data | Backend |
| JM-068 shipped | screen dep | view-all target | Eng |

---

## JM-068 — All Reviews List

**Flow:** `.maestro/flows/jm-068-reviews-list.yaml`
**Seam:** `customer_logged_in` + `journey=jeeber_has_reviews` + `jeeb.route=/profile/delivery-man/user-jeeber-002/reviews`; `journey=jeeber_cold_start_profile` for AC2b

### Identifiers asserted

| Identifier | Source | Assert type | Notes |
|---|---|---|---|
| `reviews_root` | JM-068 AC [COINED] | `extendedWaitUntil` | **[COINED]** screen root |
| `review_review-001_reviewer_name` | JM-068 AC [COINED] | `assertVisible` | **[COINED]** first-name-only (D58) |
| `review_review-002_reviewer_name` | JM-068 AC [COINED] | `assertVisible` | **[COINED]** first-name-only |
| `reviews_new_badge` | JM-068 AC [COINED] | `assertVisible` | **[COINED]** New badge (D59) |
| `reviews_hidden_score_note` | JM-068 AC [COINED] | `assertVisible` | **[COINED]** cold-start <5 note (D59) |
| `review_review-001_report_cta` | JM-068 AC [COINED] | `assertVisible` | **[COINED]** report button (D27) |
| `review_review-002_report_cta` | JM-068 AC [COINED] | `assertVisible` | **[COINED]** report button |
| `reviews_back` | JM-068 AC | `tapOn` | → jeeber-profile-reviews |
| `profile_view_all_reviews` | JM-067 ACs | `extendedWaitUntil` | back target |

### Nav assertions

| Tap | Expected id | Notes |
|---|---|---|
| `reviews_back` | `profile_view_all_reviews` | → jeeber-profile-reviews (JM-067) |

### Required seam / mock seeds

| Seed | Type | Unblocks | Owner |
|---|---|---|---|
| `jeeb.seam.journey=jeeber_has_reviews` | **NEW W4** | AC1/2/3/4 | Backend + seam |
| `POST /__mock/seed/journey { "journey": "jeeber_has_reviews" }` | mock seed | review rows | Backend |
| `GET /score-taking-service/v1/ratings/jeeb/jeeber/:jeeberId/reviews` (R1m) | **mock-fix R1m** | all ACs | Backend |
| Stable ids: `review-001`, `review-002`, `review-003` | mock data | row assertions | Backend |
| JM-067 shipped | screen dep | back target | Eng |

---

## Consolidated new seam / mock seeds (W3 + W4)

This is the full test-data contract W3/W4 flows need the app-seam + backend to implement.
Items marked **existing** are already in `62_SEAM_HARNESS.md`; **NEW** must be added.

### New `jeeb.seam.*` keys

| Key | Values | Required for | Owner |
|---|---|---|---|
| `jeeb.seam.account_type` | `social_only` | JM-061 AC4 | App + seam |

### New `jeeb.seam.journey` values

| Journey wire value | Mock seeds | Required for | Stable ids |
|---|---|---|---|
| `jeeber_wallet_ledger` | ≥2 typed ledger rows for `user-jeeber-002` | JM-055 | `ledger-row-reserve-001`, `ledger-row-fee-001`, `ledger-row-released-001` |
| `jeeber_wallet_fee_txn` | 1 Fee-won txn for `user-jeeber-002` | JM-056 AC1/2/4 | `txn-fee-001` |
| `jeeber_wallet_refund_txn` | 1 Refund txn for `user-jeeber-002` | JM-056 AC3/5 | `txn-refund-001` |
| `has_notifications` | ≥3 typed notif rows for `user-client-001` | JM-057 | `notif-offers-001`, `notif-wallet-001`, `notif-status-001` |
| `has_notifications_jeeber` | ≥2 typed notif rows for `user-jeeber-002` | JM-057 AC2c/2d | `notif-kyc-approved-001`, `notif-kyc-rejected-001` |
| `has_open_dispute` | 1 Open dispute for `user-client-001` (w/ related order+convo) | JM-065 | `dispute-client-001` |
| `jeeber_cold_start_profile` | `user-jeeber-002` profile w/ `reviewCount=2` | JM-067 AC3, JM-068 AC2b | `user-jeeber-002` (modified) |
| `jeeber_has_reviews` | ≥3 review rows for `user-jeeber-002`, `reviewCount=6` | JM-068 | `review-001`, `review-002`, `review-003` |

### New mock-fix endpoints

| Ref | Endpoint | Required for |
|---|---|---|
| **W2m** | `GET /wallet-service/v1/jeeb/wallet/ledger` (paginated typed rows) | JM-055 |
| **W3m** | `GET /wallet-service/v1/jeeb/wallet/transactions/:id` | JM-056 |
| **S1** | `POST /support-service/v1/tickets` | JM-063 |
| **R1m** | `GET /score-taking-service/v1/ratings/jeeb/jeeber/:jeeberId/reviews` (paginated) | JM-068 |
| **account_type seed** | `POST /__mock/seed/account { "type": "social_only", "userId" }` | JM-061 AC4 |

### New mock `POST /__mock/seed/journey` values to implement

| Journey | Body |
|---|---|
| `jeeber_wallet_ledger` | `{ "journey": "jeeber_wallet_ledger" }` |
| `jeeber_wallet_fee_txn` | `{ "journey": "jeeber_wallet_fee_txn" }` |
| `jeeber_wallet_refund_txn` | `{ "journey": "jeeber_wallet_refund_txn" }` |
| `has_notifications` | `{ "journey": "has_notifications" }` |
| `has_notifications_jeeber` | `{ "journey": "has_notifications_jeeber" }` |
| `has_open_dispute` | `{ "journey": "has_open_dispute" }` |
| `jeeber_cold_start_profile` | `{ "journey": "jeeber_cold_start_profile" }` |
| `jeeber_has_reviews` | `{ "journey": "jeeber_has_reviews" }` |

---

## Coined identifiers grouped by screen

The following identifiers are **implied-but-unnamed** in the ACs. They are coined here using the
`<screen-id>_<element>` grammar (`30_BACKLOG §"Identifier convention"`). Engineers MUST use exactly
these strings when placing `Semantics(identifier:)` on their widgets.

### JM-052 earnings-fees-dashboard
- `earnings_net_per_offer` — net-per-offer line (D44)
- `earnings_member_since` — member-since chip
- `earnings_gross_payout` — forbidden line (assertNotVisible guard)
- `earnings_commission_line` — forbidden line (assertNotVisible guard)
- `earnings_net_payout` — forbidden line (assertNotVisible guard)

### JM-055 wallet-activity-list
- `wallet_activity_skeleton` — skeleton loading state (D73)
- `wallet_activity_empty` — empty state widget

### JM-056 transaction-detail
- `txn_detail_type_label` — per-type label chip
- `txn_detail_amount` — amount + sign display
- `txn_detail_order_ref` — order reference number
- `txn_detail_fee_percentage_label` — "10%" fee percentage (D37, fee-won type)
- `txn_detail_pinned_price` — accepted offer price (D37, fee-won type)

### JM-057 notifications-list
- `notif_list_root` — screen root
- `notif_list_empty` — empty state
- `notif_row_<id>_timestamp` — timestamp on each row
- `notif_row_<id>_read_indicator` — unread badge/dot

### JM-058 notification-prefs
- `notif_prefs_root` — screen root
- `notif_prefs_transactional_lock_icon` — locked indicator (D64)
- `notif_prefs_push_only_note` — push-only static note (R2)

### JM-059 language-settings
- `language_settings_root` — screen root
- `language_english_option` — English option tile
- `language_arabic_option` — Arabic option tile (named in AC for RTL)

### JM-060 dispute-open-evidence
- `dispute_root` — screen root
- `dispute_auto_attach_note` — auto-attached chat+GPS/timeline note (D53)

### JM-061 password-security
- `password_security_root` — screen root
- `password_current_field` — current password input
- `password_new_field` — new password input
- `password_confirm_field` — confirm password input
- `password_new_visibility_toggle` — eye icon for new field
- `password_confirm_visibility_toggle` — eye icon for confirm field
- `password_submit_cta` — save/submit button
- `password_mismatch_error` — inline mismatch error
- `password_strength_error` — inline strength error
- `password_set_entry` — "Set a password" entry (social-only variant, D90)

### JM-062 logout-delete-account
- `logout_delete_sheet` — sheet/dialog root

### JM-063 support-ticket
- `support_root` — screen root
- `support_confirmation` — post-submit confirmation state
- `support_confirmation_back_cta` — back CTA from confirmation

### JM-065 dispute-status
- `dispute_status_outcome_note` — refund/penalty outcome note (D2)
- `dispute_status_evidence_summary` — evidence list (D53)

### JM-067 jeeber-profile-reviews
- `profile_review_helpful_cta` — Helpful button (assertNotVisible, D57)
- `profile_review_reply_cta` — Reply button (assertNotVisible, D57)
- `profile_rating_score` — numeric score display
- `profile_review_count` — review count chip
- `profile_first_name_attribution` — first-name-only attribution (D58)
- `offer_review_root` — offer-review-list root (back target)

### JM-068 reviews-list
- `reviews_root` — screen root
- `reviews_new_badge` — New badge (D59)
- `reviews_hidden_score_note` — hidden-until-5 explanatory note (D59)
- `review_<id>_reviewer_name` — per-review first-name chip (D58)
- `review_<id>_report_cta` — per-review report button (D27)

---

## AP-9 guards summary

AP-9 (`41_GUARDRAILS_TESTING`): when a CTA targets an unbuilt screen, prove the tap is ACCEPTED
and the source root survives. Swap to the real target assertion once the target ships.

| Flow | CTA | AP-9 guard reason | Swap to when |
|---|---|---|---|
| JM-052 | `earnings_activity_link` | JM-055 W3 not yet shipped | `wallet_activity_root` when JM-055 GREEN |
| JM-056 | `txn_detail_order_link` | CTO-D3 optional route unconfirmed | `order_summary_pinned` when CTO-D3 confirmed + JM-031 ships |
| JM-056 | `txn_detail_dispute_link` | JM-060 W4 not yet shipped | `dispute_root` when JM-060 GREEN |
| JM-060 (AC3) | `dispute_support_link` | JM-063 W4 not yet shipped | `support_root` when JM-063 GREEN |
| JM-063 (AC3) | `support_dispute_link` | JM-060 W4 not yet shipped | `dispute_root` when JM-060 GREEN |

# 21 — Navigation Plan — Routes to Add + Edges to Wire

> **Phase 1 deliverable (Team Lead).** Reconciles all 62 blueprint screen ids to GoRouter
> paths/names, lists every route to ADD to `lib/core/router/app_router.dart`, and every
> blueprint edge to WIRE (`from → to via <control>`). Organized so the **single shared-file**
> (`app_router.dart`) is edited in **batches** per wave (CTO brief §7 isolation rule: only ONE
> agent edits a shared file per wave; route additions are batched centrally first).
>
> Ground truth: `11_FLUTTER_INVENTORY.md` (35 registered routes today), `app_router.dart`
> (read in full), `blueprint.json` (188 edges). Companion: `20_GAP_MAP.md`, `30_BACKLOG.md`.

---

## A. Screen-id ↔ route reconciliation (all 62)

Legend: **route status** — `exists` (route registered today) · `rename` (route exists, blueprint
id differs — cosmetic) · `tab` (a shell tab body, NOT a route — reached via bottom-nav index) ·
`sheet` (modal bottom sheet / dialog, no route) · `ADD` (new `GoRoute` required) · `native`
(OS sheet, thin handler, no route).

| blueprint id | role | GoRouter path | name | route status |
|---|---|---|---|---|
| `splash` | shared | (bootstrap host, not a GoRoute) | — | exists (logic only) |
| `walkthrough` | shared | `/onboarding` | `onboarding` | rename (id≠name, cosmetic) |
| `login` | auth | `/login` | `login` | **ADD** |
| `sign-up` | auth | `/register` (or new `/sign-up` if AUTH-OD-1 → email-first) | `register`/`sign-up` | exists / **ADD** (decision-gated) |
| `phone-otp-verification` | shared | `/register/otp` (re-parent) or keep inside `/register` | `phone-otp` | exists (in `/register` flow) |
| `social-login` | auth | (native sheet, no route) — `lib/features/auth/social/` | — | native |
| `social-collision-prompt` | auth | (sheet/dialog, no route) | — | sheet |
| `recover-password` | auth | `/recover` | `recover-password` | **ADD** |
| `verify-code` | auth | `/recover/verify` | `recover-verify` | **ADD** (nested under `/recover`) |
| `auth-set-password` | auth | `/set-password` | `set-password` | **ADD** (`?mode=recovery\|in-app-social`) |
| `biometric-unlock` | auth | `/lock` | `biometric-lock` | exists (replace placeholder) |
| `customer-orders-home` | customer | `/` (Requests tab, index 0 client) | `shell` | tab |
| `request-type-selection` | customer | `/request-type` | `request-type` | exists |
| `order-chat` | customer | `/chat/:id` | `chat-detail` | exists |
| `waiting-no-coverage` | customer | `/requests/:id/waiting` | `waiting-no-coverage` | **ADD** |
| `my-orders` | customer | `/` (Replies sub-tab of Requests) | `shell` | tab |
| `offer-review-list` | customer | `/requests/:id/offers` | `offer-review` | **ADD** (wire orphaned `ClientOffersScreen`) |
| `offer-accept-confirm` | customer | (sheet, no route) | — | sheet |
| `cancel-request-confirm` | customer | (sheet, no route) | — | sheet |
| `order-summary-pinned` | customer | (pinned header widget in chat+tracking; optional `/orders/:id/summary`) | `order-summary` | sheet/widget (+ optional **ADD**) |
| `order-tracking` | customer | `/orders/:id/tracking` | `live-tracking` | exists |
| `delivered-receipt-confirm` | customer | `/orders/:id/receipt` | `delivered-receipt` | **ADD** (rewrite orphaned `DeliveryReceiptScreen`) |
| `rate-jeeber` | customer | `/orders/:id/feedback` + `/orders/:id/mutual-rate` | `feedback`/`mutual-rating` | exists |
| `customer-profile` | customer | `/` (Profile tab) → render real `CustomerProfileScreen`; route `/profile/customer` exists | `customer-profile` | tab + exists route |
| `saved-addresses` | customer | `/settings/addresses` | `settings-addresses` | exists (re-parent edge) |
| `address-detail-form` | customer | `/settings/addresses/edit` | `address-detail` | **ADD** (promote sheet → screen) |
| `delivery-requests` | jeeber | `/` (DELIVERY tab, index 1 client / Dashboard jeeber) | `shell` | tab |
| `delivery-register-prompt` | jeeber | (inline gate in DELIVERY tab) or `/jeeber/register-prompt` | `delivery-register-prompt` | tab-inline (+ optional **ADD**) |
| `delivery-onboarding-image-upload` | jeeber | `/jeeber/onboarding` (`?step=photo`) | `jeeber-onboarding` | exists (wizard step) |
| `delivery-onboarding-personal-details` | jeeber | `/jeeber/onboarding?step=address` | `jeeber-onboarding` | exists (wizard step) |
| `delivery-onboarding-service-area` | jeeber | `/jeeber/onboarding?step=service-area` | `jeeber-onboarding` | exists (wizard step) |
| `kyc-identity` | jeeber | `/profile/kyc` (`?step=id\|selfie`) | `kyc-status` | exists (wizard step) |
| `onboarding-funding` | jeeber | `/jeeber/onboarding/funding` (or wizard step `funding`) | `onboarding-funding` | **ADD** |
| `kyc-pending-status` | jeeber | `/profile/kyc?step=status` | `kyc-status` | exists (wizard step) |
| `kyc-rejected` | jeeber | `/profile/kyc?step=rejected` (extract) or `/kyc/rejected` | `kyc-rejected` | exists (extract) / **ADD** |
| `offer-kyc-gate` | jeeber | `/jeeber/offer-gate` (interstitial) or sheet | `offer-kyc-gate` | **ADD** |
| `offer-composer` | jeeber | `/jeeber/requests/:id/offer` | `jeeber-offer-submission` | exists |
| `offer-insufficient-balance` | jeeber | (sheet on offer composer, no route) | — | sheet |
| `jeeber-pending-offers` | jeeber | `/` (Pending-Response sub-tab) or `/jeeber/pending-offers` | `jeeber-pending-offers` | tab-inline (+ optional **ADD**) |
| `jeeber-requests-home` | jeeber | `/` (Dashboard tab feed) | `shell` | tab |
| `delivery-order-chat` | jeeber | `/chat/:id` (role-aware) | `chat-detail` | exists |
| `jeeber-mark-delivered` | jeeber | `/jeeber/deliveries/:id/active` | `jeeber-active-delivery` | exists |
| `feedback-rate-delivery` | jeeber | `/orders/:id/feedback?mode=jeeber` + `/orders/:id/mutual-rate?mode=jeeber` | `feedback`/`mutual-rating` | exists |
| `earnings-fees-dashboard` | jeeber | `/` (Earnings tab) | `shell` | tab |
| `wallet-hub` | jeeber | `/wallet` | `wallet` | exists-stub → **REPLACE** |
| `wallet-charge-info` | jeeber | `/wallet/charge-info` | `wallet-charge-info` | **ADD** |
| `wallet-activity-list` | jeeber | `/wallet/activity` | `wallet-activity` | **ADD** |
| `transaction-detail` | jeeber | `/wallet/transactions/:id` | `transaction-detail` | **ADD** |
| `notifications-list` | shared | `/notifications` | `notifications` | **ADD** |
| `notification-prefs` | shared | `/settings/notifications` | `settings-notifications` | exists (extend) |
| `language-settings` | shared | `/settings/language` | `language-settings` | **ADD** (register existing screen) |
| `password-security` | shared | `/settings/password` | `password-security` | **ADD** |
| `logout-delete-account` | shared | (dialogs in `/settings`; surfaced from account-status) | — | sheet (+ entry from account-status) |
| `support-ticket` | shared | `/support` | `support-ticket` | **ADD** |
| `rate-the-app` | shared | (native store-review sheet, thin handler) | — | native |
| `dispute-open-evidence` | shared | `/orders/:id/escalate` | `escalate` | exists (extend/repoint) |
| `dispute-status` | shared | `/disputes/:id` | `dispute-status` | **ADD** |
| `account-status` | shared | `/account-status` | `account-status` | **ADD** + redirect gate |
| `reviews-list` | shared | `/profile/delivery-man/reviews` | `reviews-list` | **ADD** |
| `jeeber-profile-reviews` | shared | `/profile/delivery-man` | `delivery-man-profile` | exists (extend) |
| `location-select` | shared | `/client-location` | `client-location` | exists (extend) |
| `location-map-pin` | shared | `/capture-location` | `capture-location` | exists |

> **Tab disambiguation:** `customer-orders-home`, `my-orders`, `customer-profile`,
> `delivery-requests`, `jeeber-requests-home`, `earnings-fees-dashboard` are **shell tab bodies**,
> not routes (CTO brief §4: tabs are not routes; reached via `ShellScreen` + `RoleCubit` index).
> Maestro targets them by tab `Semantics(identifier:)` + tab index, never a path.

---

## B. Routes to ADD to `app_router.dart` (batched by wave)

> Each new `GoRoute` is added centrally **before** any call-site wiring (CTO brief §6.7
> navigation honesty + §7 shared-file batching). The owning JM item builds the screen; the route
> registration is part of that item's diff but lands in the per-wave batched router edit.

### Batch W0 (foundation — auth + biometric gate)
| path | name | screen | JM | notes |
|---|---|---|---|---|
| `/login` | `login` | `LoginScreen` | JM-007 | reuse `auth/social/` social row; D23 biometric affordance |
| `/recover` | `recover-password` | `RecoverPasswordScreen` | JM-020 | email field → verify-code |
| `/recover/verify` | `recover-verify` | `VerifyRecoveryCodeScreen` | JM-021 | nested; reuse `OmdsOtpInput` |
| `/set-password` | `set-password` | `SetPasswordScreen` | JM-022 | `?mode=recovery\|in-app-social` (D90 dual exit) |
| `/lock` (replace placeholder builder) | `biometric-lock` | real `BiometricLockScreen` | JM-005 | make `BiometricLockCubit` real |
| (`/sign-up` only if AUTH-OD-1 → email-first) | `sign-up` | `SignUpScreen` | JM-008 | decision-gated; else extend `/register` |

### Batch W1 (core customer journey)
| path | name | screen | JM | notes |
|---|---|---|---|---|
| `/requests/:id/offers` | `offer-review` | `ClientOffersScreen` (wire orphan) | JM-028 | offer-review-list |
| `/requests/:id/waiting` | `waiting-no-coverage` | `WaitingNoCoverageScreen` (rewrite orphan) | JM-026 | |
| `/orders/:id/receipt` | `delivered-receipt` | `DeliveredReceiptScreen` (rewrite orphan) | JM-033 | proof photo (D3) |
| (`/orders/:id/summary` optional) | `order-summary` | `OrderSummaryScreen` | JM-031 | prefer pinned widget; route optional |

> `offer-accept-confirm` (JM-029) and `cancel-request-confirm` (JM-030) are **sheets**, not routes
> — no router edit. `order-summary-pinned` (JM-031) is preferentially a **pinned header widget**
> injected into chat + tracking (no route); add the optional route only if a standalone surface
> is needed for a notification deep-link.

### Batch W2 (jeeber onboarding + offering gate)
| path | name | screen | JM | notes |
|---|---|---|---|---|
| `/jeeber/onboarding/funding` (or wizard step) | `onboarding-funding` | `OnboardingFundingScreen` | JM-041 | |
| `/jeeber/offer-gate` | `offer-kyc-gate` | `OfferKycGateScreen` | JM-044 | interstitial before offer-composer when unapproved |
| `/kyc/rejected` (extract from status view) | `kyc-rejected` | `KycRejectedScreen` | JM-043 | appeal-via-support only (D52/D87) |
| (`/jeeber/pending-offers` optional) | `jeeber-pending-offers` | `JeeberPendingOffersScreen` | JM-047 | prefer feed sub-tab; route optional |

> `offer-insufficient-balance` (JM-046) is a **sheet** on the offer composer — no router edit.
> Jeeber-onboarding wizard steps (`personal-details`, `service-area`, `image-upload`, `kyc-identity`,
> `kyc-pending`) are **existing wizard steps** inside `/jeeber/onboarding` + `/profile/kyc` — the
> D20/D51 fixes (JM-037/038/040) are widget/cubit edits, not new routes.

### Batch W3 (wallet + money)
| path | name | screen | JM | notes |
|---|---|---|---|---|
| `/wallet` (REPLACE stub builder) | `wallet` | `WalletHubScreen` | JM-053 | + header wallet chip in shell (D33) |
| `/wallet/charge-info` | `wallet-charge-info` | `WalletChargeInfoScreen` | JM-054 | static (D92/D93) |
| `/wallet/activity` | `wallet-activity` | `WalletActivityListScreen` | JM-055 | needs mock ledger (W2) |
| `/wallet/transactions/:id` | `transaction-detail` | `TransactionDetailScreen` | JM-056 | needs mock txn endpoint (W3) |

### Batch W4 (shared: notifications, support, dispute, account, reviews, settings)
| path | name | screen | JM | notes |
|---|---|---|---|---|
| `/notifications` | `notifications` | `NotificationsListScreen` | JM-057 | deep-link dispatch (D84) |
| `/support` | `support-ticket` | `SupportTicketScreen` | JM-063 | needs mock service (S1) |
| `/disputes/:id` | `dispute-status` | `DisputeStatusScreen` | JM-065 | |
| `/account-status` | `account-status` | `AccountStatusScreen` | JM-066 | **+ redirect gate in router** (blocks all tabs while suspended, D5) |
| `/profile/delivery-man/reviews` | `reviews-list` | `ReviewsListScreen` | JM-068 | needs mock source (R1m) |
| `/settings/language` | `language-settings` | `LanguageSettingsScreen` (register existing) | JM-059 | |
| `/settings/password` | `password-security` | `PasswordSecurityScreen` | JM-061 | |
| `/settings/addresses/edit` | `address-detail` | `AddressDetailFormScreen` | JM-050 | nested under `/settings/addresses` |

**Total new routes: 23 ADDs + 2 REPLACEs (`/wallet`, `/lock`) + 1 router redirect gate
(account-status) + (1 decision-gated `/sign-up`).**

---

## C. Edges to WIRE (`from → to via <control>`)

> Grouped by the JM item that owns the *source* screen. An edge is "wired" when the source
> screen's control navigates to a real registered route/tab (CTO brief §6.7). Edges where the
> target is itself unbuilt are blocked on the target's JM (noted). 188 blueprint edges total;
> below are the **missing/divergent** edges that need wiring (existing-and-correct edges omitted).

### Auth funnel (JM-005..009, 018..022)
- `splash → walkthrough` (first launch) · `splash → customer-orders-home` (logged-in customer, last tab D75) · `splash → delivery-requests` (logged-in jeeber) · `splash → login` (logged-out) · `splash → biometric-unlock` (biometric enabled) · `splash → account-status` (suspended) — **all in `_firstRunRedirect`** (JM-006).
- `walkthrough → sign-up` (Get started / Skip) — currently `→ /register` (JM-010; resolves with AUTH-OD-1).
- `login → recover-password` (forgot) · `login → sign-up` (Sign up link) · `login → social-login` (social row) · `login → customer-orders-home` (submit) (JM-007).
- `sign-up → phone-otp-verification` (submit) · `sign-up → social-collision-prompt` (collision) · `sign-up → login` (Login link) (JM-008).
- `phone-otp-verification → customer-orders-home` (verified) · `phone-otp-verification → login` (back); returning-user biometric/refresh bypass (D23) (JM-009).
- `social-login → phone-otp-verification` (G8 phone still required) · `social-login → social-collision-prompt` (D22) (JM-018).
- `social-collision-prompt → login` · `→ sign-up` (JM-019).
- `recover-password → verify-code` · `→ sign-up` · `→ login` (JM-020).
- `verify-code → auth-set-password` · `→ recover-password` (JM-021).
- `auth-set-password → login` (recovery) · `→ customer-profile` (in-app social, D90) (JM-022).
- `biometric-unlock → customer-orders-home` (success) · `→ login` (use password) (JM-005).

### Customer journey (JM-023..035)
- `customer-orders-home → wallet-hub` (header chip, blocked on JM-053) · `→ notifications-list` (bell, blocked on JM-057) · `→ waiting-no-coverage` (open pending request) (JM-023).
- `request-type-selection → location-select` (select tier) · `→ order-chat` (Start order) — replaces current `→ /request-summary` (JM-024).
- `order-chat → waiting-no-coverage` (send=broadcast) · `→ order-summary-pinned` (view summary) · `→ dispute-open-evidence` (open dispute) (JM-025).
- `waiting-no-coverage → my-orders` (offers arrive) · `→ offer-review-list` (review) · `→ order-chat` (widen) · `→ request-type-selection` (re-target D48) · `→ cancel-request-confirm` (JM-026).
- `my-orders → offer-accept-confirm` (Accept on card) · `→ offer-review-list` (Check Offers) — replaces `→ /chat/:id` (JM-027).
- `offer-review-list → offer-accept-confirm` (Accept) · `→ jeeber-profile-reviews` (tap name) · `→ my-orders` (back) · `→ cancel-request-confirm` (JM-028).
- `offer-accept-confirm → order-chat` (Confirm) · `→ offer-review-list` (cancel) (JM-029).
- `cancel-request-confirm → customer-orders-home` (confirm) (JM-030).
- `order-summary-pinned → order-chat` · `→ order-tracking` (JM-031).
- `order-tracking → delivered-receipt-confirm` (marked delivered) · `→ dispute-open-evidence` · `→ offer-review-list` (no-show reassign D88) · `→ waiting-no-coverage` (no-show re-broadcast) · `→ order-chat` (JM-032).
- `delivered-receipt-confirm → rate-jeeber` (confirm/auto-complete) · `→ dispute-open-evidence` (Not yet) (JM-033).
- `rate-jeeber → customer-orders-home` (submit) (JM-034).
- `customer-profile →` all profile rows: `delivery-onboarding-image-upload` (Register-as-delivery, NOT /register) · `password-security` · `notification-prefs` · `language-settings` · `support-ticket` · `rate-the-app` · `logout-delete-account` · `wallet-hub` (chip+row) · `notifications-list` (bell) · `saved-addresses` (JM-035; targets blocked on their JMs).

### Jeeber onboarding + offering (JM-036..048)
- `delivery-requests → delivery-register-prompt` (KYC not approved) · `→ jeeber-requests-home` (approved) · `→ wallet-hub` (chip) · `→ notifications-list` (bell) (JM-036).
- `delivery-register-prompt → delivery-onboarding-image-upload` (Register now) (JM-036).
- `delivery-onboarding-image-upload → kyc-identity` (alt) · `→ delivery-register-prompt` (back) (JM-039).
- `delivery-onboarding-service-area → location-map-pin` (select location) · `→ kyc-identity` (Continue) (JM-038).
- `kyc-identity → onboarding-funding` (submit) · `→ delivery-onboarding-service-area` (back) (JM-040).
- `onboarding-funding → wallet-charge-info` (how to add funds) · `→ kyc-pending-status` (Continue) (JM-041).
- `kyc-pending-status → jeeber-requests-home` (approved) · `→ wallet-hub` · `→ wallet-charge-info` · `→ kyc-rejected` (JM-042).
- `kyc-rejected → support-ticket` (appeal) · `→ customer-profile` (back) — replaces resubmit (JM-043).
- `offer-kyc-gate → kyc-identity` · `→ delivery-register-prompt` · `→ jeeber-requests-home` (back) (JM-044).
- `jeeber-requests-home → offer-composer` — **route through `offer-kyc-gate` when unapproved** (JM-044/048).
- `offer-composer → jeeber-requests-home` (send, 10% reserved) — replaces `→ /chat/:id` · `→ offer-insufficient-balance` (JM-045).
- `offer-insufficient-balance → wallet-charge-info` · `→ offer-composer` (cancel) (JM-046).
- `jeeber-pending-offers → delivery-requests` (back) (JM-047).

### Jeeber fulfil + money (JM-051..056)
- `jeeber-mark-delivered → feedback-rate-delivery` (delivered → rate) — replaces `→ /orders/:id/otp` (JM-051).
- `earnings-fees-dashboard → wallet-hub` · `→ wallet-activity-list` (JM-052).
- `wallet-hub → wallet-charge-info` · `→ offer-kyc-gate` · `→ earnings-fees-dashboard` · `→ wallet-activity-list` (JM-053).
- `wallet-charge-info → wallet-hub` (back) (JM-054).
- `wallet-activity-list → transaction-detail` · `→ wallet-hub` (JM-055).
- `transaction-detail → dispute-open-evidence` · `→ wallet-activity-list` · `→ order-summary-pinned` (JM-056).

### Shared (JM-057..068)
- `notifications-list →` D84 deep-links: `delivered-receipt-confirm` (confirm-receipt) · `wallet-hub` (wallet) · `my-orders` (offers) · `order-chat` (dispute/offer-accepted) · `customer-orders-home` (marketing) · `jeeber-requests-home` (kyc_approved) · `kyc-rejected` (kyc_rejected) · `waiting-no-coverage` (request_expired) (JM-057).
- `notification-prefs → customer-profile` (back) (JM-058).
- `language-settings → customer-profile` (back) (JM-059).
- `password-security → auth-set-password` (social-only) · `→ customer-profile` (back) (JM-061).
- `logout-delete-account → splash` (confirm) · entry from `account-status → logout-delete-account` (JM-062/066).
- `support-ticket → dispute-open-evidence` · `→ customer-profile` (submit); entries `account-status → support-ticket`, `dispute-status → support-ticket`, `kyc-rejected → support-ticket` (JM-063).
- `rate-the-app → customer-profile` (return) (JM-064).
- `dispute-open-evidence → support-ticket` · `→ dispute-status` (submit) · `→ order-chat` (back) (JM-060).
- `dispute-status → support-ticket` · `→ order-chat` (JM-065).
- `account-status → support-ticket` · `→ logout-delete-account` (JM-066).
- `jeeber-profile-reviews → reviews-list` (View all) · `→ offer-review-list` (Close) (JM-067).
- `reviews-list → jeeber-profile-reviews` (back) (JM-068).
- `location-select → saved-addresses` (Saved addresses, Q3) · `→ order-chat` (confirm) · `→ location-map-pin` (new) (JM-024).
- `saved-addresses → address-detail-form` (edit/add) · `→ customer-profile` (back) (JM-049).
- `address-detail-form → saved-addresses` (Save) (JM-050).

---

## D. Shared-file edit batching rule (CTO brief §7)

`app_router.dart` is edited **once per wave** by a single integrator, applying that wave's
route ADDs/REPLACEs from §B in one diff, BEFORE the per-screen engineers wire their call sites.
Same discipline for `injection_container.dart` (wallet/notifications/support/dispute repos) and
the l10n ARB files. Order within a wave:

1. Integrator adds the wave's routes (§B batch) + any redirect-gate logic (account-status, splash).
2. Per-screen engineers build their screen + wire their *own* call-site edges (§C) — these touch
   feature files, not the router.
3. Tab-body swaps (`customer-profile` real screen into Profile tab; KYC-gate into DELIVERY tab)
   touch `shell_screen.dart` / `tabs/*` — batch those per wave too (one owner).

> **`/sign-up` and the email-first inversion (AUTH-OD-1) is the only route decision that is
> genuinely blocked** — see `30_BACKLOG.md` §"Blocking product questions". Everything else has a
> deterministic path/name above.

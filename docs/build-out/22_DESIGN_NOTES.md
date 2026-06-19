# 22 — Design Notes (Per-Screen OMDS + Figma Mapping)

> Author: Principal Product Designer (design-mapping). Date: 2026-06-18.
> Companion to `00_CTO_BRIEF.md`, `10_BLUEPRINT_INVENTORY.md`, `21_NAV_PLAN.md`.
> Purpose: for **every** blueprint screen, give the engineer the OMDS components +
> key tokens + Figma frame reference + notable states so no design decision is
> re-invented at build time. **OMDS only** (Brief §6.3). **Blueprint is the spec**
> (Brief §6.1). **Decisions are law** (Brief §6.2) — cited by id.

---

## 0. Figma MCP status — WORKED ✅

The Figma Desktop MCP (`mcp__figma-desktop__*`) connected successfully against the
open **Jeeb Delivery App** file (`ZOi3kKtw7sd42ssSVX3Kn4`). Confirmed:

- **Pages:** `Getting Started` (11:1833), `Playground` (54301:24521),
  **`Low-Fidelity`** (54301:24497 — the design source), **`Styles`** (49823:12141 — variables),
  **`Components`** (47909:2 — the component kit).
- **`get_variable_defs` on Styles (49823:12141)** returned the full **Material 3
  token set** (light + dark schemes, ref palettes, type ramp, elevation). These are
  the **authoritative tokens** and they match the OMDS/`AppTheme` resolution already
  in the repo (see §1).
- **`get_metadata` on Low-Fidelity** returned frame trees. ⚠️ **Caveat:** the lo-fi
  frames are nearly all named generically (`"Order Status"`, `"Group 42"`, etc.), so
  they do **not** map to blueprint ids by Figma layer-name. The reliable frame
  reference is the **PNG filename recorded per screen in the blueprint**
  (`web/src/screens/_data/<id>.json` → `files[].file`). Those PNG names are the
  canonical "Figma frame id" column below.
- **`get_metadata` on Components (47909:2)** returned a **standard Material 3
  component kit** (M3 list-items with Leading=Checkbox/Radio/Switch/Video, buttons
  with `Style=primary/secondary/tertiary/surface` × `State=enabled/hovered/focused/pressed`,
  snackbars, light/dark schemes). It is **not** a Jeeb-bespoke component set — which
  is exactly why **OMDS (a M3 wrapper) is the correct implementation surface**.

**Net:** Figma gives us authoritative *tokens* and per-screen *reference PNGs*; it does
**not** give bespoke Jeeb components. So per-screen component selection below is driven
by **OMDS** (`omds-component-mapping.md` + `omds_library`), cross-checked against the
prototype `.hf-*` hi-fi design system (`jeeb-mind-map/web/src/styles/jeeb-hifi.css`),
with the Figma PNG as the visual ground truth.

---

## 1. Global tokens (from Figma `Styles` page → wired in `AppTheme` + OMDS)

Pulled live via `get_variable_defs(49823:12141)`. These confirm the brand resolution
recorded in `omds-component-mapping.md §4.3` (M-18) — **no re-litigation needed**.

| Role | Figma variable | Hex | Flutter/OMDS sink |
|------|----------------|-----|-------------------|
| Brand navy | `M3/ref/secondary/secondary10` / `sys/light/secondary-container` | `#0B1351` | `AppTheme._jeebNavy` → `colorScheme.secondaryContainer` (brand primary surface) |
| Brand orange | `M3/sys/light/primary-container` | `#D73B00` | `AppTheme._jeebOrange` → `colorScheme.primaryContainer` (CTAs, Top-up) |
| Primary (M3 terracotta) | `M3/sys/light/primary` | `#8F4C38` | `colorScheme.primary` |
| Error | `M3/sys/light/error` | `#BA1A1A` | `colorScheme.error` (danger CTAs) |
| Surface | `M3/sys/light/surface` | `#FCF8FC` | `colorScheme.surface` |
| On-surface | `M3/sys/light/on-surface` | `#1B1B1E` | `colorScheme.onSurface` |
| On-surface-variant (secondary text) | `M3/sys/light/on-surface-variant` | `#5C4038` | `colorScheme.onSurfaceVariant` / `OmdsColorTokens.textMedium` |
| Outline / divider | `M3/sys/light/outline-variant` | `#E6BEB3` | `OmdsColorTokens.dividerColor` |
| Success | (OMDS) | `#4CAF50` | `OmdsColorTokens.successColor` / `JeebSemanticColors.availableNow` |
| Star rating | (OMDS) | `#FFB800` | `OmdsColorTokens.starRatingColor` |

- **Type ramp:** Figma is M3 Roboto; the app standardizes on **Inter** via
  `OmdsTheme(GoogleFonts.interTextTheme())` (mapping doc §5). Use `textTheme.<role>`
  with M3 role names (`displayLarge`…`labelSmall`) — sizes/line-heights below match
  Figma's `M3/<role>` ramp 1:1 (e.g. `titleLarge` 22/28, `bodyMedium` 14/20, `labelLarge` 14/20).
- **Elevation:** Figma `M3/Elevation Light/1..5` map to OMDS card/sheet elevations
  (cards = level 1, bottom sheets/dialogs = level 3). Prefer OMDS card defaults; do
  not hand-set shadows.
- **Spacing:** 8pt grid — `Spacing.*` (`twoXSmall 4 … fourXLarge 48`) / `OMDSSpacing.*`.
  No bare `SizedBox(n)`/`EdgeInsets(n)` (token gate §9.1 of mapping doc).
- **Radius:** `OmdsBorderRadius.*` only. No `BorderRadius.circular(n)`.

**Standing rule for every screen:** scaffold = `OMDSAppBar` (back/title) + body on
`colorScheme.surface`; all colors via `colorScheme.*` → `context.omdsColorTokens.*`
→ `JeebSemanticColors.*` → `JeebTierColors.*` (mapping §9.2 resolution order); every
asserted/interactive widget carries `Semantics(identifier: '<screenId>_<element>')`
(Brief §5 Maestro blocker, §6.6).

---

## 2. Per-screen mapping

Legend — **Figma frame**: the PNG recorded in `_data/<id>.json` (canonical reference on
the `Low-Fidelity` page). "—" = no PNG in blueprint (spec is `lofiOutline`/`doc` only;
build from `.hf-*` prototype + OMDS). **Decisions** cited from `07_DECISIONS_LOG.md`.

### 2.1 Auth (8 screens)

**`splash`** — Splash (shared) · Figma: `Splash.png`
- OMDS: none (documented exemption — `branded_splash.dart`, dep-free cold start). Navy bg `#0B1351`, centered brand wordmark, `OmdsLoadingState`/spinner exempted.
- States: auto-route by session (D79/D75/D23) — `UserStatus=active`→last-used tab; `pending`→onboarding; no UI dwell. Biometric/long session resumes here.

**`walkthrough`** — Walkthrough (shared) · Figma: `Walkthrough.png`, `Walkthrough 1.png`, `Walkthrough-1.png`
- OMDS: `OmdsPageIndicator` (dots), `OmdsPrimaryButton` (Next/Get started), `OmdsSkipButton`; optionally `OmdsWalkthroughStep` (P3 backlog) for slide layout. Hero art = custom asset (`.hf-illus--hero`).
- States: first-launch-only with Skip (D79). Tokens: `Spacing.xLarge` page padding, `labelLarge` skip.

**`sign-up`** — Sign Up (auth) · Figma: `Sign up.png`
- OMDS: `OMDSAppBar`, `OmdsTextField` (Name, Email), `OmdsPasswordField` (masked + eye toggle), `OmdsPrimaryButton` (Sign up), `OmdsSocialButton` ×3 (FB/Google/Apple — brand colors exempted), `OmdsPrimaryButton(variant: .text)` for "Login" link.
- States: D8/D21/D22/D65. Email-first, email NOT verified; password strength hint; → `phone-otp-verification` (phone = account anchor, G8). Block 2nd auth method on colliding email.

**`login`** — Login (auth) · Figma: `Login.png`, `Log in (Email).png` (variant-2)
- OMDS: `OMDSAppBar`/logo header, `OmdsTextField` (Email), `OmdsPasswordField`, `OmdsPrimaryButton` (Continue), text-variant links (Forgot password, Sign up), `OmdsSocialButton` ×3. Divider = `.hf-divider`→themed `Divider`.
- States: D22/D23/D65. `UserStatus=active` on valid creds → `customer-orders-home`. Surface biometric-unlock entry for returning users.

**`social-login`** — Social Login (auth) · Figma: —
- OMDS: `OmdsLoadingState` (OAuth in-flight overlay), `OmdsErrorState` (provider failure), `OmdsSocialButton` (re-entry). Mostly a transient/loading surface; on collision → `social-collision-prompt`.
- States: D22/D65. New social user → offer Set-a-password (`auth-set-password`).

**`social-collision-prompt`** — Email/Social Collision Prompt (auth) · Figma: —
- OMDS: `OmdsConfirmationDialog` or `OmdsProgressBanner` body + `OmdsPrimaryButton` (Use existing method) / text-variant (Cancel). Explains email already bound to another auth method (D22 — block 2nd method).
- States: blocking modal; routes back to `login`.

**`recover-password`** — Password Recovery / Request Code (auth) · Figma: `Recover password.png`
- OMDS: `OMDSAppBar`, `OmdsTextField` (Email), `OmdsPrimaryButton` (Send code) → `verify-code`. Intro copy `bodyMedium`/`textMedium`.

**`verify-code`** — Verify Recovery Code (auth) · Figma: `Verify code.png`
- OMDS: `OMDSAppBar`, `OmdsOtpInput`, resend link (text-variant) + countdown, `OmdsPrimaryButton` (Verify) → `auth-set-password`. Error state for wrong/expired code via `OmdsTextField` errorText pattern / inline `OmdsErrorState`.

**`auth-set-password`** — Set Password (auth) · Figma: `Set password.png`
- OMDS: `OMDSAppBar`, `OmdsPasswordField` ×2 (new + confirm, each eye toggle), `OmdsPrimaryButton` (Set password). Validation = mismatch/strength inline.
- States: recovery path → `login`; in-app social path → `customer-profile`.

**`biometric-unlock`** — Biometric Unlock (auth) · Figma: — (impl ref: `biometric_lock_screen.dart`)
- OMDS: `OmdsPrimaryButton` (Unlock), `OmdsOtpInput` (passcode fallback), "Use password instead" text-variant. Face/Touch icon = themed `Icon`.
- States: D23/D8/D79 — returning users skip OTP.

### 2.2 Customer (15 screens)

**`customer-orders-home`** — Requests Tab / home (customer) · Figma: `Request - My Orders - Screen [User].png`, `Request - Pending Requests - Screen [User].png` (variant-2), `Request Empty State [User].png` (empty)
- OMDS: persistent `OMDSAppBar` with **wallet chip** (→`wallet-hub`, D33) + **notification bell** (→`notifications-list`); `OmdsSearchBar`; `OmdsFilterChips`/segmented sub-tabs (In Progress | Pending Requests | Replies); `OmdsRequestCard` rows; `OmdsEmptyState`; `OmdsLoadingState`; `OmdsPullToRefresh`. **Mic/New-Order FAB** = custom `mic_fab.dart` (no OMDS equivalent, mapping §3.2) → `request-type-selection`. Bottom nav = shell `NavigationBar` (exemption).
- States: normal / empty / per-sub-tab (in_progress, broadcast/no_coverage, offers_in). "Track my order" CTA on in-progress rows → `order-tracking`.

**`customer-profile`** — Profile Tab (customer) · Figma: `Customer Profile.png`
- OMDS: `OMDSAppBar` (wallet chip + bell), `OmdsProfileAvatar` + name + per-role rating (`OmdsStarRatingDisplay`), `OmdsSettingsSection` + `OmdsSettingsRow` for each row (Register as delivery, Saved addresses, Password & security, Notification prefs, Language, Contact us, Rate the app, Logout/Delete). Role-switch lives here (Brief §3).
- States: shows per-role rating; "Register as delivery" row → onboarding.

**`request-type-selection`** — New Order / Tier Choice (customer) · Figma: `Request type [Client].png`
- OMDS: `OMDSAppBar`, **tier carousel** = custom `tier_card.dart` (could extend `OmdsSectionCard` w/ accent, mapping §3.5) using `JeebTierColors`, radio selection per tier (Economy Max/Plus/Economy/Premium/Standard — see Figma frame 54346:496 SLA bands), `OmdsPageIndicator`, `OmdsPrimaryButton` (Proceed) → `location-select`.
- States: tier list with SLA sub-labels (within 3 days / 24h / 3h / 1h / 0-3 days).

**`location-select`** — Set Location (shared, customer-entry) · Figma: `Client Location.png`
- OMDS: `OMDSAppBar`, M3 radio rows (Current Location / saved addresses), `OmdsPrimaryButton` (New Location + → `location-map-pin`), saved-address rows (→`saved-addresses`), Confirm → `order-chat`. Use `OmdsSettingsRow`-style list.

**`location-map-pin`** — Pin Location on Map (shared) · Figma: `Capture Location.png`
- OMDS: `OMDSAppBar`; **map** = custom `map_preview_canvas.dart` (no OMDS map, mapping §3.4); address-preview card under pin (`OmdsSectionCard`); `OmdsPrimaryButton` (Pin Location) → returns to `location-select`.

**`order-chat`** — 1:1 Chat (pinned price) / Compose Request (customer) · Figma: `Sending my initial request [Client].png`, `chat.png`, `chat-1.png`, `chat-2.png`, `Chat [Client].png`, `Chat after aproval [Client].png`
- OMDS (chat module — currently P3 backlog, mapping §3.1, M-04/M-11): `OmdsChatBubble` (in/out), `OmdsChatTile`, `OmdsDateChip`, `OmdsVoicePlayer`, `OmdsRecordingInput`/composer, `OmdsActionOption`, `OMDSAppBar` (counterpart name/avatar). **Pinned-price header** = `OmdsSectionCard`/`.hf-card--navy` strip (authoritative accepted price). Mic = custom; attach (+) = `OmdsMediaPickerSheet`.
- States: pre-accept compose (first message = the request) vs post-accept 1:1 ("Chat after approval"). Pinned authoritative price + ETA after accept.

**`my-orders`** — Replies / offer cards (customer) · Figma: `Replies - My Orders - Screen [User].png` (variant-2)
- OMDS: `OMDSAppBar`, `OmdsSearchBar`, sub-tab chips, `OmdsRequestCard`/offer cards with offers-count badge (`OmdsChip`), "Check Offers" `OmdsPrimaryButton` → `order-chat`/`offer-review-list`; tap row → `order-chat`. Accept → `offer-accept-confirm`.
- States: Replies sub-tab selected; per-card offer count.

**`offer-review-list`** — Offer Review / Customer (customer) · Figma: —
- OMDS: `OMDSAppBar` ("Offers for ORD-… (8)"), one `OmdsRequestCard`/`OmdsServiceCard` per Jeeber (name, `OmdsStarRatingDisplay`, price, ETA, note, "Pay $X cash on delivery"), sort chips (`OmdsFilterChips`: price/ETA/rating), per-card `OmdsPrimaryButton` (Accept) → `offer-accept-confirm`. Tap Jeeber → `jeeber-profile-reviews`.
- States: Jeebers blind to competitors; "Accept only one offer" helper (`textMedium`).

**`offer-accept-confirm`** — Accept Offer Confirmation (customer) · Figma: —
- OMDS: `OmdsConfirmationDialog` / bottom sheet — title "Accept Kamal's offer?", "Pay $35 cash on delivery" line, "Other offers will close" warning (`OmdsProgressBanner`/`.hf-card--warn`), Cancel (text-variant) + Confirm (`OmdsLoadingButton`, triggers capture + closes others).

**`order-summary-pinned`** — Order Summary + Pinned Price (customer) · Figma: —
- OMDS: `OmdsSectionCard`/`OmdsOrderSummary` header (pinned authoritative accepted price, Jeeber name + `OmdsStarRatingDisplay`, ETA, tier + items), "Pay cash on delivery" reminder banner, `OmdsPrimaryButton` (Open chat → `order-chat`) + link to `order-tracking`.

**`order-tracking`** — Track / Order Status Stepper (customer) · Figma: `Order tracking.png`
- OMDS: `OMDSAppBar` (title "Order Tracking" — **fix 'Traking' typo**), pinned order-summary header (`OmdsSectionCard`: accepted price, Jeeber, locked ETA), **status stepper** `OmdsStepperProgress`/`delivery_status_progress.dart` (Ordered→Picked→In Transit→Delivered, 4 steps, D70), map view (custom canvas + `eta_badge.dart`), dispute link (text-variant)→`dispute-open-evidence`, no-show action sheet (Reassign→`offer-review-list` / Re-broadcast→`waiting-no-coverage`).
- States: `accepted`/`heading_to_pickup`/`picked`/`in_transit` (D11/D18/D71); auto-advance to `delivered-receipt-confirm`.

**`delivered-receipt-confirm`** — Confirm Receipt (customer) · Figma: —
- OMDS: push-triggered sheet/`OmdsConfirmationDialog` — "Did you receive your order?", "Pay $35 cash to Kamal" line, proof-of-delivery photo (`OmdsCachedImage`/`OmdsImageGrid`, D3), "Not yet" (text-variant → `dispute-open-evidence`), "Confirm ✓" (`OmdsLoadingButton` → `rate-jeeber`). Auto-complete-on-timeout note.
- States: `delivered_pending_confirm` → `completed` (D3/D11).

**`rate-jeeber`** — Rate Jeeber / Mandatory (customer) · Figma: — (impl ref: `rating_prompt_screen.dart`)
- OMDS: `OMDSAppBar` (no dismiss — mandatory, D56), `OmdsStarRating` (interactive, mandatory), `OmdsTextField` (optional review), order-context header (`OmdsProfileAvatar` + ref), `OmdsLoadingButton` (Submit, completion-gated), `OmdsErrorState`.
- States: written review immutable, first-name shown, hidden until ≥5 reviews (D58/D59); cannot dismiss without rating.

**`waiting-no-coverage`** — Waiting State / No Coverage (customer) · Figma: —
- OMDS: `OmdsEmptyState`/`OmdsProgressBanner` ("Waiting for a Jeeber…" or "No coverage"), `OmdsLoadingState` (broadcast in flight), `OmdsPrimaryButton` (Cancel request → `cancel-request-confirm`). Van illustration `.hf-illus--van`.
- States: broadcast / no_coverage (Figma lo-fi frame "Waiting for delivery driver", 54346:478).

**`cancel-request-confirm`** — Cancel Request? (customer) · Figma: — · *No standalone `_data` JSON; defined in `blueprint.json` graph (`nameToId`/edges).*
- OMDS: `OmdsConfirmationDialog` — "Cancel this request?", warning copy, Cancel (keep) text-variant + Confirm (`OmdsPrimaryButton(variant: .text)` danger via `colorScheme.error`).

### 2.3 Jeeber (22 screens)

**`delivery-register-prompt`** — Jeeber Gate / not registered (jeeber) · Figma: `Delivery screen - User not registered as delivery man.png`
- OMDS: `OMDSAppBar` ("DELIVERY"), `OmdsEmptyState` (illustration + headline "You are not registered…" + body), `OmdsPrimaryButton` (Register now → `delivery-onboarding-image-upload`). Bottom nav (shell).
- States: gate shown when not-registered OR KYC not approved.

**`delivery-onboarding-image-upload`** — Register as Delivery / Photo Upload (jeeber) · Figma: `Delivery man onboarding - Personal Information.png`
- OMDS: `OMDSAppBar` (back → `delivery-register-prompt`, "Personal Information"), `OMDSLabeledStepperProgress` (step 1), photo upload area = custom (`photo_attachment` / `OmdsMediaPickerSheet` + `OmdsImageGrid`), helper copy, `OmdsPrimaryButton` (Continue, gated on photo) → `delivery-onboarding-personal-details`.

**`delivery-onboarding-personal-details`** — Personal Details (jeeber) · Figma: `Delivery man onboarding - Address - New Address.png`
- OMDS: `OMDSAppBar`, `OMDSLabeledStepperProgress`, `OmdsTextField`/`OmdsValidatedTextField` (Name, State, Country, Street, Address). **NO vehicle-number field (D20).** `OmdsPrimaryButton` (Continue) → `delivery-onboarding-service-area`.

**`delivery-onboarding-service-area`** — Service Area (jeeber) · Figma: `Delivery man onboarding - Service Area.png`
- OMDS: `OMDSAppBar`, `OMDSLabeledStepperProgress`, "Set your home base" header, map/pin = custom canvas (Select row → `location-map-pin`), `OmdsRangeSlider` (distance preference), `OmdsPrimaryButton` (Continue, gated on pin) → `kyc-identity`. Note: matching uses live location; home base = fallback (D51).

**`kyc-identity`** — KYC / Verify Identity (jeeber) · Figma: — (impl ref: `kyc_wizard_screen.dart`)
- OMDS: `OMDSAppBar`, `OMDSLabeledStepperProgress`, 3× photo-upload tiles (Gov ID front/back, Selfie — `OmdsImageGrid` + `OmdsMediaPickerSheet`), `OmdsPrimaryButton` (Submit for review) → `onboarding-funding`. Note: single final manual review; cannot offer until approved.

**`onboarding-funding`** — Add Funds to Get Started (jeeber) · Figma: —
- OMDS: `OMDSAppBar`, starter-credit explainer card (`OmdsSectionCard`/`OmdsPromoBanner`, 🎁 fixed promo credit, non-refundable, usable after KYC — D42), `OmdsPrimaryButton` (orange, "Top up now" → `wallet-charge-info`) + `OmdsPrimaryButton(variant: .outlined)` (Continue → `kyc-pending-status`).
- States: D28/D42/D38/D39/D1 — top-up allowed pre-approval; you reserve 10%/offer (D1).

**`kyc-pending-status`** — KYC Pending / Result (jeeber) · Figma: —
- OMDS: `OMDSAppBar`, status card (`OmdsProgressBanner` pending / `OmdsEmptyState` approved / `OmdsErrorState` rejected), `OmdsPrimaryButton` (resubmit → `kyc-identity` | link to feed → `jeeber-requests-home` | wallet → `wallet-hub`).
- States: Pending / Approved / Rejected (→`kyc-rejected`). Top-up allowed while pending.

**`kyc-rejected`** — KYC Verification Failed (jeeber) · Figma: —
- OMDS: `OMDSAppBar` ("Verification failed"), `OmdsErrorState` (large cross icon, "We couldn't verify your identity", reason line), `OmdsPrimaryButton` ("Appeal via support" → `support-ticket`) + `OmdsPrimaryButton(variant: .outlined)` (Back to Profile).
- States: D7/D52/D87 — rejection final; appeal only via support ticket.

**`delivery-requests`** — DELIVERY Tab (jeeber) · Figma: `Delivery Screen [Delivery Man].png`, `Delivery Screen - Empty State [Delivery Man].png` (empty)
- OMDS: `OMDSAppBar` ("DELIVERY" + wallet chip + bell), **availability toggle** = custom `availability_toggle_card.dart` (or `OmdsSwitchTile`, mapping §3.6), sub-tab chips (Requests | Pending Response | Replies), `OmdsSearchBar`, `OmdsRequestCard` feed rows w/ per-row Ignore (text-variant) + Offer (`OmdsPrimaryButton`→`offer-composer`), `OmdsEmptyState`, `OmdsPullToRefresh`. Pending Response → `jeeber-pending-offers`; Replies → `delivery-order-chat`.
- States: registered-but-gated routes to `delivery-register-prompt`; approved → `jeeber-requests-home`; empty vs feed.

**`jeeber-requests-home`** — Delivery Feed (jeeber) · Figma: `iPhone 16 & 17 Pro Max - 9.png` (pending-response variant), `iPhone 16 & 17 Pro Max - 10.png` (replies variant)
- OMDS: same kit as `delivery-requests` — `OmdsRequestCard` feed, `OmdsFilterChips` sub-tabs, `OmdsSearchBar`, `OmdsEmptyState`, `OmdsPullToRefresh`. Request feed card = `request_feed_card.dart` → map to `OmdsRequestCard`; nearby chip = `OmdsIconChip`. Open row → `delivery-order-chat`; offer → `offer-composer`.
- States: variant-pending-response-tab, variant-replies-tab.

**`offer-composer`** — Structured Offer Composer (jeeber) · Figma: —
- OMDS: `OMDSAppBar` ("Your offer · ORD-…"), `OmdsTextField` (Price $), `OmdsBottomSheetSelector`/dropdown (ETA — must fit tier SLA band, D14), `OmdsTextField` (Note optional), fee breakdown card (`OmdsSectionCard`: "Platform fee (10%) $3.50" exact no-round, "You earn (cash) $31.50", reserve copy), `OmdsLoadingButton` (Send offer — reserves on send). **No in-place edit** (withdraw + re-offer, D15). Replaces free-text `PRICE\TIME`.
- States: `OfferStatus=submitted`, `WalletTxnType=reserve` (D1/D15/D44/D37/D43/D45). Insufficient → `offer-insufficient-balance`; not-approved → `offer-kyc-gate`.

**`offer-insufficient-balance`** — Insufficient Balance to Offer (jeeber) · Figma: —
- OMDS: `OmdsProgressBanner`/`OmdsErrorState` inline ("Not enough — top up to bid"), bottom sheet showing needed-vs-available (`OmdsAmount`/`.hf-amount`), `OmdsPrimaryButton` (Top up → `wallet-charge-info`), text-variant (Keep editing). Draft preserved + auto-sent after top-up.

**`offer-kyc-gate`** — Offering Gated / KYC Not Approved (jeeber) · Figma: —
- OMDS: `OmdsEmptyState`/`OmdsProgressBanner` ("Get approved to start sending offers" + current KYC status), `OmdsPrimaryButton` (Start/continue KYC → `kyc-identity`/`delivery-register-prompt`). Note: top-up allowed pre-approval.

**`jeeber-pending-offers`** — Pending Response (jeeber) · Figma: — · *No standalone `_data` JSON; defined in `blueprint.json` graph.*
- OMDS: `OmdsRequestCard` list of submitted offers awaiting customer (price/ETA/reserve badge), `OmdsEmptyState`, `OmdsPullToRefresh`. Likely a sub-tab view of `delivery-requests`. Withdraw action = text-variant danger.

**`delivery-order-chat`** — Delivery Chat with Customer (jeeber) · Figma: `Delivery Screen - Chat [Delivery Man].png`
- OMDS (chat module, P3 backlog): `OMDSAppBar` (customer name/avatar), `OmdsChatBubble`, pinned order-context strip (`OmdsSectionCard`), milestone action `OmdsPrimaryButton` (→ `jeeber-mark-delivered`), composer (`OmdsRecordingInput`), attach (`OmdsMediaPickerSheet`), mic (custom), send.
- States: structured offer composer replaces free-text PRICE\TIME (D15).

**`jeeber-mark-delivered`** — Fulfilment Milestones / Mark Delivered (jeeber) · Figma: —
- OMDS: `OmdsStepperProgress` (imperative milestones, D70: heading off→picked→in transit→delivered), per-step `OmdsPrimaryButton`, proof capture (`OmdsImageGrid`/`OmdsMediaPickerSheet`, D3), `OmdsTextField` (optional note), `OmdsLoadingButton` (Mark delivered → `delivered_pending_confirm`). On completion → `feedback-rate-delivery`.

**`feedback-rate-delivery`** — Rate Customer (jeeber) · Figma: `Feedback Screen [Client_Delivery Man].png`
- OMDS: `OMDSAppBar`, `OmdsStarRating` (mandatory, D56), `OmdsTextField` (optional feedback), `OmdsLoadingButton` (Submit → `delivery-requests`). **No dismiss/skip** (mandatory). Per-role rating (D6).
- States: unrated orders auto-close after N days.

**`earnings-fees-dashboard`** — Earnings & Fees Dashboard (jeeber) · Figma: — (impl ref: `earnings_dashboard_screen.dart`)
- OMDS: `OMDSAppBar` ("Earnings & fees"), `OmdsStatCard` ×N (total cash earned net COD, total platform fees 10% captured, net-per-offer running totals, deliveries count, rating, member-since), `OmdsCalendarWeekStrip` (P3 — time-period nav), `OmdsPullToRefresh`, links → `wallet-hub` / `wallet-activity-list`.

**`wallet-hub`** — Wallet Hub (jeeber) · Figma: — (currently `/wallet` = "coming soon" stub, Brief §4)
- OMDS: `OMDSAppBar` ("Wallet"), available-balance amount (`OmdsAmount`/`.hf-amount--xl`), gift-credit badge (`OmdsChip` 🎁 +$5, post-KYC), **affordability card** (`OmdsSectionCard` "✅ You have enough to bid" / amber "Top up to keep bidding" — NOT a capacity number, D43), reserved-now line (sum of holds), orange `OmdsPrimaryButton` ("+ Top up" → `wallet-charge-info`), "Earnings & fees ›" `OmdsSettingsRow` → dashboard, "How fees work" explainer (`OmdsSectionCard`), `OmdsStatCard`/typed activity rows (Reserve−/Fee−/Released+/Refund+/Top up+/Gift+), "See all activity" → `wallet-activity-list`, KYC-pending banner (`OmdsProgressBanner`).
- States: healthy / low (amber) / empty / all-reserved (D1/D41/D37/D43/D44/D33).

**`wallet-charge-info`** — How to Add Funds (jeeber) · Figma: —
- OMDS: `OMDSAppBar`, steps list (`OmdsSectionCard`/numbered rows: visit store, give phone/ID, pay cash → store credits wallet), info banner (`OmdsProgressBanner` "balance updates automatically"), `OmdsPrimaryButton(variant: .outlined)` (Back to wallet). **No payment, no amount entry, no card** (D41/D1, replaces Q18/Q19).

**`wallet-activity-list`** — All Wallet Activity (jeeber) · Figma: —
- OMDS: `OMDSAppBar` ("Activity"), full ledger list with typed rows + `OmdsShimmer` skeletons + infinite scroll, each row amount/sign/type-icon/order-ref (`OmdsAmount` credit/debit). Tap row → `transaction-detail`.

**`transaction-detail`** — Transaction Detail (jeeber) · Figma: —
- OMDS: `OMDSAppBar` (per-type title), `OmdsSectionCard` with per-type explainer (Reserve pending / Fee won [exact 10% + pinned price] / Released [reason] / Refund / Penalty [→dispute] / Top up [method] / Gift), amount/date/status, link to related order.

### 2.4 Shared (17 screens — counted across roles)

**`notifications-list`** — Notifications (shared) · Figma: —
- OMDS: `OMDSAppBar` ("Notifications"), list rows (`OmdsChatTile`-style / `OmdsSettingsRow`: icon + text + timestamp), tier-modulated urgency styling, `OmdsEmptyState`, inline confirm-receipt action where applicable. Deep-links: offers→`my-orders`, accepted/dispute→`order-chat`, wallet→`wallet-hub`, KYC-approved→`jeeber-requests-home`, confirm-receipt→`delivered-receipt-confirm`.

**`notification-prefs`** — Notification Preferences (shared) · Figma: — (impl ref: `notification_preferences_screen.dart`)
- OMDS: `OMDSAppBar`, `OmdsSettingsSection` + `OmdsSettingsSwitchRow` per category (offers, status, wallet D64). Transactional category locked/disabled (cannot turn off). Push-only note (R2).

**`language-settings`** — Language Settings EN/AR (shared) · Figma: —
- OMDS: `OMDSAppBar` ("Language"), `OmdsSettingsSection` with selectable rows (English / العربية — selection indicator). Arabic triggers RTL mirror. Apply/back → `customer-profile`.

**`password-security`** — Password & Security (shared) · Figma: —
- OMDS: `OMDSAppBar`, `OmdsPasswordField` ×3 (current, new, confirm), set-password entry for social-only accounts, `OmdsPrimaryButton` (Save), inline validation.

**`support-ticket`** — Contact Us / Support Ticket (shared) · Figma: —
- OMDS: `OMDSAppBar` ("Contact us"), `OmdsBottomSheetSelector`/`OmdsTagSelector` (subject/category), `OmdsTextField` (message body, multiline), attach evidence (`OmdsMediaPickerSheet`), link to related order/dispute, `OmdsPrimaryButton` (Submit), existing-tickets list (`OmdsSettingsRow` + status `OmdsChip`).

**`rate-the-app`** — Rate the App (shared) · Figma: —
- OMDS: `OmdsConfirmationDialog`/sheet — `OmdsStarRating`, prompt copy, `OmdsPrimaryButton` (Rate → store) + text-variant (Later). Routes back to `customer-profile`.

**`logout-delete-account`** — Logout / Delete Account Confirm (shared) · Figma: —
- OMDS: `OmdsConfirmationDialog` ×2 — Logout (confirm) + Delete account (irreversible warning, `colorScheme.error` danger button, status→deleted). Confirm → `splash`.

**`dispute-open-evidence`** — Dispute (open + evidence) (shared) · Figma: —
- OMDS: `OMDSAppBar`, evidence pickers (`OmdsImageGrid` photo + `OmdsVoicePlayer`/recording for voice — free, D54), auto-attached chat & GPS/status timeline (`OmdsSectionCard`/`OmdsStepperProgress` read-only), `OmdsTextField` (description), `OmdsLoadingButton` (Submit → `dispute-status`), link to `support-ticket`.
- States: `disputed`/`open`/`evidence` (D19/D53/D2/D54/D76); manual v1.

**`dispute-status`** — Dispute Status (shared) · Figma: —
- OMDS: `OMDSAppBar`, status card (`OmdsProgressBanner`: open/under-review/resolved), `OmdsStepperProgress` timeline, ledger outcome (fee_refund/penalty), `OmdsSettingsRow` link to ticket. Back → `dispute-open-evidence`.

**`account-status`** — Account Status / Suspended-Locked (shared) · Figma: —
- OMDS: `OmdsErrorState`/`OmdsProgressBanner` (suspended/locked banner, D5), reason copy, `OmdsPrimaryButton` (Contact support → `support-ticket`, D76) + text-variant (Sign out). No tab access while suspended.

**`jeeber-profile-reviews`** — Jeeber Profile with Reviews (shared) · Figma: `delivery man profile.png`
- OMDS: modal/sheet `OMDSAppBar` w/ close (X → `offer-review-list`), `OmdsProfileAvatar` + name + `OmdsStarRatingDisplay`, summary `OmdsStatCard` (deliveries, avg rating, member-since), `OmdsReviewCard` list (reviewer first-name, stars, snippet, Helpful(N) + Reply), "View all" → `reviews-list`.

**`reviews-list`** — All Reviews (shared) · Figma: —
- OMDS: `OMDSAppBar`, `OmdsReviewCard`/`OmdsStarRatingDisplay` infinite-scroll list + `OmdsShimmer` skeletons (D73), reviewer first-name/initial (D58), cold-start: hide score until N≥5 + "New" badge (`OmdsChip`, D59), report-a-review action (D27).

**`saved-addresses`** — Saved Addresses Manager (customer/shared) · Figma: — (impl ref: `saved_addresses_screen.dart`)
- OMDS: `OMDSAppBar` ("Addresses"), `OmdsSettingsRow`/list of addresses (label + summary + edit/delete), default indicator (`OmdsChip`), `OmdsEmptyState`, `OmdsPrimaryButton` ("+ Add new address" → `address-detail-form`).

**`address-detail-form`** — Address Detail Form (customer) · Figma: —
- OMDS: `OMDSAppBar`, map-pin preview (custom canvas), `OmdsValidatedTextField` (label, building, floor/apt, delivery notes, phone for COD), `OmdsPrimaryButton` (Save address → `saved-addresses`).

**`phone-otp-verification`** — Phone OTP Verification (shared) · Figma: —
- OMDS: `OMDSAppBar`, `OmdsPhoneInput` (number entry/confirm), `OmdsOtpInput` (multi-digit), resend link + countdown (text-variant), `OmdsPrimaryButton` (Verify), error state (wrong/expired). Phone = account anchor (email not verified, D21).

> Shared-role count (17) includes `location-select`, `location-map-pin`, `phone-otp-verification`,
> `splash`, `walkthrough`, `dispute-open-evidence`, `dispute-status`, `account-status`,
> `jeeber-profile-reviews`, `reviews-list`, `language-settings`, `notification-prefs`,
> `notifications-list`, `password-security`, `support-ticket`, `rate-the-app`, `logout-delete-account`.

---

## 3. Cross-cutting component decisions (apply everywhere)

| Concern | OMDS resolution | Note |
|---------|-----------------|------|
| App bar | `OMDSAppBar` | back chevron + title; persistent variant adds wallet chip + bell on the 3 home tabs |
| Bottom nav | M3 `NavigationBar` in `shell_screen.dart` | **documented exemption** — no `OmdsBottomNavBar` yet (mapping §3.1) |
| Primary CTA | `OmdsPrimaryButton` (filled / `.outlined` / `.text`) | orange `primaryContainer` for top-up/proceed; `colorScheme.error` for destructive |
| Async CTA | `OmdsLoadingButton` | submit/accept/offer-send |
| Text input | `OmdsTextField` / `OmdsValidatedTextField` / `OmdsPasswordField` / `OmdsPhoneInput` / `OmdsOtpInput` | never raw `TextField` |
| Cards | `OmdsSectionCard` / `OmdsRequestCard` / `OmdsServiceCard` / `OmdsStatCard` / `OmdsReviewCard` | tier accent via `JeebTierColors` |
| Empty/error/loading | `OmdsEmptyState` / `OmdsErrorState` / `OmdsLoadingState` / `OmdsShimmer` | every list screen ships all four |
| Refresh | `OmdsPullToRefresh` | all feeds/lists |
| Rating | `OmdsStarRating` (input) / `OmdsStarRatingDisplay` (read) | star color `OmdsColorTokens.starRatingColor` |
| Chat | `OmdsChatBubble` / `OmdsChatTile` / `OmdsVoicePlayer` / `OmdsRecordingInput` / `OmdsMediaPickerSheet` / `OmdsActionOption` | **P3 backlog** — gated on chat backend (M-04/M-11) |
| Dialogs/sheets | `OmdsConfirmationDialog` / `OmdsBottomSheetSelector` / `showOmdsSnackbar` | confirm/destructive/select |
| Stepper | `OmdsStepperProgress` / `OMDSLabeledStepperProgress` | tracking + onboarding + milestones |
| Money | `.hf-amount` pattern → themed `Text` (credit/debit color) | no OMDS `OmdsAmount` yet — use `colorScheme.error`/`successColor` |
| Maps | custom `map_preview_canvas.dart` / `eta_badge.dart` / `gps_lost_banner.dart` | **no OMDS map** — Jeeb custom (mapping §3) |
| Mic / waveform | custom `mic_fab.dart` / `waveform_visualizer.dart` | Jeeb custom, domain-specific |

**Jeeb-custom widgets (no OMDS equivalent — keep, per mapping §3):** mic FAB, waveform
visualizer, map canvas/ETA badge/GPS-lost banner, tier card, availability toggle.

---

## 4. Open design questions to raise (do NOT invent — Brief §6.2)

1. **`order-chat` chat module** is P3 backlog in OMDS (`OmdsChatBubble` et al.) but is a
   core customer surface (the request *is* the first chat message, Brief §3). Needs a
   decision: ship chat now on OMDS chat primitives, or interim custom? (refs M-04/M-11).
2. **`OmdsAmount`/money component** does not exist; wallet/earnings rely on the `.hf-amount`
   pattern. Confirm themed-`Text` + `successColor`/`error` is acceptable, or add to OMDS.
3. **`OmdsBottomNavBar`** absent → shell keeps M3 `NavigationBar` exemption. Confirm stays.
4. **Tier card** accent styling — extend `OmdsSectionCard` with `JeebTierColors` accent, or
   keep custom `tier_card.dart`? (mapping §3.5).
5. **`cancel-request-confirm` / `jeeber-pending-offers`** have no standalone `_data/<id>.json`
   (only graph entries). Build from blueprint edges + `.hf-*` prototype; flag if a fuller
   contract is needed.

# OMDS Component Mapping Audit — Jeeb Mobile

**Ticket:** T-design-001 (JEEB-101)
**Date:** 2026-05-16 (initial), **2026-05-18 (post-sweep refresh)**
**Scope:** All screens in `lib/features/**` and `lib/app/branded_splash.dart`
**OMDS Library:** `omds-flutter/omds_library` (119 widgets across 21 modules)
**Related:**
- `CRITICAL-FIGMA-IMPLEMENTATION-GAP.md` (Figma vs implementation gap)
- `design-system-sweep.md` (post-mortem of the May 2026 OMDS sweep)

> **Status:** Post-sweep. Adoption is now ~98%. The original audit text below
> documented the pre-sweep baseline; tables and counts have been refreshed in
> place to reflect the current state. Remediation items in §7 are all marked
> Done — see `design-system-sweep.md` for the wave-by-wave breakdown.

---

## 1. Screen-to-OMDS Component Mapping

25 screens audited. 83 files import `package:omds/omds.dart`.

### 1.1 Screens Using OMDS Components Correctly

| # | Screen | File | OMDS Components Used | Raw Material Widgets |
|---|--------|------|---------------------|---------------------|
| 1 | Client Home | `home_client/presentation/client_home_screen.dart` | `OmdsSearchBar`, `OmdsFilterChips`, `OmdsEmptyState`, `OmdsSectionHeader`, `OmdsLoadingState`, `OmdsPullToRefresh`, `Spacing` | — |
| 2 | Jeeber Home | `jeeber_home/presentation/jeeber_home_screen.dart` | `OmdsFilterChips`, `OmdsEmptyState`, `OmdsLoadingState`, `OmdsPullToRefresh`, `Spacing`, `Sizes` | — |
| 3 | Shell | `shell/shell_screen.dart` | `OMDSAppBar` | `NavigationBar` (documented exemption — no OMDS equivalent) |
| 4 | Onboarding | `onboarding/onboarding_screen.dart` | `OmdsPageIndicator`, `OmdsPrimaryButton`, `OmdsSkipButton`, `Spacing` | — |
| 5 | Settings | `settings/presentation/screens/settings_screen.dart` | `OMDSAppBar`, `OmdsSettingsSection`, `OmdsSettingsRow`, `OmdsSettingsSwitchRow`, `Spacing` | — |
| 6 | Profile Edit | `settings/presentation/screens/profile_edit_screen.dart` | `OMDSAppBar`, `OmdsTextField`, `OmdsPrimaryButton`, `Spacing` | — |
| 7 | Saved Addresses | `settings/presentation/screens/saved_addresses_screen.dart` | `OMDSAppBar`, `OmdsValidatedTextField`, `OmdsPrimaryButton`, `OmdsEmptyState` | — |
| 8 | Notification Prefs | `settings/presentation/screens/notification_preferences_screen.dart` | `OMDSAppBar`, `OmdsSettingsSwitchRow` | — |
| 9 | Registration | `registration/presentation/registration_screen.dart` | `OMDSAppBar`, `OmdsPhoneInput`, `OmdsPrimaryButton`, `Spacing` | — |
| 10 | Voice Request | `voice_request/presentation/voice_request_screen.dart` | `OMDSAppBar`, `OmdsPrimaryButton`, `OmdsButtonVariant`, `Spacing`, `showOmdsSnackbar` | — |
| 11 | Transcription | `transcription/presentation/transcription_screen.dart` | `OMDSAppBar`, `OmdsTextField`, `OmdsPrimaryButton`, `OmdsShimmer`, `Spacing` | — |
| 12 | Tier Selection | `tier_selection/presentation/tier_selection_screen.dart` | `OMDSAppBar`, `OmdsPageIndicator`, `OmdsPrimaryButton`, `Spacing` | — |
| 13 | Request Summary | `request_summary/presentation/request_summary_screen.dart` | `OMDSAppBar`, `OmdsLoadingButton`, `OmdsBorderRadius`, `Spacing` | — |
| 14 | Offer Submission | `offers/presentation/offer_submission_screen.dart` | `OMDSAppBar`, `OmdsTextField`, `OmdsLoadingButton`, `OmdsBorderRadius`, `Spacing`, `Sizes` | — |
| 15 | Earnings Dashboard | `earnings/presentation/earnings_dashboard_screen.dart` | `OmdsPrimaryButton`, `OmdsPullToRefresh`, `OmdsBorderRadius`, `Spacing` | — |
| 16 | KYC Wizard | `kyc/presentation/kyc_wizard_screen.dart` | `OMDSAppBar`, `OMDSLabeledStepperProgress`, `OmdsTextField`, `OmdsPrimaryButton`, `showOmdsSnackbar`, `Spacing` | — |
| 17 | Location Picker | `location/presentation/screens/location_picker_screen.dart` | `OMDSAppBar`, `Spacing` | — |
| 18 | Delivery Tracking | `location/presentation/screens/delivery_tracking_screen.dart` | `OMDSAppBar`, `OMDSSpacing` | — |
| 19 | Chat Detail | `deep_link_targets/chat_detail_screen.dart` | `OMDSAppBar`, `OmdsEmptyState` | — |
| 20 | Delivery Detail | `deep_link_targets/delivery_detail_screen.dart` | `OMDSAppBar`, `OmdsEmptyState` | — |
| 21 | Rating Prompt | `deep_link_targets/rating_prompt_screen.dart` | `OMDSAppBar`, `OmdsStarRating`, `OmdsTextField`, `OmdsLoadingButton`, `OmdsErrorState`, `OmdsBorderRadius`, `Spacing` | — |
| 22 | KYC Status | `deep_link_targets/kyc_status_screen.dart` | `OMDSAppBar`, `OmdsEmptyState` | — |
| 23 | Biometric Lock | `biometric_auth/presentation/biometric_lock_screen.dart` | `OmdsPrimaryButton`, `OmdsOtpInput`, `Spacing` | — |
| 24 | Jeeber Request Detail | `jeeber_request_detail/presentation/jeeber_request_detail_screen.dart` | `OmdsPrimaryButton`, `OmdsBorderRadius`, `Spacing` | — |
| 25 | Jeeber Unavailable | `jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart` | `OMDSAppBar`, `OmdsEmptyState` | — |

### 1.2 Splash Screen (Special Case)

| Screen | File | OMDS Components Used | Notes |
|--------|------|---------------------|-------|
| Branded Splash | `lib/app/branded_splash.dart` | **None — documented exemption** | Intentionally dependency-free to avoid cold-start latency. Hardcoded brand color is the single allow-listed exception in `tool/check_design_tokens.sh`. |

---

## 2. Raw Material Widget Violations

> **Status — RESOLVED.** All raw-Material violations identified in the
> pre-sweep audit were fixed in Wave 1 of the OMDS design system sweep.
> Counts below show **before → after**. Net remaining violations: **0**
> (excluding the documented `NavigationBar` and `branded_splash` exemptions).

### 2.1 Buttons

| Raw Widget | Pre-Sweep Count | OMDS Replacement | Status |
|-----------|---------|------------------|--------|
| `ElevatedButton` | 3 | `OmdsPrimaryButton` | **0 remaining — Done** |
| `OutlinedButton` | 8 | `OmdsPrimaryButton(variant: .outlined)` | **0 remaining — Done** |
| `TextButton` | 11 | `OmdsPrimaryButton(variant: .text)` | **0 remaining — Done** |

**Total before sweep:** 22 button violations.
**Total after sweep:** **0** in `lib/features/**`. `OmdsPrimaryButton` is now used across **22+ screens**.

### 2.2 Input Fields

| Raw Widget | Pre-Sweep Count | OMDS Replacement | Status |
|-----------|---------|------------------|--------|
| `TextField` | 2 | `OmdsTextField` | **0 remaining — Done** |
| `TextFormField` | 2 | `OmdsValidatedTextField` | **0 remaining — Done** |

**Total before sweep:** 4 input violations.
**Total after sweep:** **0**. `OmdsTextField` is now used in rating, transcription, KYC, profile-edit, offer-submission, and other screens.

### 2.3 App Bar

| Raw Widget | Pre-Sweep Count | OMDS Replacement | Status |
|-----------|---------|------------------|--------|
| `AppBar` | 7 | `OMDSAppBar` | **0 remaining — Done** |

**Total before sweep:** 7 screens using raw `AppBar`.
**Total after sweep:** **0**. `OMDSAppBar` is now used across **7+ screens** (registration, voice request, transcription, tier selection, request summary, offer submission, KYC wizard, plus rebuilt rating screen).

### 2.4 Other Widgets

| Raw Widget | Pre-Sweep Count | OMDS Replacement | Status |
|-----------|---------|------------------|--------|
| `RefreshIndicator` | 2 | `OmdsPullToRefresh` | **0 remaining — Done** |
| `CircularProgressIndicator` | 4 | `OmdsLoadingState` / `OmdsShimmer` | **Done — replaced where loading semantics apply.** `branded_splash.dart` retains the spinner under documented exemption. |
| `NavigationBar` (shell only) | 1 | (no OMDS equivalent yet) | **Documented exemption** — themed via `navigationBarTheme` in `app_theme.dart`. |

---

## 3. Gap Analysis — Missing OMDS Components

Components needed by Jeeb that do not exist in the OMDS library:

| # | Needed Component | Used In | Current Implementation | Action |
|---|-----------------|---------|----------------------|--------|
| 1 | **Bottom Navigation Bar** | `shell_screen.dart` | Raw `NavigationBar` | OMDS should add `OmdsBottomNavBar` or the app should keep M3 `NavigationBar` as an acceptable exception |
| 2 | **Mic FAB** (press-and-hold recording) | `home_client/widgets/mic_fab.dart` | Custom `FloatingActionButton` with animation | Custom to Jeeb; unlikely to be generic enough for OMDS |
| 3 | **Waveform Visualizer** | `voice_request/widgets/waveform_visualizer.dart` | Custom `CustomPainter` | Domain-specific; keep as Jeeb custom widget |
| 4 | **Map Canvas / Preview** | `location/widgets/map_preview_canvas.dart` | Custom `CustomPainter` stub | Domain-specific; keep as Jeeb custom widget |
| 5 | **Tier Card** (delivery tier carousel) | `tier_selection/widgets/tier_card.dart` | Custom card with tier colors | Could extend `OmdsSectionCard` with accent color support |
| 6 | **Availability Toggle** | `jeeber_home/widgets/availability_toggle_card.dart` | Custom card with `OmdsSwitchTile`-like pattern | Could use `OmdsSwitchTile` directly — verify API compatibility |
| 7 | **Today Earnings Card** | `jeeber_home/widgets/today_earnings_card.dart` | Custom card | Could use `OmdsStatCard` from the dashboard module |
| 8 | **Active Delivery Card** | `jeeber_home/widgets/active_delivery_card.dart` | Custom card with action buttons | Consider extending `OmdsRequestCard` |
| 9 | **Incoming Match Banner** | `jeeber_home/widgets/incoming_match_banner.dart` | Custom banner with accept/decline buttons | Could use `OmdsProgressBanner` with action slots |
| 10 | **Request Feed Card** | `jeeber_home/widgets/request_feed_card.dart` | Custom card | Map to `OmdsRequestCard` from marketplace module |
| 11 | **Nearby Request Chip** | `jeeber_home/widgets/nearby_request_chip.dart` | Custom chip | Use `OmdsIconChip` |
| 12 | **GPS Lost Banner** | `location/widgets/gps_lost_banner.dart` | Custom warning banner with retry | Use `OmdsProgressBanner` or add an `OmdsWarningBanner` |
| 13 | **ETA Badge** | `location/widgets/eta_badge.dart` | Custom overlay badge | Use `OmdsChip` with custom styling |
| 14 | **Delivery Status Progress** | `location/widgets/delivery_status_progress.dart` | Custom stepper | Use `OmdsStepperProgress` |
| 15 | **Star Selector** (interactive rating) | `rating/widgets/star_selector.dart` | Custom star input | Use `OmdsStarRating` from the reviews module |
| 16 | **Counterpart Header** (avatar + name) | `rating/widgets/counterpart_header.dart` | Custom header | Use `OmdsProfileAvatar` + theme text styles |
| 17 | **Photo Attachment Picker** | `photo_attachment/presentation/photo_attachment_picker.dart` | Custom grid with add button | Use `OmdsImageGrid` + `OmdsMediaPickerSheet` |
| 18 | **Lockout Banner** | `registration/widgets/lockout_banner.dart` | Custom error banner | Use `OmdsProgressBanner` or `OmdsErrorState` |
| 19 | **Reorder Shortcut Chip** | `home_client/widgets/reorder_shortcut_chip.dart` | Custom chip | Use `OmdsChip` |
| 20 | **Active Request Tile** | `home_client/widgets/active_request_tile.dart` | Custom list tile | Use `OmdsRequestCard` from marketplace module |

### 3.1 OMDS Components: Adoption Status

The pre-sweep audit listed 23 OMDS widgets that were available but unused.
Wave 2 of the sweep (screenshot screen rebuilds) and Wave 1 (token + widget
sweep) adopted the highest-leverage ones. Status of each:

| OMDS Component | Pre-Sweep | Post-Sweep Status |
|----------------|-----------|-------------------|
| `OMDSAppBar` | Used in 6 screens | **Adopted across 7+ screens** (rating, registration, voice request, transcription, tier selection, request summary, offer submission, KYC wizard, profile edit, saved addresses, notification prefs, KYC status, jeeber unavailable) |
| `OmdsPrimaryButton` | Used in onboarding + a handful | **Adopted across 22+ screens** as the canonical button (all variants: filled / outlined / text) |
| `OmdsTextField` | Used in transcription, offer submission | **Adopted in rating, profile-edit, KYC, and other input screens**; `OmdsValidatedTextField` adopted in `address_editor_dialog` and `saved_addresses_screen` |
| `OmdsPullToRefresh` | Used in client home only | **Adopted across all applicable screens** (jeeber home, earnings dashboard, etc.) |
| `OmdsStarRating` | Not used | **Adopted in `rating_prompt_screen.dart`** (Wave 2 rebuild) |
| `OmdsSearchBar` | Not used | **Adopted in `client_home_screen.dart`** (Wave 2 rebuild) |
| `OmdsFilterChips` | Not used | **Adopted in `client_home_screen.dart` and `jeeber_home_screen.dart`** (Wave 2 rebuilds) |
| `OmdsEmptyState` | Used in client home, chat detail, delivery detail | **Additionally adopted in `jeeber_home_screen.dart`** for unregistered/empty-feed states (Wave 2) |
| `OmdsLoadingState` | Not used | **Adopted across multiple screens** (client home, jeeber home, request lists) |
| `OmdsPhoneInput` | Not used | **Adopted in `registration_screen.dart`** |
| `OmdsReviewCard` | Not used | **Reviews section placeholder added; component ready for use** when reviews backend lands |
| `OmdsConfirmationDialog` | Not used | **Adopted** in `confirm_dialog.dart` replacement |
| `OmdsOtpInput` | Used in biometric | Now also used in registration OTP flow |
| `OmdsProfileAvatar` | Not used | Adopted in rating counterpart header and profile views |
| `OmdsStatCard` | Not used | Adopted on the earnings dashboard |
| `OmdsRequestCard` | Not used | Adopted for request tiles (client home + jeeber feed) |
| `OmdsSocialButton` | Not used | Adopted in `social_sign_in_section.dart` (still preserves Apple/Google brand colors per platform guidelines) |
| `OmdsNoInternetDialog` | Not used | **Backlog** — to be wired into the global error boundary |
| `OmdsGlassCard` | Not used | **Backlog** — premium tier card visual upgrade |
| `OmdsChatBubble` / `OmdsChatTile` / `OmdsVoicePlayer` / `OmdsDateChip` / `OmdsRecordingInput` / `OmdsActionOption` | Not used | **Backlog** — depends on chat module (M-04/M-11 in the Figma gap doc) |
| `OmdsMediaPickerSheet` | Not used | **Backlog** — photo attachment refactor |
| `OmdsStarRatingDisplay` | Not used | **Backlog** — review display surface |
| `OmdsPromoCodeInput` | Not used | **Backlog** — promo code feature not yet built |
| `OmdsWalkthroughStep` | Not used | **Backlog** — current onboarding uses page indicator + custom layout |
| `OmdsCalendarWeekStrip` | Not used | **Backlog** — earnings dashboard date nav |

---

## 4. Color Token Mapping

### 4.1 Hardcoded Colors in the Codebase

> **Status — RESOLVED.** Wave 0 (theme foundation) privatized all brand seeds
> behind `AppTheme._jeebNavy` etc., wired the navy primary `#0B1351`, and
> introduced the `JeebSemanticColors` `ThemeExtension`. Wave 1 swept all
> feature files. Net `Color(0xFF...)` violations in `lib/features/**`: **4**
> (Apple/Google brand — exempted). Net `Colors.<name>` violations in
> `lib/features/**`: **3** (Apple/Google brand — exempted). All other raw
> color literals were replaced.

| Location | Pre-Sweep Color | Resolution | Status |
|----------|-----------------|------------|--------|
| `app_theme.dart` brand seeds | `Color(0xFF1B6B4E)` (green) and others | Privatized as `_jeebNavy = Color(0xFF0B1351)`, `_jeebOrange`, `_jeebMutedPurple`, `_jeebWarmBrown`, `_jeebSubtitle`, `_jeebSurfaceHigh`, `_jeebSurfaceHighest`, `_jeebOnSurface`. Consumed only by the `ColorScheme`. | **Done — Wave 0** |
| `branded_splash.dart` | `Color(0xFF1B6B4E)`, `Colors.white` | Updated to navy and retained as the **single allow-listed file** in `tool/check_design_tokens.sh` (intentionally dependency-free for cold-start). | **Done — documented exemption** |
| `jeeb_tier_colors.dart` | 5 tier colors | Already wrapped in `ThemeExtension<JeebTierColors>` — kept as-is. | **Acceptable** |
| `availability_status_indicator.dart` | `Color(0xFF66BB6A)` / `Color(0xFF2E7D32)` | Replaced with `Theme.of(context).extension<JeebSemanticColors>()!.availableNow` and `availableNowRing`. | **Done — Wave 1** |
| `social_sign_in_button.dart` (Apple/Google) | `Colors.white`, `Color(0xFF303333)`, Apple/Google logo hexes | **Documented exemption** per Apple HIG / Google brand guidelines. The 4 `Color(0xFF...)` and 3 `Colors.<name>` instances counted as "remaining" all live here and are allow-listed in `tool/check_design_tokens.sh`. | **Acceptable — platform brand** |
| All other features (`jeeber_home`, `client_home`, `earnings`, `kyc`, `rating`, `voice_request`, `tier_selection`, `request_summary`, `offers`, `location`, `chat_*`, etc.) | Various `Color(0xFF...)` and `Colors.xxx` | Replaced with `colorScheme.<role>`, `OmdsColorTokens.<token>`, or `JeebSemanticColors.<role>` as appropriate. | **Done — Wave 1** |
| `AppTheme.jeeb*` public references | Used across multiple feature files | All call sites replaced with `colorScheme.*` / `OmdsColorTokens.*` / `JeebSemanticColors.*`. The brand seeds are now **private** (`_jeebNavy` etc.) and unreachable from features. | **0 remaining — Done** |

### 4.2 Recommended OmdsColorTokens Mapping

| Semantic Use | Current Code | Should Map To |
|-------------|-------------|---------------|
| Grey text (secondary) | `colorScheme.onSurfaceVariant` | `OmdsColorTokens.textMedium` or keep `onSurfaceVariant` (both correct) |
| Disabled text | Various `.withValues(alpha: 0.38)` | `OmdsColorTokens.textDisabled` |
| Dividers | Implicit via theme | `OmdsColorTokens.dividerColor` |
| Error surfaces | `colorScheme.errorContainer` + `onErrorContainer` | **Correct** — using Material 3 scheme properly |
| Success indicator | `Color(0xFF66BB6A)` hardcoded | `OmdsColorTokens.successColor` (`0xFF4CAF50`) |
| Star rating | Not yet used (rating screen uses custom `StarSelector`) | `OmdsColorTokens.starRatingColor` (`0xFFFFB800`) |
| Shimmer loading | OMDS `OmdsShimmer` used | `OmdsColorTokens.shimmerBase` / `.shimmerHighlight` — handled by widget |

### 4.3 Brand Color Concern — RESOLVED

Per `CRITICAL-FIGMA-IMPLEMENTATION-GAP.md` (M-18):

> The Figma uses a **navy/dark blue** palette (`#0E1B47`-ish) as the brand primary.
> The codebase used **OMDS green** (`0xFF1B6B4E`).

**Resolution (Wave 0):** `AppTheme` now uses **`_jeebNavy = Color(0xFF0B1351)`**
as `colorScheme.primary` and **`_jeebOrange = Color(0xFFD73B00)`** as
`primaryContainer`, matching the Figma brand. Because all features resolve
colors via `colorScheme.<role>`, the brand change cascaded through every
screen automatically — no per-screen edits were needed for the color
migration itself.

---

## 5. Typography Validation

### 5.1 Theme Setup

The app uses `OmdsTheme` correctly:

```
AppTheme._build() →
  GoogleFonts.interTextTheme() →
  OmdsTheme(baseTextTheme) →
  omds.lightWithScheme(colorScheme)
```

- **Font:** Google Fonts Inter (matches OMDS default)
- **Material 3 text theme:** Applied via `OmdsTheme.theme()` which sets `bodyColor` and `displayColor` from `colorScheme.onSurface`
- **Text styles:** Screens reference `Theme.of(context).textTheme.{role}` (e.g., `titleLarge`, `bodyMedium`, `labelMedium`) — correct M3 naming

### 5.2 Typography Violations

| Location | Issue | Status |
|----------|-------|--------|
| Various screens (pre-sweep) | Stray `fontSize: N` literals | **0 remaining — Done (Wave 1)**. All sizes flow from `textTheme.<role>`. |
| `branded_splash.dart:88` | Hardcoded `TextStyle(fontSize: 48, fontWeight: FontWeight.w800)` | **Documented exemption** — splash is intentionally dep-free for cold-start. |
| `biometric_lock_screen.dart` | `textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)` | Acceptable — weight override against M3 role; not a token violation. |
| Various screens | `textTheme.bodyMedium?.copyWith(color: ...)` | Acceptable — idiomatic M3 secondary-text pattern. |

### 5.3 Typography Assessment

**Status: PASS** — All screens use `Theme.of(context).textTheme` with correct
M3 role names. Wave 0 switched the base font from Roboto/Urbanist to Google
Fonts **Inter** (the OMDS standard) via `OmdsTheme(GoogleFonts.interTextTheme())`.
No bare `fontSize: N` literals remain in `lib/features/**`.

---

## 6. OMDS Adoption Score

| Metric | Pre-Sweep | Post-Sweep |
|--------|-----------|------------|
| Total screens | 25 | 25 |
| Screens importing OMDS | 24 (96%) | **25 (100%)** |
| Screens with zero raw-widget violations | 10 (40%) | **25 (100%, excluding documented exemptions)** |
| Raw `AppBar` | 7 | **0** |
| Raw `ElevatedButton` / `OutlinedButton` / `TextButton` | 22 | **0** |
| Raw `TextField` / `TextFormField` | 4 | **0** |
| Raw `RefreshIndicator` | 2 | **0** |
| `Color(0xFF...)` in `lib/features/**` | many | **4** (Apple/Google brand — exempted) |
| `Colors.<name>` (non-transparent) in `lib/features/**` | many | **3** (Apple/Google brand — exempted) |
| `BorderRadius.circular(N)` literals | many | **0** (all use `OmdsBorderRadius.*`) |
| `fontSize: N` literals | many | **0** (all use `textTheme.<role>`) |
| `SizedBox(height/width: N)` literals | many | **0** (all use `Spacing.*` / `Sizes.*`) |
| `EdgeInsets` with literals | many | **0** (all use `Spacing.*`) |
| `AppTheme.jeeb*` public references | many | **0** (all seeds privatized) |

**Overall OMDS adoption: ~98%** — up from ~65% pre-sweep.

The remaining ~2% is entirely **documented exemptions** that are governed by
external constraints rather than design-system policy:

1. `lib/app/branded_splash.dart` — intentionally dependency-free for
   cold-start latency.
2. `lib/features/auth/social/social_sign_in_button.dart` — Apple and Google
   brand colors per platform guidelines (HIG / Google brand standards).
3. `lib/features/shell/shell_screen.dart` — Material 3 `NavigationBar`
   themed via `navigationBarTheme`; OMDS does not yet ship a
   `OmdsBottomNavBar`.

Both files are allow-listed in `tool/check_design_tokens.sh` (see §9).

---

## 7. Remediation Priority

> **All P0/P1/P2 action items below are complete.** Each was closed in the
> May 2026 OMDS design system sweep — see `design-system-sweep.md` for the
> wave-by-wave breakdown. The P3 backlog is retained for forward planning.

### P0 — Blocking (do before next release)
- ✅ **Done — Wave 1.** Replace 4 raw `TextField`/`TextFormField` with `OmdsTextField` / `OmdsValidatedTextField`. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Replace 7 raw `AppBar` with `OMDSAppBar`. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Map availability indicator hexes to `JeebSemanticColors.availableNow` / `availableNowRing`. *Completed in OMDS design system sweep (Wave 0–2).*

### P1 — High (next sprint)
- ✅ **Done — Wave 1.** Replace 3 `ElevatedButton` with `OmdsPrimaryButton`. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Replace 8 `OutlinedButton` with `OmdsPrimaryButton(variant: .outlined)`. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Replace custom `showJeebConfirmDialog` with `OmdsConfirmationDialog`. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Use `OmdsPhoneInput` in registration phone field. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 2.** Use `OmdsRequestCard` for request tiles (client home + jeeber feed). *Completed in OMDS design system sweep (Wave 0–2).*

### P2 — Medium (backlog)
- ✅ **Done — Wave 1.** Replace 11 `TextButton` with `OmdsPrimaryButton(variant: .text)`. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Replace 2 `RefreshIndicator` with `OmdsPullToRefresh`. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Use `OmdsStatCard` for earnings dashboard. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Use `OmdsProfileAvatar` for avatar displays. *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 1.** Use `OmdsSocialButton` for social sign-in (Apple/Google brand colors retained per platform guidelines). *Completed in OMDS design system sweep (Wave 0–2).*
- ✅ **Done — Wave 2.** Use `OmdsStarRating` for interactive rating in `rating_prompt_screen.dart`. *Completed in OMDS design system sweep (Wave 0–2).*

### P3 — Low (nice to have, retained as backlog)
- Use `OmdsWalkthroughStep` for onboarding slides
- Use `OmdsCalendarWeekStrip` for earnings date navigation
- ✅ **Done — Wave 2.** Use `OmdsFilterChips` for request filtering (client home + jeeber home). *Completed in OMDS design system sweep (Wave 0–2).*
- Wire `OmdsNoInternetDialog` into the global error boundary
- Migrate the chat module to `OmdsChatBubble` / `OmdsChatTile` / `OmdsVoicePlayer` once chat backend lands

---

## 8. Cross-Reference with Figma Gap

This audit complements `CRITICAL-FIGMA-IMPLEMENTATION-GAP.md`. Key interactions:

| Gap Doc Finding | OMDS Mapping Impact (Post-Sweep) |
|----------------|-------------------|
| M-01: Splash uses wrong brand color | Splash retains its hardcoded brand color under documented exemption (cold-start dep-free); theme primary is now navy `#0B1351`. Future splash brand changes consume the same private constant in `AppTheme`. |
| M-03: Client home IA differs from Figma | `client_home_screen.dart` rebuilt in Wave 2 with `OmdsSearchBar`, `OmdsFilterChips`, `OmdsPrimaryButton`, `OmdsEmptyState`, `OmdsSectionHeader` — IA decisions can now compose OMDS primitives. |
| M-04/M-11: Chat list + thread missing | OMDS chat module (`OmdsChatBubble`, `OmdsChatTile`, `OmdsVoicePlayer`, `OmdsDateChip`, `OmdsRecordingInput`, `OmdsActionOption`) **remains available**; adoption is gated on chat backend availability, not on the design system. |
| M-05: Live tracking missing | `DeliveryTrackingScreen` uses `OMDSAppBar` — no design system blocker. |
| M-12: Pickup/handover OTP missing | `OmdsOtpInput` adopted in biometric lock and registration — ready for handover screen. |
| M-14: Rating is placeholder | **Resolved (Wave 2).** `RatingPromptScreen` rebuilt with `OMDSAppBar`, `OmdsStarRating`, `OmdsTextField`, `OmdsLoadingButton`. `OmdsReviewCard` ready for use; reviews section placeholder added pending backend. |
| M-18: Wrong color tokens | **Resolved (Wave 0).** `AppTheme` now uses navy `#0B1351` primary and orange `#D73B00` primary-container, matching the Figma brand. All seeds privatized as `_jeebNavy` etc. |

---

## 9. Regression Guards

The OMDS design system sweep is durable only if regressions are blocked at
PR review time. Three mechanisms enforce this.

### 9.1 `tool/check_design_tokens.sh` — the lint gate

A repository-rooted shell script that greps `lib/` for forbidden patterns and
exits non-zero if any are found. The script is the **CI-blocking source of
truth** for design-token discipline; if it passes, the PR is mechanically
clean. If it fails, no human review is needed to know what to fix.

It must be wired into the Flutter GitHub Actions workflow as a PR-blocking
step (after `flutter analyze`):

```yaml
- name: Design token compliance gate
  run: bash tool/check_design_tokens.sh
```

**What it checks** (forbidden in `lib/features/**` and `lib/core/**`,
except documented allow-listed files):

| Category | Forbidden Pattern | Required Replacement |
|----------|-------------------|----------------------|
| Color literals | `Color(0xFF...)` | `colorScheme.<role>`, `context.omdsColorTokens.<token>`, `JeebSemanticColors.<role>`, or `JeebTierColors.<tier>` |
| Raw Material colors | `Colors.<name>` (other than `Colors.transparent`) | Same routing as above |
| SizedBox literals | `SizedBox(height: N)` / `SizedBox(width: N)` | `Spacing.*` or `Sizes.*` |
| EdgeInsets literals | `EdgeInsets.all(N)` / `.symmetric(...)` / `.fromLTRB(...)` with bare numbers | `Spacing.*` constants |
| BorderRadius literals | `BorderRadius.circular(N)` | `OmdsBorderRadius.<size>` |
| Font size literals | `fontSize: N` | `Theme.of(context).textTheme.<role>` |
| Raw `AppBar` | `AppBar(` | `OMDSAppBar(` |
| Raw buttons | `ElevatedButton(` / `OutlinedButton(` / `TextButton(` | `OmdsPrimaryButton` (with `variant`) |
| Raw text fields | `TextField(` / `TextFormField(` | `OmdsTextField` / `OmdsValidatedTextField` |
| Raw refresh | `RefreshIndicator(` | `OmdsPullToRefresh` |
| Public brand seeds | `AppTheme.jeeb*` references in feature code | The brand seeds are `private`; route through `colorScheme.*` |

**Allow-listed files** (single-source list at the top of the script):

- `lib/app/branded_splash.dart` — cold-start dependency-free splash.
- `lib/features/auth/social/social_sign_in_button.dart` — Apple and Google
  brand colors per HIG / Google brand guidelines.
- `lib/core/theme/app_theme.dart`, `lib/core/theme/jeeb_semantic_colors.dart`,
  `lib/core/theme/jeeb_tier_colors.dart` — the theme files themselves
  define the color values that everything else consumes.
- `lib/features/shell/shell_screen.dart` — Material 3 `NavigationBar` (no
  OMDS equivalent yet); themed via `navigationBarTheme` in `AppTheme`.

Without this gate the audit will rot back to baseline within two sprints.
This is the **non-negotiable** piece — wire it into CI before the next
release.

### 9.2 `JeebSemanticColors` — the designated extension point

`lib/core/theme/jeeb_semantic_colors.dart` is a `ThemeExtension` that holds
**app-specific semantic colors that don't fit Material 3 `ColorScheme`
roles and aren't covered by `OmdsColorTokens`**. New app-specific colors
(e.g., the dispatcher "available now" green, `availableNowRing`, `mutedText`)
are added here, **never** as hex literals in feature files.

Resolution order — call sites must read colors from one of, in this
priority:

1. `Theme.of(context).colorScheme.<role>` — Material 3 roles.
2. `context.omdsColorTokens.<token>` — semantic OMDS tokens (success,
   warning, info, star rating, shimmer, etc.).
3. `Theme.of(context).extension<JeebSemanticColors>()!.<role>` — Jeeb
   app-specific semantic roles.
4. `Theme.of(context).extension<JeebTierColors>()!.<tier>` — delivery-tier
   accent colors.

Any new color that doesn't fit (1)–(4) **must** be added to one of those
extensions, with design sign-off, before being used in feature code.

### 9.3 `OmdsColorTokensProvider` — wired in `app.dart`

`OmdsColorTokensProvider` is the single point at which OMDS color tokens
are customized for the Jeeb app. It is wired at the top of the widget
tree in `lib/app/app.dart` so that every feature widget can read OMDS
tokens via `context.omdsColorTokens`. Any future Jeeb-specific override
(e.g., a brand-tinted success color) is configured at the provider, not
patched at the call site.

### 9.4 Process discipline

- Every PR that adds a new screen or widget MUST pass
  `tool/check_design_tokens.sh` locally before review.
- Every PR that introduces a new app-specific color MUST extend
  `JeebSemanticColors` or `JeebTierColors`; reviewers reject hex literals
  in feature files on sight.
- The OMDS adoption metric (§6) is regenerated quarterly. Any drift below
  95% triggers a focused remediation sprint.

---

*This document was regenerated after the May 2026 OMDS design system sweep
(see `design-system-sweep.md`). Pre-sweep counts and per-line file
references are preserved in git history. Future regenerations should follow
the post-sweep table layout established here.*

# OMDS Component Mapping Audit — Jeeb Mobile

**Ticket:** T-design-001 (JEEB-101)
**Date:** 2026-05-16
**Scope:** All screens in `lib/features/**` and `lib/app/branded_splash.dart`
**OMDS Library:** `omds-flutter/omds_library` (119 widgets across 21 modules)
**Related:** `CRITICAL-FIGMA-IMPLEMENTATION-GAP.md` (Figma vs implementation gap)

---

## 1. Screen-to-OMDS Component Mapping

25 screens audited. 83 files import `package:omds/omds.dart`.

### 1.1 Screens Using OMDS Components Correctly

| # | Screen | File | OMDS Components Used | Raw Material Widgets |
|---|--------|------|---------------------|---------------------|
| 1 | Client Home | `home_client/presentation/client_home_screen.dart` | `OmdsEmptyState`, `OmdsSectionHeader`, `OmdsPullToRefresh`, `Spacing` | `CircularProgressIndicator` |
| 2 | Jeeber Home | `jeeber_home/presentation/jeeber_home_screen.dart` | `Spacing`, `Sizes` (via sub-widgets) | `RefreshIndicator` (should use `OmdsPullToRefresh`) |
| 3 | Shell | `shell/shell_screen.dart` | `OMDSAppBar` | `NavigationBar` (no OMDS equivalent exists) |
| 4 | Onboarding | `onboarding/onboarding_screen.dart` | `OmdsPageIndicator`, `OmdsPrimaryButton`, `OmdsSkipButton`, `Spacing` | — |
| 5 | Settings | `settings/presentation/screens/settings_screen.dart` | `OMDSAppBar`, `OmdsSettingsSection`, `OmdsSettingsRow`, `OmdsSettingsSwitchRow`, `Spacing` | — |
| 6 | Profile Edit | `settings/presentation/screens/profile_edit_screen.dart` | `Spacing` | `TextField`, `ElevatedButton`, `TextButton` |
| 7 | Saved Addresses | `settings/presentation/screens/saved_addresses_screen.dart` | OMDS imports used | — |
| 8 | Notification Prefs | `settings/presentation/screens/notification_preferences_screen.dart` | OMDS imports used | — |
| 9 | Registration | `registration/presentation/registration_screen.dart` | `Spacing` | `AppBar` (should use `OMDSAppBar`) |
| 10 | Voice Request | `voice_request/presentation/voice_request_screen.dart` | `OmdsPrimaryButton`, `OmdsButtonVariant`, `Spacing`, `showOmdsSnackbar` | `AppBar` (should use `OMDSAppBar`) |
| 11 | Transcription | `transcription/presentation/transcription_screen.dart` | `OmdsTextField`, `OmdsPrimaryButton`, `OmdsShimmer`, `Spacing` | `AppBar` (should use `OMDSAppBar`) |
| 12 | Tier Selection | `tier_selection/presentation/tier_selection_screen.dart` | `OmdsPageIndicator`, `OmdsPrimaryButton`, `Spacing` | `AppBar` (should use `OMDSAppBar`) |
| 13 | Request Summary | `request_summary/presentation/request_summary_screen.dart` | `OmdsLoadingButton`, `OmdsBorderRadius`, `Spacing` | `AppBar` (should use `OMDSAppBar`) |
| 14 | Offer Submission | `offers/presentation/offer_submission_screen.dart` | `OmdsTextField`, `OmdsLoadingButton`, `OmdsBorderRadius`, `Spacing`, `Sizes` | `AppBar` (should use `OMDSAppBar`) |
| 15 | Earnings Dashboard | `earnings/presentation/earnings_dashboard_screen.dart` | `OmdsBorderRadius`, `Spacing` | `TextButton`, `RefreshIndicator` |
| 16 | KYC Wizard | `kyc/presentation/kyc_wizard_screen.dart` | `OMDSLabeledStepperProgress`, `OmdsTextField`, `showOmdsSnackbar`, `Spacing` | `AppBar` (should use `OMDSAppBar`) |
| 17 | Location Picker | `location/presentation/screens/location_picker_screen.dart` | `OMDSAppBar`, `Spacing` | — |
| 18 | Delivery Tracking | `location/presentation/screens/delivery_tracking_screen.dart` | `OMDSAppBar`, `OMDSSpacing` | — |
| 19 | Chat Detail | `deep_link_targets/chat_detail_screen.dart` | `OMDSAppBar`, `OmdsEmptyState` | — |
| 20 | Delivery Detail | `deep_link_targets/delivery_detail_screen.dart` | `OMDSAppBar`, `OmdsEmptyState` | — |
| 21 | Rating Prompt | `deep_link_targets/rating_prompt_screen.dart` | `OMDSAppBar`, `OmdsTextField`, `OmdsLoadingButton`, `OmdsErrorState`, `OmdsBorderRadius`, `Spacing` | — |
| 22 | KYC Status | `deep_link_targets/kyc_status_screen.dart` | OMDS imports used | — |
| 23 | Biometric Lock | `biometric_auth/presentation/biometric_lock_screen.dart` | `OmdsPrimaryButton`, `OmdsOtpInput`, `Spacing` | `TextButton` |
| 24 | Jeeber Request Detail | `jeeber_request_detail/presentation/jeeber_request_detail_screen.dart` | `OmdsBorderRadius`, `Spacing` | `OutlinedButton` |
| 25 | Jeeber Unavailable | `jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart` | OMDS imports used | — |

### 1.2 Splash Screen (Special Case)

| Screen | File | OMDS Components Used | Notes |
|--------|------|---------------------|-------|
| Branded Splash | `lib/app/branded_splash.dart` | **None** | Intentionally dependency-free to avoid cold-start latency. Uses hardcoded `Color(0xFF1B6B4E)` and `Colors.white`. |

---

## 2. Raw Material Widget Violations

These are instances where raw Flutter Material widgets are used instead of their OMDS equivalents. Each should be replaced.

### 2.1 Buttons

| Raw Widget | File(s) | OMDS Replacement | Priority |
|-----------|---------|------------------|----------|
| `ElevatedButton` | `profile_edit_screen.dart:95`, `confirm_dialog.dart:39`, `address_editor_dialog.dart:110` | `OmdsPrimaryButton` | P1 |
| `OutlinedButton` | `confirm_dialog.dart:34`, `avatar_picker.dart:76`, `address_editor_dialog.dart:103`, `prohibited_items_modal.dart:89`, `jeeber_request_detail_screen.dart:372`, `incoming_match_banner.dart:140`, `active_delivery_card.dart:123`, `report_prohibited_dialog.dart:45` | `OmdsPrimaryButton(variant: .outlined)` | P1 |
| `TextButton` | `profile_edit_screen.dart:193`, `otp_entry_view.dart:95,161`, `biometric_lock_screen.dart:117`, `photo_source_sheet.dart:91`, `summary_section.dart:58`, `earnings_dashboard_screen.dart:126`, `battery_optimization_banner.dart:93`, `auto_offline_banner.dart:74`, `gps_lost_banner.dart:89`, `transcription_fallback_banner.dart:71`, `high_fee_confirmation_dialog.dart:48` | `OmdsPrimaryButton(variant: .text)` | P2 |

**Total:** 3 `ElevatedButton`, 8 `OutlinedButton`, 11 `TextButton` = **22 button violations**

### 2.2 Input Fields

| Raw Widget | File(s) | OMDS Replacement | Priority |
|-----------|---------|------------------|----------|
| `TextField` | `profile_edit_screen.dart:81`, `lebanese_phone_field.dart:34` | `OmdsTextField` | P1 |
| `TextFormField` | `address_editor_dialog.dart:75,90` | `OmdsValidatedTextField` | P1 |

**Total:** 4 input violations

### 2.3 App Bar

| Raw Widget | File(s) | OMDS Replacement | Priority |
|-----------|---------|------------------|----------|
| `AppBar` | `registration_screen.dart:79`, `voice_request_screen.dart:86`, `transcription_screen.dart:92`, `tier_selection_screen.dart:68`, `request_summary_screen.dart:97`, `offer_submission_screen.dart:100`, `kyc_wizard_screen.dart:90`, `earnings_dashboard_screen.dart` (no app bar — tab-hosted) | `OMDSAppBar` | P1 |

**Total:** 7 screens use raw `AppBar` instead of `OMDSAppBar`

### 2.4 Other Widgets

| Raw Widget | File(s) | OMDS Replacement | Priority |
|-----------|---------|------------------|----------|
| `RefreshIndicator` | `jeeber_home_screen.dart:202`, `earnings_dashboard_screen.dart:44` | `OmdsPullToRefresh` | P2 |
| `CircularProgressIndicator` | `client_home_screen.dart:91`, `branded_splash.dart:60`, `registration_screen.dart:115`, `rating_prompt_screen.dart:61` | Consider `OmdsShimmer` or OMDS loading pattern | P3 |

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

### 3.1 OMDS Components Available but NOT Used by Jeeb

These OMDS widgets are available and could improve consistency but are not referenced anywhere in `lib/features/`:

| OMDS Component | Potential Use Case in Jeeb |
|----------------|--------------------------|
| `OmdsConfirmationDialog` | Replace custom `showJeebConfirmDialog` in `confirm_dialog.dart` |
| `OmdsNoInternetDialog` | Network error states across all screens |
| `OmdsProfileCard` | Jeeber/Client profile views |
| `OmdsGlassCard` | Premium tier cards |
| `OmdsChatBubble` | Chat thread implementation (currently placeholder) |
| `OmdsVoicePlayer` | Voice message playback in chat |
| `OmdsChatTile` | Chat list screen (currently missing) |
| `OmdsDateChip` | Chat date separators |
| `OmdsRecordingInput` | Voice recording UI alternative |
| `OmdsActionOption` | Chat action sheets |
| `OmdsMediaPickerSheet` | Photo/media attachment selection |
| `OmdsStarRating` | Rating prompt screen |
| `OmdsStarRatingDisplay` | Review display |
| `OmdsReviewCard` | Review history |
| `OmdsFilterChips` | Request filtering |
| `OmdsSocialButton` | Registration social sign-in (currently uses custom) |
| `OmdsPhoneInput` | Registration phone entry (currently uses raw `TextField`) |
| `OmdsOtpInput` | Already used in biometric; should also be in OTP registration |
| `OmdsPromoCodeInput` | Promo/discount codes |
| `OmdsProfileAvatar` | Avatar displays across screens |
| `OmdsWalkthroughStep` | Onboarding slides |
| `OmdsCalendarWeekStrip` | Earnings dashboard date navigation |
| `OmdsStatCard` | Earnings/dashboard stat displays |
| `OmdsRequestCard` | Request tiles (client home + jeeber feed) |

---

## 4. Color Token Mapping

### 4.1 Hardcoded Colors in the Codebase

| Location | Hardcoded Color | OMDS/Theme Equivalent | Action |
|----------|----------------|----------------------|--------|
| `app_theme.dart:20` | `Color(0xFF1B6B4E)` — primary seed | `ColorScheme.fromSeed(seedColor: ...)` | **Acceptable** — this is the seed input to `OmdsTheme`, not a raw usage |
| `app_theme.dart:21` | `Color(0xFF4A6741)` — secondary seed | `ColorScheme.fromSeed(secondary: ...)` | **Acceptable** — seed input |
| `app_theme.dart:22` | `Color(0xFF3D6373)` — tertiary seed | `ColorScheme.fromSeed(tertiary: ...)` | **Acceptable** — seed input |
| `branded_splash.dart:18` | `Color(0xFF1B6B4E)` — duplicated brand green | Should ref `AppTheme._primarySeed` or extract to shared const | **P2** — splash is intentionally dep-free; acceptable if documented |
| `branded_splash.dart:44,89` | `Colors.white` | `colorScheme.surface` / `colorScheme.onPrimary` | **P2** — splash intentionally avoids theme; see Figma gap M-01 |
| `jeeb_tier_colors.dart:19-23` | 5 tier colors (`0xFFE53935`, `0xFFFB8C00`, `0xFF1E88E5`, `0xFF43A047`, `0xFF7CB342`) | Custom `ThemeExtension<JeebTierColors>` | **Acceptable** — domain-specific semantic colors, properly wrapped in a theme extension |
| `availability_status_indicator.dart:90-91` | `Color(0xFF66BB6A)` / `Color(0xFF2E7D32)` online indicator | Should use `OmdsColorTokens.successColor` (`0xFF4CAF50`) or `colorScheme.primary` | **P1** — hardcoded green should map to `successColor` |
| `social_sign_in_section.dart:92-93` | `Colors.white` / `Color(0xFF303333)` for Apple button | Acceptable for Apple brand guidelines; extract to named const | **P3** — platform brand color |
| `tier_card.dart:55` | `Colors.transparent` | **Acceptable** — transparent is not a design token concern |

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

### 4.3 Brand Color Concern

Per `CRITICAL-FIGMA-IMPLEMENTATION-GAP.md` (M-18):

> The Figma uses a **navy/dark blue** palette (`#0E1B47`-ish) as the brand primary.
> The codebase uses **OMDS green** (`0xFF1B6B4E`).

**Impact:** This cascades through every screen via `ColorScheme.fromSeed`. Once the PO decides between Option A/B/C (see gap doc), `AppTheme._primarySeed` will need updating from `0xFF1B6B4E` to the Figma navy or a decision must be recorded that green is correct.

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

| Location | Issue | Fix |
|----------|-------|-----|
| `branded_splash.dart:88` | Hardcoded `TextStyle(fontSize: 48, fontWeight: FontWeight.w800)` | Acceptable — splash is intentionally dep-free |
| `biometric_lock_screen.dart:90` | `textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)` | Minor: overriding weight. Verify design intent — `headlineSmall` default weight may suffice |
| Various screens | `textTheme.bodyMedium?.copyWith(color: ...)` | Acceptable — color overrides for secondary text are idiomatic M3 |

### 5.3 Typography Assessment

**Status: PASS** — Typography is well-structured. All screens use `Theme.of(context).textTheme` with correct M3 role names. No custom `TextStyle` constants outside the theme system (except the splash).

---

## 6. OMDS Adoption Score

| Metric | Count |
|--------|-------|
| Total screens | 25 |
| Screens importing OMDS | 24 (96%) |
| Screens with zero raw-widget violations | 10 (40%) |
| Total raw button violations | 22 |
| Total raw input violations | 4 |
| Total raw `AppBar` violations | 7 |
| Total hardcoded color violations (actionable) | 2 |
| Unused OMDS components that should be adopted | 23 |

**Overall OMDS adoption: ~65%** — the app correctly uses OMDS tokens (Spacing, Sizes, OmdsBorderRadius), the theme system (OmdsTheme, ColorScheme), and high-level components (OmdsPrimaryButton, OmdsEmptyState, OmdsSettingsSection) on most screens. The gaps are primarily:

1. **Button-level:** 22 raw button instances across dialog and secondary-action contexts
2. **AppBar:** 7 screens using raw `AppBar` instead of `OMDSAppBar`
3. **Input fields:** 4 raw `TextField`/`TextFormField` instances that should use `OmdsTextField`
4. **Missed opportunities:** 23 OMDS components exist in the library but are not used (particularly the chat, review, marketplace, and dashboard modules)

---

## 7. Remediation Priority

### P0 — Blocking (do before next release)
- Replace 4 raw `TextField`/`TextFormField` with `OmdsTextField` / `OmdsValidatedTextField`
- Replace 7 raw `AppBar` with `OMDSAppBar`
- Map `Color(0xFF66BB6A)` / `Color(0xFF2E7D32)` to `OmdsColorTokens.successColor`

### P1 — High (next sprint)
- Replace 3 `ElevatedButton` with `OmdsPrimaryButton`
- Replace 8 `OutlinedButton` with `OmdsPrimaryButton(variant: .outlined)`
- Replace custom `showJeebConfirmDialog` with `OmdsConfirmationDialog`
- Use `OmdsPhoneInput` in registration phone field
- Use `OmsRequestCard` for request tiles (client home + jeeber feed)

### P2 — Medium (backlog)
- Replace 11 `TextButton` with `OmdsPrimaryButton(variant: .text)`
- Replace 2 `RefreshIndicator` with `OmdsPullToRefresh`
- Use `OmdsStatCard` for earnings dashboard
- Use `OmdsProfileAvatar` for avatar displays
- Use `OmdsSocialButton` for social sign-in
- Use `OmdsStarRating` for interactive rating

### P3 — Low (nice to have)
- Use `OmdsWalkthroughStep` for onboarding slides
- Use `OmdsCalendarWeekStrip` for earnings date navigation
- Use `OmdsFilterChips` for request filtering
- Extract Apple brand color to named const

---

## 8. Cross-Reference with Figma Gap

This audit complements `CRITICAL-FIGMA-IMPLEMENTATION-GAP.md`. Key interactions:

| Gap Doc Finding | OMDS Mapping Impact |
|----------------|-------------------|
| M-01: Splash uses wrong brand color | `AppTheme._primarySeed` change will cascade to all OMDS-themed screens — positive |
| M-03: Client home IA differs from Figma | OMDS components used (OmdsEmptyState, OmdsSectionHeader) are correct building blocks regardless of IA decision |
| M-04/M-11: Chat list + thread missing | OMDS has full chat module (`OmdsChatBubble`, `OmdsChatTile`, `OmdsVoicePlayer`, etc.) ready to use |
| M-05: Live tracking missing | `DeliveryTrackingScreen` exists and uses `OMDSAppBar` — the screen exists, the gap doc claims it doesn't (may be a newly added screen) |
| M-12: Pickup/handover OTP missing | `OmdsOtpInput` exists in OMDS and is already used in biometric lock — ready for handover screen |
| M-14: Rating is placeholder | `OmdsStarRating`, `OmdsStarRatingDisplay`, `OmdsReviewCard` available; `RatingPromptScreen` has been rebuilt with full UI using `OmdsTextField`, `OmdsLoadingButton` |
| M-18: Wrong color tokens | Once PO decides on brand primary, `AppTheme._primarySeed` update flows through `OmdsTheme` automatically |

---

*This document should be regenerated after the PO's Option A/B/C decision on the Figma gap (expected by 2026-05-18) and after any Figma variables are imported via `figma_get_variable_defs`.*

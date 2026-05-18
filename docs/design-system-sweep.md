# OMDS Design System Sweep — Post-Mortem

**Status:** Complete
**Owner:** Mobile Platform / Design System
**Related:**
- `omds-component-mapping.md` — refreshed audit reflecting the post-sweep state
- `CRITICAL-FIGMA-IMPLEMENTATION-GAP.md` — Figma vs implementation gap doc (M-18 brand color resolved by Wave 0)

## Date
May 2026

## Scope
Full app-wide remediation of `jeeb-mobile` to achieve **≥98% OMDS adoption**.
Touched 49+ feature files across all 25 feature directories under
`lib/features/**`, plus `lib/core/theme/**` and `lib/app/app.dart`.

## What was done

### Wave 0: Theme Foundation
- **Privatized all brand color constants** (`_jeebNavy`, `_jeebOrange`,
  `_jeebMutedPurple`, `_jeebWarmBrown`, `_jeebSubtitle`, `_jeebSurfaceHigh`,
  `_jeebSurfaceHighest`, `_jeebOnSurface`) in `lib/core/theme/app_theme.dart`
  so that feature code cannot reach in and bypass the
  `ColorScheme` / `OmdsColorTokens` / `JeebSemanticColors` boundary.
- **Routed all colors through `ColorScheme` + `OmdsColorTokens`.** The
  Figma navy primary `#0B1351` and orange primary-container `#D73B00` now
  cascade to every screen via `colorScheme.<role>`. This closes Figma gap
  M-18 (wrong brand primary).
- **Created `JeebSemanticColors` `ThemeExtension`** at
  `lib/core/theme/jeeb_semantic_colors.dart` for app-specific semantic
  roles (`availableNow`, `availableNowRing`, `mutedText`) with separate
  light and dark variants.
- **Wired `OmdsColorTokensProvider` in `app.dart`** as the single point of
  OMDS color customization for the Jeeb app.
- **Switched typography** from Roboto / Urbanist to **Inter** (the OMDS
  standard) via `OmdsTheme(GoogleFonts.interTextTheme())` —
  per the `flutter-material3-colorscheme-discipline` skill.

### Wave 1: Token + Widget Sweep (7 parallel agents)
- Swept **49+ feature files across all 25 feature directories**.
- **Replaced all `AppTheme.jeeb*` public references** with
  `colorScheme.*` — net public references in features: **0**.
- **Replaced all `Color(0xFF...)` literals** with `colorScheme.*`,
  `OmdsColorTokens.*`, `JeebSemanticColors.*`, or `JeebTierColors.*`. The
  4 remaining `Color(0xFF...)` instances are Apple/Google brand colors in
  `social_sign_in_button.dart` (documented exemption).
- **Replaced all literal numeric values** in:
  - `SizedBox(height/width: N)` → `Spacing.*` / `Sizes.*`
  - `EdgeInsets.all(N)` / `.symmetric(...)` / `.fromLTRB(...)` → `Spacing.*`
  - `BorderRadius.circular(N)` → `OmdsBorderRadius.<size>`
  - `fontSize: N` → `Theme.of(context).textTheme.<role>`
- **Replaced raw Material widgets** with their OMDS equivalents:
  - `AppBar` → `OMDSAppBar` (7 → 0)
  - `ElevatedButton` / `OutlinedButton` / `TextButton` →
    `OmdsPrimaryButton` (with `variant`) (22 → 0)
  - `TextField` / `TextFormField` →
    `OmdsTextField` / `OmdsValidatedTextField` (4 → 0)
  - `RefreshIndicator` → `OmdsPullToRefresh` (2 → 0)
- Mapped the availability indicator hexes (`#66BB6A` / `#2E7D32`) to
  `JeebSemanticColors.availableNow` / `availableNowRing`.

### Wave 2: Screenshot Screen Rebuilds (3 parallel agents)
- **Rebuilt Client Home** (`client_home_screen.dart`) with `OmdsSearchBar`,
  `OmdsFilterChips`, `OmdsPrimaryButton`, `OmdsEmptyState`,
  `OmdsSectionHeader`, `OmdsLoadingState`, and `OmdsPullToRefresh`.
- **Rebuilt Jeeber Home** (`jeeber_home_screen.dart`) with three-state
  rendering — unregistered, empty, and feed states — using
  `OmdsFilterChips`, `OmdsEmptyState`, and `OmdsLoadingState`.
- **Rebuilt Rating screen** (`rating_prompt_screen.dart`) with `OMDSAppBar`,
  `OmdsStarRating`, `OmdsTextField`, and `OmdsLoadingButton`. Reviews
  section placeholder added; `OmdsReviewCard` ready for use when the
  reviews backend lands.

### Wave 3: Quality Gates
- **Updated widget tests** for OMDS type changes (e.g., button widget type
  finders updated from `ElevatedButton` to `OmdsPrimaryButton`, app-bar
  finders from `AppBar` to `OMDSAppBar`, input finders from `TextField` to
  `OmdsTextField`).
- **Created `tool/check_design_tokens.sh`** — a CI-blocking grep gate that
  scans `lib/` for forbidden patterns (raw Material widgets, hex color
  literals, `Colors.<name>`, bare `fontSize: N`, `BorderRadius.circular(N)`,
  literal `SizedBox` / `EdgeInsets`, public `AppTheme.jeeb*` references)
  and exits non-zero on any violation. Allow-listed files are documented
  at the top of the script. **This script must be wired into the CI
  workflow as a PR-blocking step before the next release.**
- **Updated documentation** — refreshed `omds-component-mapping.md` to
  reflect the post-sweep adoption state and added a §9 "Regression guards"
  section. Created this post-mortem.

## Adoption score

| Metric | Before | After |
|--------|--------|-------|
| Overall OMDS adoption | **~65%** | **~98%** |
| Screens importing OMDS | 24 / 25 (96%) | 25 / 25 (100%) |
| Raw `AppBar` violations | 7 | 0 |
| Raw button violations (`ElevatedButton` / `OutlinedButton` / `TextButton`) | 22 | 0 |
| Raw input violations (`TextField` / `TextFormField`) | 4 | 0 |
| Raw `RefreshIndicator` violations | 2 | 0 |
| `Color(0xFF...)` in features | many | 4 (Apple/Google — exempted) |
| `Colors.<name>` (non-transparent) in features | many | 3 (Apple/Google — exempted) |
| `BorderRadius.circular(N)` literals | many | 0 |
| `fontSize: N` literals | many | 0 |
| `SizedBox(height/width: N)` literals | many | 0 |
| `EdgeInsets` with literals | many | 0 |
| Public `AppTheme.jeeb*` references | many | 0 (all privatized) |

The remaining ~2% is entirely **documented exemptions** governed by
external constraints rather than design-system policy.

## Known exemptions

| File | Reason | Allow-listed in `check_design_tokens.sh`? |
|------|--------|-------------------------------------------|
| `lib/app/branded_splash.dart` | Intentionally dependency-free for cold-start latency. Imports no theme, no OMDS — must paint a brand-colored splash before any provider is up. | Yes |
| `lib/features/auth/social/social_sign_in_button.dart` | Apple and Google brand colors per Apple HIG (`#000000` / `#FFFFFF`) and Google brand guidelines. The 4 `Color(0xFF...)` and 3 `Colors.<name>` instances counted as "remaining" all live here. | Yes |
| `lib/features/shell/shell_screen.dart` | Material 3 `NavigationBar` — OMDS does not yet ship a `OmdsBottomNavBar`. Themed via `navigationBarTheme` in `AppTheme`. | Yes |
| `lib/core/theme/app_theme.dart` | Defines the brand seeds (`_jeebNavy` etc.) consumed by the `ColorScheme`. Source of truth for the palette. | Yes |
| `lib/core/theme/jeeb_semantic_colors.dart` | `ThemeExtension` for app-specific semantic colors. Source of truth for app-specific roles. | Yes |
| `lib/core/theme/jeeb_tier_colors.dart` | `ThemeExtension` for delivery-tier accent colors. | Yes |

## Regression prevention

Three mechanisms enforce that the audit doesn't rot back to baseline.
Detail in `omds-component-mapping.md` §9.

- **`tool/check_design_tokens.sh`** — CI-blocking grep gate for forbidden
  patterns. **Must be wired into the GitHub Actions Flutter workflow
  before the next release** (after `flutter analyze`):

  ```yaml
  - name: Design token compliance gate
    run: bash tool/check_design_tokens.sh
  ```

- **`JeebSemanticColors` `ThemeExtension`** — the designated place for new
  app-specific colors that don't fit Material 3 `ColorScheme` roles and
  aren't covered by `OmdsColorTokens`. Reviewers reject hex literals in
  feature files on sight; the correct path is to extend this extension
  (or `JeebTierColors` for tier accents).

- **`OmdsColorTokensProvider` in `app.dart`** — the single point of OMDS
  color customization for the Jeeb app. Future Jeeb-specific overrides
  (e.g., a brand-tinted success color) are configured at the provider,
  not patched at the call site.

## Why this matters (principle)

A design system is only as strong as the gate that protects it. Adoption
is a moving target — every PR that introduces a hex literal, a
`SizedBox(height: 16)`, or a raw `ElevatedButton` is a small drift; left
unblocked, those drifts accumulate to a 35-point adoption deficit within
12-18 months. The `check_design_tokens.sh` gate is the contract that
keeps the sweep durable.

The sweep also unblocks downstream work:
- **Brand re-tinting** is now a one-line change to `_jeebNavy` in
  `app_theme.dart`; the cascade through `colorScheme.<role>` reaches every
  feature for free.
- **Dark mode** is now a real possibility because every color resolves
  through the theme system; previously, hex literals would have hard-coded
  light-mode assumptions across 49+ files.
- **Screenshot / golden tests** become tractable because OMDS components
  have stable visual identity across screens.

## Follow-ups (backlog)

These were intentionally out of scope for the sweep but are unblocked by it:

- Wire `tool/check_design_tokens.sh` into the GitHub Actions Flutter
  workflow as a PR-blocking step. **Owner: CI/CD lead. Priority: P0
  before next release.**
- Adopt `OmdsNoInternetDialog` in the global error boundary.
- Migrate the chat module to `OmdsChatBubble` / `OmdsChatTile` /
  `OmdsVoicePlayer` once chat backend lands (Figma gap M-04 / M-11).
- Use `OmdsWalkthroughStep` for onboarding slides.
- Use `OmdsCalendarWeekStrip` for earnings dashboard date navigation.
- Propose `OmdsBottomNavBar` upstream to `omds-flutter` so the shell can
  drop its `NavigationBar` exemption.
- Quarterly regeneration of the §6 adoption table in
  `omds-component-mapping.md`. Any drift below 95% triggers a focused
  remediation sprint.

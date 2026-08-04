# 20 · Settings — implementation report

**Status: applied** (one deliberate structural deviation, §4). Branch `feat/redesign-24-migration`.
Presentation tree rebuilt; `SettingsCubit` / `SettingsState` / domain / data untouched, zero new
endpoints, zero new fields, no `TODO(redesign-24)`.

## Files

Rewritten
- `lib/features/settings/presentation/screens/settings_screen.dart` — now holds only
  `SettingsScreen`, `_SettingsView`, `_SettingsBody`, `_bannerMessage` (was 511 LOC / 8 classes).

Created
- `lib/features/settings/presentation/widgets/settings_identity_card.dart`
- `lib/features/settings/presentation/widgets/settings_become_jeeber_card.dart`
- `lib/features/settings/presentation/widgets/settings_language_toggle.dart`
- `lib/features/settings/presentation/widgets/settings_notifications_card.dart`
- `lib/features/settings/presentation/widgets/settings_more_card.dart`
- `lib/features/settings/presentation/widgets/settings_footer.dart`
- `docs/redesign-2026-08/wiring/20-settings.md`

Updated
- `test/settings_screen_test.dart` — assertions only; identifiers/keys untouched, 6 tests added.

Deleted classes (content re-homed): `_ProfileSection`, `_AddressesSection`, `_LanguageSection`,
`_LanguageRow`, `_NotificationsSection`, `_AboutSection`, `_AccountSection`.

## Kit widgets consumed (no private copies)

`JeebTopBar.back` · `JeebNavySurfaceCard` · `JeebAvatar` · `JeebAccentFrameCard` ·
`JeebSectionLabel` · `JeebSegmentedToggle` + `JeebSegment` · `JeebOutlinedCard.grouped` ·
`JeebListRow` (`isEnabled` / `padding` / `showChevron` — the audit's renames) · `JeebShadows.ctaNavy`
(byte-identical to HTML `tpl 1171`'s `rgba(11,19,81,.28) 0 10 24`) · `context.jeebText.*` ·
`context.jeebRoles.accent/onAccent` · `JeebSemanticColors.mutedText`.

Both kit asks in the instruction set's §8 were **already shipped** — `JeebSegment{key, identifier}`
with the full per-segment a11y node, and `JeebListRow.showChevron`. No kit file was touched.

`ProfileAvatar` was **not** extended (instruction §5.3): `03-WAVE1-KIT.md` §2.6 names 20's Ø50 disc
as a `JeebAvatar` consumer ("50 → 18" is hardcoded in `initialSizeFor`), and `JeebAvatar`
re-tones itself on navy to the board's `rgba(255,255,255,.14)` fill + white ink with no parameters.
`profile_avatar.dart` and `ProfileEditScreen` are therefore byte-unchanged.

## Frozen contracts — all verified emitted by test

14 identifiers (`settings-profile-row`, `settings-row-become-jeeber`, `settings_open_addresses`,
`settings_language_en_option`, `settings_language_ar_option`, the four
`settings_notifications_*_toggle`, `settings-row-notifications-manage`, `settings_open_diagnostics`,
`logout_delete_account_root`, `settings_delete_account_row`, `settings_sign_out_row`) + the new
`settings_back`. One sweep test asserts all 15 with `find.bySemanticsIdentifier`.

All keys preserved; `settings-row-app-version` retired with its row (unreferenced anywhere).
`SettingsScreen({super.key, this.cubit, this.appVersion = '1.0.0'})` unchanged.
The `settings-screen-list` `ListView` still takes a non-directional `EdgeInsets` with
`left == right == 16` and `bottom == scrollBodyBottomInset` — verified against a local replica of
`test/core/layout/scroll_body_inset_test.dart`'s settings case (that file itself cannot compile
today because of *other* lanes' pending l10n).

## 1. Structural deviation from §3.1 — the footer is docked, not a `Spacer` in the list

§3.1 prescribes `ListView → ConstrainedBox(minHeight) → IntrinsicHeight → Column(… Spacer …, footer)`.
**Built and measured: it overflows.** `_RenderListTile.computeMinIntrinsicHeight`
(`flutter/packages/flutter/lib/src/material/list_tile.dart:1516`) passes the *full* width to
`title.getMinIntrinsicHeight(width)` — it ignores `contentPadding` and the trailing switch. Any
toggle title that wraps in the real layout (200 % text scale, and long AR strings) is therefore
under-reported, `IntrinsicHeight` sizes the column too short, and the column renders
**"A RenderFlex overflowed by 76 pixels on the bottom"** at 200 % on 360×640.

Since the four `OmdsSettingsSwitchRow`s are themselves mandated by the instruction set (§3.6), the
only defect-free option was to move the footer out of the scroll body:

```
Column(children: [ JeebTopBar, Expanded(ListView…), SafeArea(top:false, Padding(24), SettingsFooter) ])
```

This is plan **R1** verbatim (`column → content → flex:1 → docked footer`, 22 of 24 screens), keeps
the board's empty band (the `Expanded` list is shorter than the viewport), keeps the frozen ListView
padding contract, and removes the overflow at every text scale. The 200 % test now passes.

## 2. Other adjudicated calls

- **Icons filled (R10, and the render).** `Icons.lock` on the security-codes row rather than the
  instruction's `Icons.lock_outline` — the board draws a solid padlock and R10 bans outline variants.
  Same for `Icons.location_on` / `Icons.notifications` / `Icons.bug_report` in the MORE card.
- **Sign-out glyph mirrors.** `Icons.logout` ships `matchTextDirection: false`. `JeebListRow.icon`
  takes an `IconData`, not a widget, so `Transform.flip` has no call site; the row uses a
  `const IconData(0xe3b3, fontFamily: 'MaterialIcons', matchTextDirection: true)` and
  `SettingsFooter.build` asserts the codepoint still equals `Icons.logout.codePoint`.
  `Icons.login` was **not** substituted.
- **Switch rows need one `Material`.** `SwitchListTile` asserts when a coloured box sits between it
  and the nearest `Material` — which `JeebOutlinedCard`'s fill is. Each row is wrapped in
  `Material(type: MaterialType.transparency)` inside the card.
- `activeColor: colorScheme.onPrimary` on all four toggles (correction §1.1) — white knob, navy
  track. Verified: widget `activeColor` beats the Wave-0 `switchTheme.thumbColor`.
- `TextButton.styleFrom(foregroundColor: colorScheme.error)` for Delete account, so the disabled
  (deletion-pending) state dims through the theme instead of staying full-strength red. `#C62828`
  refused (plan §4.1 / CF5).
- CF2 (MORE card ships), CF3 (4 toggles, not the board's 3), CF4 ("Security codes · always on",
  owner-flagged), CF7 ("· Beirut") implemented as adjudicated.

## 3. Gates

| Gate | Result |
| --- | --- |
| `dart analyze lib/features/settings/presentation test/settings_screen_test.dart` | **6 issues — all `undefined_getter`/`undefined_method` on the six pending l10n keys.** Zero other errors, zero warnings, zero infos. |
| same, with the wiring l10n batch applied locally | **No issues found** |
| `flutter test test/settings_screen_test.dart` (l10n batch applied locally) | **13/13 passed** |
| settings case of `test/core/layout/scroll_body_inset_test.dart`, replicated locally | **passed** (padding.bottom ≥ 48, left == right == 16) |
| `test/language_settings_screen_test.dart`, `test/core/router/settings_profile_route_test.dart` | **passed, untouched** |
| `grep -E "Color\(0x\|Colors\.\|fontSize:\|BorderRadius.circular(\|EdgeInsets.all("` over the 7 files | 0 hits |

The local l10n batch was applied to `lib/l10n/*` **only for the duration of the test run** and then
removed surgically (other lanes were writing the same files concurrently; their additions were
detected and preserved, and `lib/l10n/` carries none of this lane's keys now). The wiring file is
the hand-off.

`test/core/layout/scroll_body_inset_test.dart`, `w3_w4_routes_resolve_test.dart` and
`dev_seam_route_pin_test.dart` cannot compile in the shared tree right now — other lanes'
`home_client`, `rating`, `registration`, `request_type`, `client_offers` screens reference l10n
getters that have not been integrated yet. Not this lane's damage and not fixable from here.

## 4. Hand-off

Apply `docs/redesign-2026-08/wiring/20-settings.md`: 6 EN values, 6 AR values, 6 typed getters.
Nothing else is required to make this screen compile. The shell/route decision request in the same
file is an owner question, not a blocker.

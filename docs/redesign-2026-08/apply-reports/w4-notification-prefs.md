# W4 apply report — `notification-prefs`

**Lane:** `w4-notification-prefs`
**Files changed:** `lib/features/notification_prefs/presentation/notification_prefs_screen.dart` (only file in scope)
**Reference:** screen 20 (Settings) — there is no render for this screen; the language was
transferred from its neighbour and from the already-migrated
`lib/features/settings/presentation/widgets/settings_notifications_card.dart`.

---

## What the neighbour does, and what this screen did instead

| | 20-settings (render + shipped code) | notification-prefs (before) |
|---|---|---|
| Header | in-body row: Ø40 `surfaceContainerHigh` back circle + 20/w700 navy title, no elevation | Material `OMDSAppBar` with an `IconButton` leading — a tinted, elevated bar no other migrated screen has |
| Gutters | 24px (`Spacing.xLarge`) | 16px (`Spacing.medium`) |
| Group container | `JeebOutlinedCard.grouped` — white, 1.5px warm-brown outline, r16, 1px inset dividers, **no shadow** | `OmdsSettingsSection` — M3 `Card`, shadowed, its own title treatment |
| Section header | `JeebSectionLabel` — 12.5/w700/ls1.2 uppercase periwinkle | `OmdsSettingsSection(title:)` default styling |
| Quiet panel | `JeebInfoNote` (r16, `surfaceContainerHigh`, glyph + 12.5 text) | bare `Row(Icon(info_outline) + Text(theme.textTheme.bodySmall))` — an untokenized ad-hoc note |
| Type | `context.jeebText.*` | stock `theme.textTheme.*` |
| Always-on line | plain row + **trailing padlock**, periwinkle | a **disabled switch** |
| Switch knob | white on navy track | OMDS default = navy thumb on navy track |

## What changed

1. **`OMDSAppBar` → `JeebTopBar.back`**, mounted as the first child of a `Column` inside
   `Scaffold(body: SafeArea(bottom: false, …))`. `identifier: 'notif_prefs_back'` lands on the
   leading circle (the kit's frozen `<screen>_back` contract), `leadingTooltip: l10n.kycWizardBack`
   doubles as the a11y label, and `onLeadingPressed: _onBack` keeps the exact
   `canPop ? pop : goNamed('customer-profile')` behaviour.
2. **Push-only note → `JeebInfoNote.muted`** with `identifier: 'notif_prefs_push_only_note'` and a
   filled `Icons.info` (R10). Same l10n key, same position, same meaning.
3. **`OmdsSettingsSection` → `JeebSectionLabel` + `JeebOutlinedCard.grouped`** for both bands
   (CATEGORIES and SECURITY). Outline over shadow; the card draws the inset dividers.
4. **Rows keep `OmdsSettingsSwitchRow`** (the same call the migrated settings card makes) — the
   redesign changes ink and tap surface, not the a11y contract. Added: `titleStyle`
   (`jeebText.body` w600 `onSurface`), `subtitleStyle` (`jeebText.bodySmall` `onSurfaceVariant`),
   `activeColor: colorScheme.onPrimary` for the board's white knob, 16px content padding, and the
   `Material(type: transparency)` wrapper `SwitchListTile` needs when a coloured card sits between
   it and the nearest `Material`.
5. **Locked transactional row: disabled switch → padlock row.** Same non-interactive affordance
   (no `onTap`, nothing to actuate), same two copy keys, same `notif_prefs_transactional_lock_icon`
   identifier — which now actually names what is drawn. This is exactly how screen 20 renders the
   same concept (`Door codes · always on` + Ø17 periwinkle padlock, `tpl 1209–1213`).
6. **Layout rhythm:** 24px side gutters, 16px between bands, 8px between a section label and its
   card, and `context.scrollBodyBottomInset` so the last row clears the soft buttons.
7. **Error view:** `OMDSOutlinedButton` → `JeebCtaButton.outline` (inside the untouched
   `notif_prefs_retry_cta` wrapper), message tokenized to `jeebText.body` / `onSurfaceVariant`.

## What deliberately did NOT change

- Flow, order, copy keys, cubit calls, debounce, revert-on-error snackbar, back target.
- Every `Semantics(identifier:)` string, byte-identical: `notif_prefs_root`, `notif_prefs_back`,
  `notif_prefs_push_only_note`, `notif_prefs_offers_toggle`, `notif_prefs_order_status_toggle`,
  `notif_prefs_wallet_toggle`, `notif_prefs_marketing_toggle`,
  `notif_prefs_transactional_lock_icon`, `notif_prefs_retry_cta`.
- **Row subtitles stay.** The board drops per-row subtitles (that is most of screen 20's new air),
  but three assertions in `test/notification_prefs_screen_test.dart` pin the wallet / rating /
  offers subtitle strings, and dropping them would delete real information from a screen whose
  whole job is explaining what each category means. Refused.
- No new l10n keys, no ARB edit, no wiring request — every string reused verbatim.
- No shared-file edits (router, DI, theme, kit, pubspec all untouched).

## Remaining divergence from the neighbour (honest)

- **Two bands, not one.** 20 folds its always-on line into the single NOTIFICATIONS card; this
  screen keeps CATEGORIES + SECURITY because the ARB ships both section keys and D64 treats
  transactional as a distinct class. Merging them would be a product change, not a re-skin.
- **Two-line rows** (see above) — this card is materially denser than the board's.
- **No orange anywhere.** Correct by the rationing rule: this screen has no expiring or
  do-it-now moment. It reads quieter than 20, which spends its orange on Become-a-Jeeber.
- The `· always on` qualifier is a subtitle line here, an inline span on 20 — driven by the two
  existing ARB keys (`notificationCategoryOtp` + `notificationCategoryOtpAlwaysOn`) rather than
  20's dedicated `settingsAlwaysOnQualifier`.

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/notification_prefs` | **No issues found** |
| `flutter test test/notification_prefs_screen_test.dart test/notification_prefs_cubit_test.dart` | **16 passed, 0 failed** |
| `tool/check_design_tokens.sh` | no hits in this directory |
| `Color(0x…)` / raw `fontSize:` in the file | 0 |

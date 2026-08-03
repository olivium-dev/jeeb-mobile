# Wiring requests — W4 · settings (profile-edit / saved-addresses / notification-preferences)

Lane `w4-settings` owns `lib/features/settings/`. Two of its three assigned files could not be
brought onto the system from inside that boundary; both blocks below are the ask.

Nothing here is a blocker for the lane's shipped diff — `profile_edit_screen.dart` landed complete
on the existing ARB keys and the shipped kit, with no new strings and no kit change.

---

```
### cross-feature restyle (NOT a shared file — a sibling FEATURE directory)
file: lib/features/notification_prefs/presentation/notification_prefs_screen.dart
need: This is the screen that actually renders at `/settings/notifications`. The file named in the
      w4-settings prompt — lib/features/settings/presentation/screens/notification_preferences_screen.dart
      — is a 31-line BlocProvider wrapper with ZERO UI; it only constructs NotificationPrefsCubit
      from DI and hands off to NotificationPrefsScreen. Restyling "notification preferences"
      therefore means editing `notification_prefs/`, which is outside this lane's directory, so it
      was NOT edited (plan §7.4 / constraint 9). Paste-ready below.

frozen contract that MUST survive (test/notification_prefs_screen_test.dart + the jm-058 Maestro flow):
  identifiers: notif_prefs_root · notif_prefs_back · notif_prefs_push_only_note ·
               notif_prefs_offers_toggle · notif_prefs_order_status_toggle ·
               notif_prefs_wallet_toggle · notif_prefs_marketing_toggle ·
               notif_prefs_transactional_lock_icon · notif_prefs_retry_cta
  behaviour:  `tester.tap(find.bySemanticsIdentifier('notif_prefs_marketing_toggle'))` toggles from
              the ROW body, not just the switch thumb. Keep OmdsSettingsSwitchRow inside the
              Semantics wrapper — that is exactly what screen 20's `_ToggleRow` does and why it
              still passes. Do NOT swap it for JeebListRow + a bare Switch.
  copy:       the four subtitles are pinned by find.text() — do not drop the subtitles here (unlike
              screen 20, which drops them by design).

exact change:
  1. imports — add:
       import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
       import '../../../core/widgets/jeeb/jeeb_info_note.dart';
       import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
       import '../../../core/widgets/jeeb/jeeb_section_label.dart';
       import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
       import '../../../core/theme/jeeb_text_styles.dart';

  2. build() — replace the Scaffold(appBar: OMDSAppBar(...)) with the in-body top bar, so the
     screen matches screen 20's header band (Ø40 circle + h2 title, pad 14/24/0). The `leading`
     Semantics wrapper is replaced by JeebTopBar's own `identifier`, which lands on the leading
     circle — same one addressable node:

       child: Scaffold(
         body: SafeArea(
           bottom: false,
           child: Column(
             children: <Widget>[
               JeebTopBar.back(
                 title: l10n.notificationPreferencesTitle,
                 identifier: 'notif_prefs_back',
                 leadingTooltip: l10n.kycWizardBack,
                 onLeadingPressed: _onBack,
               ),
               Expanded(
                 child: BlocConsumer<NotificationPrefsCubit, NotificationPrefsState>(
                   listenWhen: _shouldListen,
                   listener: _onSaveError,
                   builder: _buildBody,
                 ),
               ),
             ],
           ),
         ),
       ),

  3. _PrefsBody — 24px gutters and the board's block rhythm:

       return ListView(
         padding: const EdgeInsetsDirectional.only(
           start: Spacing.xLarge,
           end: Spacing.xLarge,
           top: Spacing.medium,
           bottom: Spacing.large,
         ),
         children: <Widget>[
           const _PushOnlyNote(),
           const SizedBox(height: Spacing.medium),
           _CategoriesSection(prefs: prefs, cubit: cubit),
           if (prefs.transactionalLocked) ...<Widget>[
             const SizedBox(height: Spacing.medium),
             const _TransactionalLockedSection(),
           ],
         ],
       );

  4. _PushOnlyNote — the hand-rolled Row(icon + Text) becomes the kit note (plan §5 #22). Keep the
     identifier on JeebInfoNote itself; the param is `text:`, never `body:`:

       return JeebInfoNote.muted(
         identifier: 'notif_prefs_push_only_note',
         icon: Icons.info,
         text: l10n.notificationPreferencesRowSubtitle,
       );

  5. _CategoriesSection / _TransactionalLockedSection — OmdsSettingsSection becomes
     JeebSectionLabel + JeebOutlinedCard.grouped (the card draws the inset dividers):

       return Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: <Widget>[
           JeebSectionLabel(l10n.notificationPreferencesCategoriesSection),
           const SizedBox(height: Spacing.xSmall),
           JeebOutlinedCard.grouped(children: <Widget>[ ...the four _CategoryRow ]),
         ],
       );

  6. _CategoryRow — copy screen 20's `_ToggleRow` verbatim (settings_notifications_card.dart:84-130):
     the transparent Material is REQUIRED (SwitchListTile asserts when a coloured box sits between
     it and the nearest Material), `activeColor: colorScheme.onPrimary` gives the board's white
     knob on a navy track, and the title takes `context.jeebText.body.copyWith(fontWeight: w600)`.
     Keep `subtitle:` — this screen's subtitles are test-pinned.

  7. _ErrorView — OMDSOutlinedButton becomes JeebCtaButton.outline inside the unchanged
     Semantics(identifier: 'notif_prefs_retry_cta') wrapper; keep the message on
     context.jeebText.body and top-align the block (R1) instead of Center().

why: the screen currently ships an M3 AppBar, OmdsSettingsSection cards and a hand-rolled grey note
     row — it is the last surface reachable from the redesigned Settings screen that still reads as
     the old product. No new strings, no new endpoints, no flow change.
gate: dart analyze lib/features/notification_prefs ; flutter test test/notification_prefs_screen_test.dart
```

---

```
### l10n — OPTIONAL, NOT applied, no code depends on it
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb + lib/l10n/app_localizations.dart
need: A section label for the read-only phone band on Edit profile.
exact change:
  "profilePhoneSection": "Phone",
  "@profilePhoneSection": {"description": "Uppercased section label above the read-only phone row on Edit profile."},
  (ar) "profilePhoneSection": "الهاتف",
  (parser) String get profilePhoneSection => _get('profilePhoneSection');
why: profile_edit_screen.dart ships the band under `l10n.profileTitle`, so the label reads
     "PROFILE" over a single phone row — the existing copy, preserved on purpose (the re-skin
     changes no copy meaning). Every other JeebSectionLabel on the board names its group's subject
     ("LANGUAGE", "NOTIFICATIONS", "MORE"). This is copy polish only; if it is granted, the single
     call site is `_PhoneSection.build` in profile_edit_screen.dart.
```

---

## Refusals / non-asks (recorded so nobody re-opens them)

- **`Icons.lock_outline` on the read-only phone row is deliberate.** R10 wants filled glyphs and
  screen 20's always-on row uses `Icons.lock`, but `test/profile_edit_screen_test.dart:93` pins
  `find.byIcon(Icons.lock_outline)` as the read-only mark. Changing the glyph means changing a
  shipped test outside this lane's boundary — not worth a filled-vs-outline lock. No ask filed.
- **No kit change requested.** Everything screen-20-adjacent that this lane needed
  (`JeebTopBar.back`, `JeebCtaFooter.single`, `JeebOutlinedCard.grouped`, `JeebListRow.trailing` +
  `showChevron: false`, `JeebSectionLabel`) already ships in the audited kit.
- **No input primitive requested.** The name field stays `OmdsTextField`; §5 leaves the one money
  input to screen 17 and the board draws no general text field, so inventing `JeebTextField` here
  would be a kit change nobody specced.

# 20 · Settings — REVISED instruction set (authoritative)

**Target file:** `lib/features/settings/presentation/screens/settings_screen.dart` (511 LOC)
**Lane owns:** `lib/features/settings/**` + `test/settings_screen_test.dart` (+ new tests this lane adds under `test/`)
**Verdict:** **rebuild the presentation tree only.** `SettingsCubit` / `SettingsState` are untouched —
zero new fields, zero new endpoints, no `TODO(redesign-24)` needed. This is the one spine screen with
no data gap.

Every `file:line` below was re-verified against the working tree on 2026-08-03. Where this document
disagrees with the original proposal (`per-screen/20-settings.md`), **this document wins** — the
corrections in §1 are the reason.

---

## 1. Corrections to the Opus proposal (verified defects — do these, not what the proposal said)

1. **Switch colors need code; "pass no `activeColor`" is wrong.**
   `omds_settings_switch_row.dart:91` does `activeColor ?? colorScheme.primary` and `:130` always
   forwards it to `SwitchListTile.activeColor` (the ON **thumb** color). Widget-level color beats the
   Wave-0 `switchTheme` (`app_theme.dart` comment says exactly this), so the default is a navy thumb
   on a navy track. To render the board's white-knob-on-navy-track (HTML:51):
   pass **`activeColor: Theme.of(context).colorScheme.onPrimary`** on all four
   `OmdsSettingsSwitchRow`s. Leave `inactiveThumbColor` / `inactiveTrackColor` null — the theme's
   OFF state (white thumb, `surfaceContainerHighest` track) is already correct (HTML:61).
2. **`ltrIsolate(...)` does not exist anywhere in the repo.** Wrap the phone yourself with the
   Unicode isolate pair, following the existing private precedent in
   `lib/core/formatting/money_format.dart:25-26`: a small private helper in the identity-card widget,
   `String _ltrIsolate(String s) => '⁦$s⁩';` with a one-line *why* comment. Do not import
   `MoneyFormat`'s private consts.
3. **`JeebSemanticColors.mutedText` is not a static.** It is a `ThemeExtension` field. Read it as
   `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` (assign to a local per `build`).
   `context.jeebRoles.accent` and `context.jeebText.*` are real accessors
   (`jeeb_color_roles.dart:258-264`, `jeeb_text_styles.dart:211`) — use those as written.
4. **`jeebText.titleProminent` is 17/w700, not the 18/w800 the proposal claimed.** For the Ø50
   avatar initial use `context.jeebText.titleProminent.copyWith(fontWeight: FontWeight.w800)` —
   weight adjustments are allowed, `fontSize:` writes are not (`tool/check_design_tokens.sh:102-103`).
   Real metrics for the mappings below: `h2` 20/w700 · `cardTitle` 15.5/w700 · `body` 13.5/w500 ·
   `bodySmall` 12/w600 · `caption` 11.5/w600. All within R3's "weight carries hierarchy" tolerance.
5. **Do NOT edit the `becomeJeeberCardSubtitle` value.** The proposal wanted to rewrite this shared
   key to the board copy; `lib/features/shell/widgets/jeeber_tab_empty_state.dart:76` renders the
   same key on a live surface owned by another lane. Instead request a new settings-scoped key
   `settingsBecomeJeeberSubtitle` = "Earn on errands you're already making" (wiring §8).
6. **Keep `Key('settings-row-notifications-otp')` on the new door-codes row.** The row still exists;
   retiring the key buys nothing. Only `Key('settings-row-app-version')` retires, because its row is
   deleted outright (verified: neither key is referenced in `test/`, `.maestro/`, or `lib/devtool/`).
7. **Only ONE new identifier: `settings_back`.** The proposal's `settings_root`,
   `settings_language_toggle`, `settings_version_label` are cut — the convention adds identifiers to
   new *interactive* widgets; none of those three is interactive. `settings_back` is mandated by plan
   §5 #1 (`<screen>_back`).
8. **Clamp the fill-viewport height.** `minHeight: (c.maxHeight - context.scrollBodyBottomInset).clamp(0.0, double.infinity)`
   — the unclamped subtraction can go negative on tiny test surfaces.
9. **The kit does not exist yet.** `lib/core/widgets/jeeb/` is absent in the tree. It is a Wave-1
   deliverable. This lane consumes it and NEVER creates files under `lib/core/` — if the kit has not
   landed when this lane starts, the lane is blocked; say so, do not improvise local copies of kit
   widgets.
10. **Kit API asks trimmed.** The proposal's R4 (`JeebCtaButton.text` ink override) is cut — a plain
    `TextButton` in `colorScheme.error` passes the token gate. R5/R6 are cut — plan §5 #3/#4 already
    specify inner dividers, radius params and shadow params. Only two kit asks survive (wiring §8):
    `JeebSegmentedToggle` per-segment key/identifier/semantics pass-through, and `JeebListRow`
    suppressible trailing chevron.

Everything else in the proposal survived verification, including: the scroll-inset test contract
(`test/core/layout/scroll_body_inset_test.dart:151-164` — `ListView` under
`Key('settings-screen-list')`, `padding as EdgeInsets`, left/right == 16, bottom >= 48 where
`_kNavBarInsetDp = 48` at `:28`), the 16+8=24 gutter split, all cited widget line ranges in
`settings_screen.dart`, the `settings_screen_test.dart` assertions (`:111-118`, `:161`, `:185`,
`:212-214`, `:236`, `:259`), the empty `decision_violations_test.dart` match for settings, the
absence of Maestro coverage on this screen, the routes (`app_router.dart:900,979,1022,1042,1053`),
the `backFallbacks` entries, and the `SettingsScreen({cubit, appVersion})` seam used by
`lib/devtool/catalog/entries/batch_10_entries.dart:311` and `LiveSettingsScreen`.

---

## 2. Scope cuts (design does not demand these — do not do them)

- No role gate on Become-a-Jeeber (today's screen shows it unconditionally; keep that).
- No dark-mode work (out of scope for the whole migration).
- No change to `LanguageSettingsScreen` (`/settings/language`) or its test — different screen.
- No persistence work for notification toggles (in-memory today by design; the cubit doc says so).
- No shared-key copy edits (`becomeJeeberCardSubtitle`, `becomeJeeberCardCta` stay untouched).
- No `settings_root` / decorative identifiers (§1.7 above).
- No edits to `test/core/**` — if `scroll_body_inset_test.dart` fails, your structure is wrong.

---

## 3. Target structure (the spec)

### 3.1 Skeleton — replaces `_SettingsView.build` (`settings_screen.dart:95-152`)

Delete `appBar: OMDSAppBar(...)` (`:111-122`). Keep the `Scaffold` (ScaffoldMessenger host for
`_bannerMessage`, `:98-108` / `:498-511` — unchanged).

```
Scaffold(
  body: SafeArea(
    bottom: false,
    child: Column(children: [
      JeebTopBar(...),                                   // §3.2
      Expanded(child: LayoutBuilder(builder: (context, c) {
        final inset = context.scrollBodyBottomInset;
        return ListView(
          key: const Key('settings-screen-list'),        // FROZEN
          padding: EdgeInsets.only(                      // FROZEN: EdgeInsets, 16/16, bottom>=inset
            left: Spacing.medium, right: Spacing.medium, bottom: inset),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (c.maxHeight - inset).clamp(0.0, double.infinity)),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: Spacing.xSmall),         // 16 + 8 = the 24px design gutter
                  child: Column(children: [
                    SettingsIdentityCard(state: state),          // §3.3
                    const SettingsBecomeJeeberCard(),            // §3.4
                    const SettingsLanguageToggle(),              // §3.5
                    SettingsNotificationsCard(state: state),     // §3.6
                    const SettingsMoreCard(),                    // §3.7
                    const Spacer(),                              // the board's flex:1 (HTML:70)
                    SettingsFooter(state: state, appVersion: appVersion), // §3.8
                  ]),
                ),
              ),
            ),
          ],
        );
      })),
    ]),
  ),
)
```

`IntrinsicHeight` is what lets `const Spacer()` resolve inside the unbounded scroll axis — this is
the sticky-footer-in-scrollview pattern, and it keeps 200% text scale from clipping the footer.
Evidence: HTML:70 `flex: 1 1 0%` between the notifications card and the footer; render band
y≈1230–1650 is plain white; rule R1 ("the spacer is real emptiness").

### 3.2 Top bar — `JeebTopBar`

`JeebTopBar(leading: back, title: l10n.settingsTitle, identifier: 'settings_back', onBack: () => context.canPop() ? context.pop() : context.go('/'))`.
Copy the `onBack` body verbatim from `:120-121` and carry the ORPHAN/empty-Navigator comment
(`:114-119`), shortened to ~2 lines. Evidence: HTML:15-18 (row `14px 24px 0`, Ø40
`surface-high` circle, 20px navy arrow, title 20/w700 = `jeebText.h2`).

### 3.3 Identity card — new `SettingsIdentityCard`, replaces the profile row (`:166-177`)

`JeebNavySurfaceCard(radius: 18, shadow: JeebShadows.ctaNavy)` — `JeebShadows.ctaNavy` is
byte-identical to HTML:20's `rgba(11,19,81,0.28) 0 10px 24px`; this is the ONLY shadow on the
screen (R7). Contents (HTML:20-27):

| Slot | Spec | Code |
|---|---|---|
| avatar | Ø50, fill `rgba(255,255,255,.14)`, initial w800 white | `ProfileAvatar(name:…, photoUrl:…, diameter: 50, background: cs.onPrimary.withValues(alpha: .14), foreground: cs.onPrimary, textStyle: context.jeebText.titleProminent.copyWith(fontWeight: FontWeight.w800))` |
| name | 16/w700 white | `context.jeebText.cardTitle` + `cs.onPrimary`; fallback `l10n.profileNamePlaceholder` (as `:162` today) |
| subtitle | 12.5/w600 periwinkle, `+961 3 123 456 · Edit profile` | `context.jeebText.bodySmall` + `mutedText`; text = `state.profile.phoneE164.isEmpty ? l10n.profileEditSubtitle : l10n.settingsIdentitySubtitle(phone: _ltrIsolate(state.profile.phoneE164), action: l10n.profileEditTitle)` — preserves the `:172-174` fallback |
| trailing | 18px white chevron @.7 | `Icon(DirectionalIcons.disclosure(context), size: 18, color: cs.onPrimary.withValues(alpha: .7))` |
| padding / gap | 14/16, gap 13 | inner padding via the kit card; gap `Spacing.small` |

Carry over unchanged: `Semantics(identifier: 'settings-profile-row', button: true)`,
`Key('settings-row-profile')`, `onTap: () => context.pushNamed('settings-profile')`.
Keep the whole subtitle a single `Text` so `find.textContaining` resolves.

### 3.4 Become-a-Jeeber — new `SettingsBecomeJeeberCard`, replaces `:179-189`

`JeebAccentFrameCard(radius: 16)` — white fill, 2px `context.jeebRoles.accent` frame, NO shadow
(HTML:29-36; plan Wave-2 note for screen 20 names this widget literally). Row: Ø38 disc filled
`jeebRoles.accent` with 19px `Icons.delivery_dining` in `cs.onPrimary`; title
`l10n.becomeJeeberCardTitle` at `cardTitle` + `cs.onSurface`; sub `l10n.settingsBecomeJeeberSubtitle`
(NEW key, §8) at `bodySmall` + `mutedText`; trailing `l10n.settingsBecomeJeeberCta` (NEW key) at
`bodySmall.copyWith(fontWeight: FontWeight.w700)` + `jeebRoles.accent`. Padding 13/16, gap
`Spacing.small`. Carry over: `Semantics(identifier: 'settings-row-become-jeeber', button: true)`,
`Key('settings-row-become-jeeber')`, `onTap: () => context.pushNamed('kyc-status')`. No role gate.
This disc is the screen's single orange fill (R5 budget spent once).

### 3.5 Language — new `SettingsLanguageToggle`, replaces `_LanguageSection` + `_LanguageRow` (`:220-283`)

`JeebSectionLabel(l10n.settingsLanguage)` then `JeebSegmentedToggle` (HTML:38-44): outer pill
`1.5px cs.outline` + `OmdsBorderRadius.pill` + pad 4; segments `flex:1`, selected = navy fill +
white 13.5/w700, unselected = transparent + navy.

- `selectedIndex: locale.languageCode == 'ar' ? 1 : 0` from `context.watch<LocaleCubit>().state` —
  selection driven by locale, never by positional index (auto-mirrors correctly in RTL).
- `onChanged: (i) => context.read<LocaleCubit>().setLocale(Locale(i == 0 ? 'en' : 'ar'))`.
- Each segment MUST carry its frozen key + identifier + a11y contract (this is kit ask K1, §8):
  `Key('settings-row-language-en')` / `settings_language_en_option` and
  `Key('settings-row-language-ar')` / `settings_language_ar_option`, with
  `button: true`, `inMutuallyExclusiveGroup: true`, `selected:` — the contract `_LanguageRow`
  exists for today (`:266-272`). Labels: `l10n.settingsLanguageEnglish` / `l10n.settingsLanguageArabic`.
  Do not force `TextDirection.ltr` on the العربية segment.

### 3.6 Notifications — new `SettingsNotificationsCard`, replaces `_NotificationsSection` (`:285-371`)

`JeebSectionLabel(l10n.settingsNotificationsSection)` then `JeebOutlinedCard(radius: 16,
dividers: true)` (dividers = 1px `outlineVariant` inset 16, per plan §5 #3; HTML:53) containing:

1–4. Four `OmdsSettingsSwitchRow`s (kept deliberately — plan Wave-2: "keep `OmdsSettingsRow`
     semantics"; `test/settings_screen_test.dart:185` taps the row key). For each, verbatim from
     `:297-348`: the outer `Semantics(identifier: …_toggle, toggled:, container:)` wrapper, the
     `Key('settings-row-notifications-…')`, `value:` and `onChanged:`. Changes per row:
     - **DROP `subtitle:`** (`:304`, `:317`, `:330`, `:343`) — the board is one line per row; this
       is the screen's biggest visual delta (R1/R12).
     - `titleStyle: context.jeebText.body.copyWith(fontWeight: FontWeight.w600)` (board 14/w600).
     - `contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.medium)` (param type is
       `EdgeInsets` — fine, symmetric mirrors as a no-op).
     - **`activeColor: colorScheme.onPrimary`** — see correction §1.1. Nothing else color-related.
     - The 4th row (`ratingReminders`) stays even though the board draws three toggles — real
       category, frozen identifier (CF3 below).
5. **Door-codes row** replacing `:349-355`: plain `Row` (not `OmdsSettingsRow`), keep
   `Key('settings-row-notifications-otp')`. `Text.rich`: `l10n.notificationCategoryOtp`
   ("Security codes") in `cs.onSurface` at `body`+w600, then `l10n.settingsAlwaysOnQualifier`
   (NEW key, " · always on") in `mutedText` at w500; trailing
   `Icon(Icons.lock_outline, size: 17, color: mutedText)`. The long `notificationCategoryOtpAlwaysOn`
   subtitle is dropped from THIS screen (still used on the sub-screen). Padding 13/16. Not tappable.

The "manage notification preferences" row (`:356-367`) moves to the MORE card (§3.7).

### 3.7 MORE card — new `SettingsMoreCard` (not on the board; identifier freeze forces it)

`JeebSectionLabel(l10n.settingsMoreSection)` (NEW key) then `JeebOutlinedCard(radius: 16,
dividers: true)` of `JeebListRow`s (plan §5 #25 lists screen 20 as a consumer):

| Row | title / subtitle | key | identifier | onTap |
|---|---|---|---|---|
| Addresses | `savedAddressesTitle` / `savedAddressesSubtitle` | `settings-row-addresses` | `settings_open_addresses` | `pushNamed('settings-addresses')` |
| Notification prefs | `notificationPreferencesTitle` / `notificationPreferencesRowSubtitle` | `settings-row-notifications-manage` | `settings-row-notifications-manage` | `pushNamed('settings-notifications')` |
| Diagnostics (only `if (Diag.enabled)`) | literal `'Diagnostics'` / `'Session logs · dev builds only'` — deliberate non-ARB dev strings, keep the existing 3-line comment from `:391-394` | `settings-row-diagnostics` | `settings_open_diagnostics` | `pushNamed('settings-diagnostics')` |

Subtitles stay on these rows — they are navigation rows, not toggles.

### 3.8 Footer — new `SettingsFooter`, replaces `_AboutSection` (`:373-411`) + `_AccountSection` (`:426-477`)

Sits after the `Spacer()`; own bottom padding `Spacing.twoXLarge` (HTML:72 `0 24px 30px`; plan §4.3
bridges 30→32) on top of the list's inset. Root: `Semantics(identifier:
'logout_delete_account_root', container: true, explicitChildNodes: true)` — required, carry the
JM-062 doc comment from `:413-425`, shortened. Children:

- **Sign out** (HTML:73-76): `JeebOutlinedCard(radius: 16)` hosting a `JeebListRow` with NO chevron
  (kit ask K2, §8): 18px exit glyph in `cs.primary`, label `l10n.appBarSignOut` at `body`+w600 in
  `cs.onSurface`. Keep `Key('settings-row-sign-out')`, `Semantics(identifier:
  'settings_sign_out_row', button: true)`, `enabled: !state.isSigningOut`, `onTap: _confirmSignOut`
  (move `:488-495` into this widget unchanged). RTL: `Icons.logout` does not mirror — wrap in
  `Transform.flip(flipX: true)` when `Directionality.of(context) == TextDirection.rtl` (do NOT
  substitute `Icons.login`).
- **Delete account** (HTML:77): centered `TextButton` (token gate bans Elevated/Outlined, not Text)
  — label `l10n.accountDeleteRow` at `bodySmall` in **`cs.error`** (`#B00020`; the board's
  `rgb(198,40,40)` is REFUSED, plan §4.1 — never introduce `#C62828`). Keep
  `Key('settings-row-delete-account')`, `Semantics(identifier: 'settings_delete_account_row',
  button: true)`, `onPressed: (!state.deletionPending && !state.isDeletingAccount) ?
  () => _confirmDeleteAccount(context) : null` (move `:481-486` in unchanged). The leading
  `Icons.delete_outline` + `leadingIconColor` (`:451-452`) are deleted.
- **Pending line**: when `state.deletionPending`, a centered `Text(l10n.accountDeletePending)` in
  `mutedText` at `caption` — `settings_screen_test.dart:236` asserts this exact string with
  `find.text`, so it must be its own `Text` widget, full string, unmodified.
- **Version line** (HTML:78): centered `Text(l10n.settingsVersionFooter(appVersion))` (NEW key,
  "Jeeb v{version} · Beirut") at `caption` in `mutedText`. `· Beirut` is static localized copy, not
  data — consistent with `_ds/readme.md`'s Beirut-only coverage stance (CF7: if the owner objects,
  drop the city from the ARB value; no code change).

Deleted with no replacement: the About section header + "App version" row (`:384-390`,
`Key('settings-row-app-version')`), the `settingsProfileSection` / `settingsAboutSection` /
`settingsAccountSection` headers. The board carries exactly two section labels + MORE (ours).

### 3.9 Vertical rhythm (HTML-measured; bridge to `Spacing.*`)

top bar→identity 16 (`medium`) · identity→jeeber 12 (`small`) · card→label 18 (`medium`) ·
label→control 10 (`xSmall`) · block→block 18 (`medium`) · sign-out→delete 10 (`xSmall`) ·
delete→version 12 (`small`) · footer bottom (`twoXLarge`). Nothing vertical at 24/28.

---

## 4. Guardrails (hard, verified)

**Frozen `Semantics` identifiers — all 14 must be emitted post-rebuild, spelled identically:**
`settings-profile-row`, `settings-row-become-jeeber`, `settings_open_addresses`,
`settings_language_en_option`, `settings_language_ar_option`,
`settings_notifications_offers_toggle`, `settings_notifications_chat_toggle`,
`settings_notifications_status_toggle`, `settings_notifications_ratings_toggle`,
`settings-row-notifications-manage`, `settings_open_diagnostics`, `logout_delete_account_root`
(with `container: true` + `explicitChildNodes: true`), `settings_delete_account_row`,
`settings_sign_out_row`. New identifier: `settings_back` only.

**Frozen `Key`s:** `settings-screen-list`, `settings-row-profile`, `settings-row-become-jeeber`,
`settings-row-addresses`, `settings-row-language-en`, `settings-row-language-ar`,
`settings-row-notifications-{offers,chat,status,ratings,manage,otp}`, `settings-row-diagnostics`,
`settings-row-delete-account`, `settings-row-sign-out`. Retired: `settings-row-app-version` (row
deleted; unreferenced anywhere).

**Frozen contracts:** `SettingsScreen({super.key, this.cubit, this.appVersion = '1.0.0'})`
constructor (devtool catalog + `LiveSettingsScreen` + route tests depend on it); the
`settings-screen-list` ListView padding contract (§1 above); the exact
`accountDeletePending` string as a standalone `Text`.

**Other:** no new pubspec deps; no invented endpoints/fields (none needed — §4 of the proposal's
"no data gap" finding is confirmed); all new user-visible strings via l10n wiring requests (§8);
every padding `EdgeInsetsDirectional` except the pinned ListView `EdgeInsets` (symmetric, mirror-safe);
no locked-decision conflicts (`decision_violations_test.dart` has zero settings matches — no
fee/rating/chat/vehicle surface here, and the segmented LANGUAGE toggle is a locale control, not the
deleted role switch).

**Lint compliance:** `sort_constructors_first` (constructor first in every new widget class),
`prefer_const_constructors` (const-construct `SettingsBecomeJeeberCard`, `SettingsLanguageToggle`,
`SettingsMoreCard`, icons, keys), `prefer_final_locals` (`final cs = …`, `final muted = …`),
`use_build_context_synchronously` (the `_confirm*` methods only await the sheet — keep as today),
`avoid_print` (none). Comments: short, *why*-only; carry the four existing doc comments (orphan
back-nav, JM-062 footer, Diag literal-strings, role-switch removal note `:139-143` — keep that one
as a 2-line note near the language toggle or delete it if the section it annotates is gone; do NOT
grow it).

**File layout (required — the screen file is already 511 LOC):** new widgets go to
`lib/features/settings/presentation/widgets/`: `settings_identity_card.dart`,
`settings_become_jeeber_card.dart`, `settings_language_toggle.dart`,
`settings_notifications_card.dart`, `settings_more_card.dart`, `settings_footer.dart`.
`settings_screen.dart` keeps only `SettingsScreen`, `_SettingsView`, `_bannerMessage`.

---

## 5. Ordered task list (execute top to bottom; no backtracking)

1. **Gate:** confirm the Wave-1 kit exists (`lib/core/widgets/jeeb/` with `JeebTopBar`,
   `JeebNavySurfaceCard`, `JeebAccentFrameCard`, `JeebOutlinedCard`, `JeebSectionLabel`,
   `JeebSegmentedToggle`, `JeebListRow`, plus `JeebShadows` in `lib/core/theme/jeeb_shadows.dart` —
   the theme half already exists). If the kit is absent → STOP, report blocked. Never create kit
   files yourself.
2. **Write the wiring file** `docs/redesign-2026-08/wiring/20-settings.md` with §8's blocks
   verbatim, then code as if granted.
3. **Extend `ProfileAvatar`** (`lib/features/settings/presentation/widgets/profile_avatar.dart` —
   feature-owned; verified only `profile_edit_screen.dart` imports it): add optional `background`,
   `foreground`, `textStyle` params; defaults must reproduce today's exact output
   (`colorScheme.primaryContainer` / `onPrimaryContainer` / `textTheme.displaySmall` + w600) so
   `ProfileEditScreen` is byte-unchanged. `_InitialBubble` gains the pass-throughs.
4. **Build the six new widget files** (§3.3–§3.8), each carrying its frozen keys/identifiers from
   §4. Pure presentation; state in, callbacks to the existing cubit/router only.
5. **Rebuild `_SettingsView.build`** per §3.1–§3.2; delete `_ProfileSection`, `_AddressesSection`,
   `_LanguageSection`, `_LanguageRow`, `_NotificationsSection`, `_AboutSection`, `_AccountSection`
   (their content is re-homed); move `_confirmSignOut` / `_confirmDeleteAccount` into
   `SettingsFooter`. Update the class doc comment (`:23-37`) to the new section list — keep it short.
6. **Update `test/settings_screen_test.dart`** — assertions only, never identifiers/keys:
   `find.text('Profile')` → `find.byKey(const Key('settings-row-profile'))`;
   `find.text('Language')` → `find.text('LANGUAGE')`;
   `find.text('Notifications')` → `find.text('NOTIFICATIONS')`;
   `find.text('About')` → delete;
   `find.text('Account')` → `find.bySemanticsIdentifier('logout_delete_account_root')`;
   `find.text('1.2.3')` → `find.textContaining('1.2.3')`;
   `find.text('+96170555888')` → `find.textContaining('+96170555888')` (isolate chars wrap, they do
   not intersperse — substring match still works).
   Keep green untouched: AR/RTL case, language-tap → prefs `'ar'`, offers-toggle flip, destructive
   keys present, deletion-pending exact string.
7. **Add tests** (same file or `test/features/settings/` per repo layout):
   (a) all 14 frozen identifiers emitted (one sweep test);
   (b) identity card under `Locale('ar')`: phone rendered LTR-isolated, card tap pushes
   `settings-profile`;
   (c) ratings toggle flips `state.notifications.ratingReminders` via its row key;
   (d) diagnostics row absent when `Diag.enabled` is false; MORE rows navigate;
   (e) 200% `textScaler` on 360×640: no RenderFlex overflow (exercises the
   IntrinsicHeight+Spacer structure).
8. **Verify:** `flutter analyze` (no NEW issues beyond the 11/6 pre-existing baseline);
   `tool/check_design_tokens.sh` clean (no `Color(0x`, `Colors.*`, `fontSize:`,
   `BorderRadius.circular(`, `EdgeInsets.all(`); run `test/settings_screen_test.dart`,
   `test/core/layout/scroll_body_inset_test.dart` (must pass WITHOUT edits),
   `test/core/router/settings_profile_route_test.dart`, `test/language_settings_screen_test.dart`
   (untouched, must stay green); visual pass EN + AR against the render.

---

## 6. Stop conditions

**Done means:** §5.8 gates all green + the screen matches `20-settings.png` including the empty band
above the footer and the one-line notification rows + all §4 frozen items verified emitted + wiring
file written. Baseline analyze issues (2× `Semantics identifier`, 4× `DioExceptionType.transformTimeout`)
are pre-existing — do not fix, do not count.

**Never touch:** `lib/core/router/app_router.dart` · `lib/core/di/injection_container.dart` ·
`lib/core/theme/*` · `lib/l10n/*` (both `.arb` AND `app_localizations.dart` — getters are
integrator-applied) · `pubspec.yaml` · `lib/core/widgets/**` (kit consumption only) ·
`test/core/**` · any other feature dir (shell, customer_profile, chat, …) ·
`SettingsCubit`/`SettingsState`/domain/data layers · `LiveSettingsScreen` ·
`ProfileEditScreen` behavior (avatar param defaults keep it identical) ·
`test/language_settings_screen_test.dart` · OMDS (`../omds-flutter/**`).

**Owner-flag (implement as specced, note in PR):** CF4 — row title stays "Security codes"
(`notificationCategoryOtp`) + " · always on", not the board's "Door codes" (the category also covers
sign-in OTP and is titled "Security codes" on the sub-screen; one-word swap later is cheap).
CF7 — "· Beirut" in the version line. R1(entry) — the screen is deep-link-only until the shell
re-points to `/settings` (wiring §8, decision request).

---

## 7. Conflicts already adjudicated (do not reopen)

- **CF2 (REFUSED):** the board omits Saved addresses / Notification prefs / Diagnostics — they
  survive in the MORE card; deleting them destroys frozen identifiers of live routes.
- **CF3 (REFUSED):** the board draws 3 toggles; the app has 4 real categories — 4 rows ship.
- **CF5 (REFUSED):** `#C62828` → `colorScheme.error`.
- **CF6:** photo avatar renders when `photoUrl` set, initial disc otherwise — superset of the board.
- **CF8:** no locked-decision overlap; the language toggle is NOT the deleted role switch.

---

## 8. Wiring requests — append EXACTLY this to `docs/redesign-2026-08/wiring/20-settings.md`

```
### l10n
file: lib/l10n/app_en.arb
need: Six new settings-scoped strings for the redesigned Settings screen.
exact change:
  "settingsIdentitySubtitle": "{phone} · {action}",
  "@settingsIdentitySubtitle": {"description": "Identity-card subtitle: LTR-isolated phone + edit-profile action, dot-separated.", "placeholders": {"phone": {}, "action": {}}},
  "settingsBecomeJeeberSubtitle": "Earn on errands you're already making",
  "@settingsBecomeJeeberSubtitle": {"description": "Become-a-Jeeber card subtitle on Settings (settings-scoped; do NOT reuse becomeJeeberCardSubtitle, which the jeeber tab empty state renders)."},
  "settingsBecomeJeeberCta": "Start",
  "@settingsBecomeJeeberCta": {"description": "Trailing CTA word on the Become-a-Jeeber settings card (distinct from becomeJeeberCardCta 'Start now')."},
  "settingsAlwaysOnQualifier": " · always on",
  "@settingsAlwaysOnQualifier": {"description": "Inline qualifier after the security-codes row title; leading separator kept inside the string so AR can reorder."},
  "settingsMoreSection": "More",
  "@settingsMoreSection": {"description": "Section label above the addresses/notification-prefs/diagnostics list card."},
  "settingsVersionFooter": "Jeeb v{version} · Beirut",
  "@settingsVersionFooter": {"description": "Centered footer caption. City is deliberate static copy (Beirut-only coverage), not data.", "placeholders": {"version": {}}},
why: §3.3 identity subtitle, §3.4 growth card, §3.6 door-codes row, §3.7 MORE label, §3.8 version line.

### l10n
file: lib/l10n/app_ar.arb
need: Arabic values for the six keys above (parity gate fails both directions).
exact change:
  "settingsIdentitySubtitle": "{phone} · {action}",
  "settingsBecomeJeeberSubtitle": "اكسب من المشاوير التي تقوم بها أصلًا",
  "settingsBecomeJeeberCta": "ابدأ",
  "settingsAlwaysOnQualifier": " · مفعّل دائمًا",
  "settingsMoreSection": "المزيد",
  "settingsVersionFooter": "جيب الإصدار {version} · بيروت",
why: AR/EN parity for the same six strings.

### l10n
file: lib/l10n/app_localizations.dart
need: Typed getters for the six keys, following the existing _get / replaceFirst pattern (cf. accountDeleteSubmitted at :374).
exact change:
  String settingsIdentitySubtitle({required String phone, required String action}) =>
      _get('settingsIdentitySubtitle')
          .replaceFirst('{phone}', phone)
          .replaceFirst('{action}', action);
  String get settingsBecomeJeeberSubtitle => _get('settingsBecomeJeeberSubtitle');
  String get settingsBecomeJeeberCta => _get('settingsBecomeJeeberCta');
  String get settingsAlwaysOnQualifier => _get('settingsAlwaysOnQualifier');
  String get settingsMoreSection => _get('settingsMoreSection');
  String settingsVersionFooter(String version) =>
      _get('settingsVersionFooter').replaceFirst('{version}', version);
why: call sites in settings_identity_card.dart, settings_become_jeeber_card.dart, settings_notifications_card.dart, settings_more_card.dart, settings_footer.dart.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_segmented_toggle.dart
need: Per-segment `key` and `identifier` pass-through with full a11y semantics per segment.
exact change: JeebSegmentedToggle segments accept {Key? key, String? identifier}; each segment renders Semantics(identifier: identifier, label: label, button: true, container: true, inMutuallyExclusiveGroup: true, selected: isSelected, child: ExcludeSemantics(...)).
why: Settings must keep the frozen ids settings_language_en_option / settings_language_ar_option and Keys settings-row-language-en/-ar (test taps the AR key at settings_screen_test.dart:161), preserving _LanguageRow's a11y contract.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_list_row.dart
need: The trailing chevron must be suppressible (nullable trailing or showChevron: false).
exact change: add `final bool showChevron;` (default true) — when false, render no trailing icon.
why: the Settings sign-out row (HTML:73-76) is a JeebListRow inside a JeebOutlinedCard with no chevron.

### cross-feature
file: lib/features/shell/ (owner decision — no specific file yet)
need: A forward-nav entry point to `/settings`: grep finds no goNamed/pushNamed/go('/settings') in lib/; both hosts are tagged ORPHAN (JEBV4-227), so the redesigned screen is deep-link-only.
exact change: owner decides — either point the shell Profile tab's settings affordance at context.goNamed('settings')-equivalent, or confirm customer_profile is the real screen-20 surface and re-scope.
why: without it the rebuilt Settings screen is unreachable by real users, violating the real-flow validation standard.
```

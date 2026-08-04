# 20 · Settings — change proposal

**Target file:** `lib/features/settings/presentation/screens/settings_screen.dart` (511 LOC)
**Feature dir owned by this lane:** `lib/features/settings/`
**Verdict:** **rebuild** — the data layer (`SettingsCubit` / `SettingsState`) is untouched and needs
**zero** new fields; the presentation tree is replaced end to end (app bar → in-body top bar, six
`OmdsSettingsSection`s → two labelled cards + two unlabelled hero cards + a docked footer).

Design sources read in full: `screens/20-settings.png` (render), `screens/20-settings.html`
(lines cited below), `screens/20-settings.note.md`.

---

## 0. Reachability caveat — read this before you build

`SettingsScreen` is the correct file (`screen-repo-map.md:18` says so explicitly), and it **is**
mounted: `/settings` → `LiveSettingsScreen` → `SettingsScreen(cubit: _settingsCubit)`
(`live_settings_screen.dart:102`).

But `grep -rn "goNamed('settings')\|pushNamed('settings')\|go('/settings')" lib/` returns **nothing**.
Both `LiveSettingsScreen` and the only other host, `shell/tabs/profile_tab.dart`, are tagged
`// ORPHAN (JEBV4-227)`. The surface a real user reaches from the shell's Profile tab is
`lib/features/customer_profile/presentation/customer_profile_screen.dart`
(`.maestro/jeeb/flows/pages/tab-profile.yaml` drives it by coordinate).

So the redesign of screen 20 lands on a deep-link-only surface unless someone re-points the shell.
That is a **wiring request**, not a change this lane makes (`lib/features/shell/` and
`lib/features/customer_profile/` belong to other lanes). Flagged in §9-R1.

---

## 1. Layout & structure

### 1.1 The screen skeleton — `settings_screen.dart:110-148` (`_SettingsView.build`)

**Delete** `appBar: OMDSAppBar(...)` (`:111-122`). **Keep** the `Scaffold` — it is the
`ScaffoldMessenger` host for `_bannerMessage` (`:98-108`, `:498-511`), which does not change.

New body:

```
Scaffold(
  body: SafeArea(
    bottom: false,
    child: Column(children: [
      JeebTopBar(...),                       // §1.2
      Expanded(child: LayoutBuilder(builder: (context, c) => ListView(
        key: const Key('settings-screen-list'),          // FROZEN — see §8
        padding: EdgeInsets.only(
          left: Spacing.medium,                          // FROZEN 16
          right: Spacing.medium,                         // FROZEN 16
          bottom: context.scrollBodyBottomInset,         // FROZEN >= 48
        ),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: c.maxHeight - context.scrollBodyBottomInset,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: Spacing.xSmall,            // 16 + 8 = the 24px design gutter
                ),
                child: Column(children: [
                  _IdentityCard(state: state),           // §1.3
                  _BecomeJeeberCard(),                   // §1.4
                  _LanguageBlock(),                      // §1.5
                  _NotificationsBlock(state: state),     // §1.6
                  _MoreBlock(),                          // §1.7
                  const Spacer(),                        // the real flex:1
                  _SettingsFooter(state: state),         // §1.8
                ]),
              ),
            ),
          ),
        ],
      ))),
    ]),
  ),
)
```

**Why `LayoutBuilder` + `ConstrainedBox` + `IntrinsicHeight` and not `Column`/`Expanded`/footer:**
`test/core/layout/scroll_body_inset_test.dart:151-164` reads
`tester.widget<ListView>(find.byKey(const Key('settings-screen-list')))`, casts
`listView.padding! as EdgeInsets`, and pins `padding.left == 16`, `padding.right == 16`,
`padding.bottom >= 48`. The widget under that key must therefore stay a `ListView` with exactly
those `EdgeInsets`. `IntrinsicHeight` gives the inner `Column` a determinate height inside the
unbounded scroll axis, so `const Spacer()` resolves — that is the only way to get the design's real
`flex:1` spacer *and* keep everything in one scrollable (which is what keeps 200% text scale from
clipping the footer off-screen).

*Design evidence:* HTML:70 `<div style="flex: 1 1 0%"></div>` sits between the notifications card and
the footer; in the render the band from y≈1230 to y≈1650 (≈30% of the canvas) is plain white. Plan
R1: "the spacer is real emptiness — never fill it, never vertically centre."

**Gutter:** HTML uses `padding: … 24px …` on every block (`:15`, `:20`, `:38`, `:46`, `:72`).
`Spacing.medium` (16) on the `ListView` + `Spacing.xSmall` (8) on the content column = 24 exactly,
with zero edits to the pinned core-layout test. (The alternative — bump the test to 24 — touches
`test/core/layout/`, a shared file this lane does not own. See §9-CF1.)

### 1.2 Top bar (NEW) — replaces `OMDSAppBar` at `:111-122`

`JeebTopBar(leading: back, title: l10n.settingsTitle, identifier: 'settings_back', onBack: ...)`.

The `onBack` callback is **copied verbatim** from `:120-121`:
`() => context.canPop() ? context.pop() : context.go('/')`. The comment at `:114-119` explaining why
(orphan route, empty Navigator stack) moves with it, shortened.

*Design evidence:* HTML:15-18 — row `padding: 14px 24px 0px`, `gap: 14px`, Ø40 circle
`background: var(--jeeb-surface-high)` with a 20px navy back glyph, title `20px / 700 / --jeeb-navy`.
Kit spec §5 #1 names 20 as a `JeebTopBar` consumer.

### 1.3 Identity card (NEW) — replaces the profile `OmdsSettingsRow` at `:169-177`

`JeebNavySurfaceCard(radius: 18, shadow: JeebShadows.ctaNavy)` wrapping a `Row`:

| Slot | Spec | Token |
|---|---|---|
| avatar | Ø50 circle, fill `rgba(255,255,255,.14)`, initial 18/w800 white | `ProfileAvatar(diameter: 50, background: cs.onPrimary.withValues(alpha: .14), foreground: cs.onPrimary, textStyle: context.jeebText.titleProminent)` |
| name | 16 / w700 white | `context.jeebText.cardTitle` + `cs.onPrimary` |
| subtitle | 12.5 / w600 periwinkle — `+961 3 123 456 · Edit profile` | `context.jeebText.bodySmall` + `JeebSemanticColors.mutedText` |
| trailing | 18px white chevron @ .7 | `Icon(DirectionalIcons.disclosure(context), size: 18, color: cs.onPrimary.withValues(alpha: .7))` |
| gap | 13 | `Spacing.small` |
| padding | `14/16` | `EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14)` inside the kit widget |

`Semantics(identifier: 'settings-profile-row', button: true)` and `Key('settings-row-profile')` and
`onTap: () => context.pushNamed('settings-profile')` all carry over unchanged from `:166-177`.

Subtitle composition preserves the current fallback at `:172-174`:
`phoneE164.isEmpty ? l10n.profileEditSubtitle : l10n.settingsIdentitySubtitle(ltrIsolate(phone), l10n.profileEditTitle)`.
Name falls back to `l10n.profileNamePlaceholder` as today (`:162`).

*Design evidence:* HTML:20-27; note — "profile promoted to a navy identity card".
`JeebShadows.ctaNavy` is `0 10 24 rgba(11,19,81,.28)`, byte-identical to HTML:20's
`box-shadow: rgba(11, 19, 81, 0.28) 0px 10px 24px`. This is the **only** shadow on the screen (R7).

### 1.4 Become a Jeeber (RESTYLE) — replaces the `OmdsSettingsRow` at `:182-189`

`JeebAccentFrameCard(radius: 16)` — white fill, **2px** `context.jeebRoles.accent` frame, no shadow.

| Slot | Spec | Token |
|---|---|---|
| disc | Ø38 circle, orange fill, 19px white scooter glyph | `jeebRoles.accent` fill + `Icons.delivery_dining` at `cs.onPrimary` |
| title | 14.5 / w700 navy — "Become a Jeeber" | `context.jeebText.cardTitle` + `cs.onSurface` |
| sub | 12 / w500 periwinkle — "Earn on errands you're already making" | `context.jeebText.bodySmall` + `mutedText` |
| trailing | 13 / w700 orange — "Start" | `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)` + `jeebRoles.accent` |
| padding | `13/16`, gap 12 | `Spacing.small` gap |

`Semantics(identifier: 'settings-row-become-jeeber')`, `Key('settings-row-become-jeeber')` and
`onTap: () => context.pushNamed('kyc-status')` carry over unchanged from `:179-189`.

*Design evidence:* HTML:29-36 (`border: 2px solid var(--jeeb-orange)`); note — "'Become a Jeeber'
surfaced as the one growth action (orange outline)". Plan Wave-2 red flag for screen 20 says
literally: "Become-a-Jeeber = `JeebAccentFrameCard`". This is the one orange fill on the screen (the
Ø38 disc) — R5's "orange marks the one thing that decays / grows" budget, spent once.

Do **not** add a role gate here. The current screen shows this row unconditionally; hiding it for
approved jeebers would be a behaviour change this design does not ask for (`BecomeJeeberCard`'s
`isAlreadyJeeber` flag is a *different* widget, used only by the orphan `ProfileTab`).

### 1.5 Language block (RESTYLE) — replaces `_LanguageSection` `:220-247` + `_LanguageRow` `:249-283`

```
JeebSectionLabel(l10n.settingsLanguage)          // renders "LANGUAGE"
JeebSegmentedToggle(
  segments: [en, ar],
  selectedIndex: locale.languageCode == 'ar' ? 1 : 0,
  onChanged: (i) => context.read<LocaleCubit>().setLocale(Locale(i == 0 ? 'en' : 'ar')),
)
```

Outer pill: `1.5px cs.outline`, `OmdsBorderRadius.pill`, padding 4. Segments: `flex: 1`, padding
`9/0`, pill; selected = `cs.primary` fill + `cs.onPrimary` at 13.5/w700; unselected = transparent +
`cs.onSurface` at w700.

`_LanguageRow` (`:249-283`) and its trailing `Icon(Icons.check)` are **deleted**. Both segments must
carry the pre-existing `Key('settings-row-language-en')` / `Key('settings-row-language-ar')` and the
identifiers `settings_language_en_option` / `settings_language_ar_option`, with
`inMutuallyExclusiveGroup: true` + `selected:` + `button: true` — that a11y contract is what
`_LanguageRow` exists for today and must not be lost. See §9-R2 (kit wiring request).

*Design evidence:* HTML:38-44; note — "EN/عربي as a live segmented toggle". Kit §5 #19 names
"20 (language)" as its consumer.

### 1.6 Notifications block (RESTYLE) — replaces `_NotificationsSection` `:285-371`

```
JeebSectionLabel(l10n.settingsNotificationsSection)   // "NOTIFICATIONS"
JeebOutlinedCard(radius: 16, dividers: true, children: [
  <switch row> offers          settings_notifications_offers_toggle
  <switch row> chat            settings_notifications_chat_toggle
  <switch row> status          settings_notifications_status_toggle
  <switch row> ratingReminders settings_notifications_ratings_toggle   // 4th — see §9-CF3
  <door-codes row>                                                     // non-interactive
])
```

- Keep `OmdsSettingsSwitchRow` (plan Wave-2 red flag: "keep `OmdsSettingsRow` semantics") with the
  existing `Key('settings-row-notifications-*')` and `Semantics(identifier:, toggled:, container:)`
  wrappers verbatim from `:297-348`.
- **Drop every `subtitle:`** (`:304`, `:317`, `:330`, `:343`). The board renders one line per row.
  This is the density change (R1/R12) and it is the single biggest visual delta on this screen: the
  notifications card goes from ~5×72px to 4×52px + one 52px lock row.
- `contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.medium)` (HTML:49 `padding: 13px 16px`).
- `titleStyle: context.jeebText.body.copyWith(fontWeight: FontWeight.w600)` — the board is 14/w600;
  `body` is 13.5/w500, so the weight is lifted and the 0.5px is accepted (R3: weight carries the
  hierarchy, size barely moves; `lib/features` may not write `fontSize:`).
- Switch visuals need **no code**: Wave 0 already shipped `switchTheme` in `app_theme.dart:238-245`
  (`thumbColor: white`, track `primary` selected / `surfaceContainerHighest` unselected) — exactly
  HTML:51 and HTML:61.
- Dividers: `1px cs.outlineVariant`, inset `Spacing.medium` (HTML:53 `height:1; background:
  var(--jeeb-surface-highest); margin: 0 16px`). Supplied by `JeebOutlinedCard(dividers: true)`.
- **Door-codes row** replaces the `OmdsSettingsRow` at `:349-355`: no leading icon, a `Text.rich`
  title (`l10n.notificationCategoryOtp` in `cs.onSurface` w600 + `l10n.settingsAlwaysOnQualifier` in
  `mutedText` w500), trailing `Icon(Icons.lock_outline, size: 17, color: mutedText)`. The long
  subtitle `notificationCategoryOtpAlwaysOn` is dropped.

- The "manage notification preferences" row (`:356-367`) **moves** to §1.7 — the board ends this card
  at the lock row and a chevron row would break the closed shape.

*Design evidence:* HTML:46-69; note — "notification toggles grouped in one outlined card with
door-codes honestly marked always-on".

### 1.7 MORE block (NEW card, not on the board) — rehomes three live destinations

```
JeebSectionLabel(l10n.settingsMoreSection)       // "MORE"
JeebOutlinedCard(radius: 16, dividers: true, children: [
  JeebListRow  savedAddressesTitle            → settings-addresses      settings_open_addresses
  JeebListRow  notificationPreferencesTitle   → settings-notifications  settings-row-notifications-manage
  if (Diag.enabled) JeebListRow 'Diagnostics' → settings-diagnostics    settings_open_diagnostics
])
```

`JeebListRow` = navy glyph, title navy w700, subtitle `mutedText`, trailing
`DirectionalIcons.disclosure(context)` chevron in periwinkle, inset `outlineVariant` divider.
Keys `settings-row-addresses`, `settings-row-notifications-manage`, `settings-row-diagnostics` and
all three identifiers carry over unchanged from `:203-216`, `:356-367`, `:395-407`.

The subtitles stay here (`savedAddressesSubtitle`, `notificationPreferencesRowSubtitle`) — these are
navigation rows, not toggles, and the kit spec for `JeebListRow` includes a subtitle slot.

*Design evidence:* the board does **not** draw this card — but plan §5 #25 lists `JeebListRow`'s
consumers as "**20** 23", i.e. the plan already anticipates a grouped list card on screen 20 that the
board omits. Constraint 2 (identifier freeze) and the fact that all three destinations are real
routes make deleting them a refusal, not an option (§9-CF2).

### 1.8 Footer (RESTRUCTURE) — replaces `_AboutSection` `:373-411` + `_AccountSection` `:426-477`

Docked below the `Spacer()`, padding `EdgeInsetsDirectional.only(bottom: 30)` on top of the list's
own gutter (HTML:72 `padding: 0px 24px 30px`).

```
Semantics(identifier: 'logout_delete_account_root', container: true, explicitChildNodes: true,
  child: Column(children: [
    JeebOutlinedCard(radius: 16, child: <sign-out row>),   // settings_sign_out_row
    <delete-account text action>,                          // settings_delete_account_row
    if (state.deletionPending) <pending line>,
    <version line>,
  ]))
```

- **Sign out** (HTML:73-76): `1.5px cs.outline`, r16, padding `13/16`, gap 12, an 18px navy exit
  glyph, label `l10n.appBarSignOut` at `context.jeebText.body.copyWith(fontWeight: FontWeight.w600)`
  in `cs.onSurface`. **No chevron** (the board draws none) — this is why `JeebListRow` needs an
  optional trailing (§9-R3). Keeps `Key('settings-row-sign-out')`, `identifier:
  'settings_sign_out_row'`, `enabled: !state.isSigningOut`, `onTap: _confirmSignOut` (`:462-472`).
- **Delete account** (HTML:77): centered, `margin-top: 10`, 12.5/w600, `rgb(198,40,40)` → render at
  `context.jeebText.bodySmall` in **`cs.error`** (§4.1 refuses `--jeeb-danger`; do not introduce
  `#C62828`). Keeps `Key('settings-row-delete-account')`, `identifier:
  'settings_delete_account_row'`, `enabled: !state.deletionPending && !state.isDeletingAccount`,
  `onTap: _confirmDeleteAccount` (`:442-460`). The leading `Icons.delete_outline` and the
  `leadingIconColor` at `:451-452` are deleted.
- **Pending line** — when `state.deletionPending`, render `l10n.accountDeletePending` as a second
  centered line in `mutedText` at `caption`. The board has no slot for it, but
  `test/settings_screen_test.dart` asserts that exact string and it is a real user-facing state.
- **Version** (HTML:78): centered, `margin-top: 12`, 11/w500 periwinkle —
  `l10n.settingsVersionFooter(appVersion)` → "Jeeb v1.2.3 · Beirut" at `context.jeebText.caption` in
  `mutedText`.

`_AboutSection`'s "App version" `OmdsSettingsRow` (`:384-390`) and the `settingsAboutSection` /
`settingsAccountSection` / `settingsProfileSection` headers are **deleted** — the board carries only
two section labels (`LANGUAGE`, `NOTIFICATIONS`), and the note says "destructive actions demoted to
the bottom", not "grouped under an Account header".

### 1.9 Vertical rhythm (measured from the HTML, R12)

| Gap | px | Token |
|---|---|---|
| top bar → identity card | 16 | `Spacing.medium` |
| identity → become-a-jeeber | 12 | `Spacing.small` |
| jeeber card → LANGUAGE label | 18 | `Spacing.medium` (16) |
| label → control | 10 | `Spacing.xSmall` (8) |
| LANGUAGE block → NOTIFICATIONS label | 18 | `Spacing.medium` |
| sign out → delete | 10 | `Spacing.xSmall` |
| delete → version | 12 | `Spacing.small` |
| footer bottom | 30 | `Spacing.twoXLarge` (32) — plan §5 says pick 32 |

Nothing on this screen is spaced at 24 or 28 vertically.

---

## 2. Tokens — every implicit/ad-hoc value in the current file

`settings_screen.dart` today has **zero** hex literals (it is token-clean) but it is *role-poor*: it
leans on OMDS defaults and `textTheme.bodyLarge`. Full replacement table:

| Current | Where | Becomes |
|---|---|---|
| `OMDSAppBar` default title style | `:112` | `context.jeebText.h2` + `cs.onSurface`, inside `JeebTopBar` |
| `OmdsSettingsSection` title (`textTheme.titleLarge` w600, OMDS default) | `:164`, `:201`, `:226`, `:295`, `:382`, `:440` | `JeebSectionLabel` → `context.jeebText.sectionLabel` at the 12.5px default, ls 1.2, uppercase, `mutedText` |
| `OmdsSettingsRow` title (`textTheme.bodyLarge`) | all rows | `context.jeebText.cardTitle` (cards) / `body`+w600 (toggle rows) / `bodySmall` (footer) |
| `OmdsSettingsRow` subtitle (`textTheme.bodySmall` + `onSurfaceVariant`) | all rows | `context.jeebText.bodySmall` + `JeebSemanticColors.mutedText` |
| `textTheme.bodyLarge?.copyWith(color: colorScheme.error)` | `:453-457` | `context.jeebText.bodySmall` + `cs.error` |
| `leadingIconColor: colorScheme.error` | `:452` | deleted (no leading glyph in the footer) |
| implicit card fill (`OmdsSettingsSection` has none) | — | `JeebOutlinedCard`: `cs.surface` + `1.5px cs.outline` (`#916F66`), `OmdsBorderRadius.medium` (16), **no shadow** |
| implicit divider | — | `1px cs.outlineVariant` (`#E5E1E5`), inset `Spacing.medium` |
| navy | — | `cs.primary` (`#0B1351`) |
| orange | — | `context.jeebRoles.accent` (`#D73B00`) — the sanctioned accessor, even though this file is not in the `no_raw_semantic_colors_test` list |
| periwinkle | — | `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` (`#777FC0`) — decorative/muted ink only, never a primary fact (R4) |
| back-circle fill | — | `cs.surfaceContainerHigh` (`#EAE7EB`) |
| switch on/off | — | already correct from `app_theme.dart:238-245`; pass no `activeColor` |
| identity-card shadow | — | `JeebShadows.ctaNavy` |
| radii | — | `OmdsBorderRadius.medium` (16) cards · `OmdsBorderRadius.pill` toggle · exact 18 for the identity card *inside* `JeebNavySurfaceCard` (kit widgets may use design-exact px; `lib/features` may not) |
| spacing | — | `Spacing.*` per §1.9; `EdgeInsetsDirectional` everywhere except the pinned `ListView.padding` |

`tool/check_design_tokens.sh` stays clean: no `Color(0x`, no `Colors.*`, no `fontSize:`, no
`BorderRadius.circular(N)`, no `EdgeInsets.all(<number>)`, no raw `AppBar(`.

---

## 3. Shared components consumed

| Kit widget (plan §5) | Used for | Replaces |
|---|---|---|
| #1 `JeebTopBar` (`leading: back`) | header | `OMDSAppBar` `:111-122` |
| #4 `JeebNavySurfaceCard` (r18, `ctaNavy`) | identity card | profile `OmdsSettingsRow` `:169-177` |
| #5 `JeebAccentFrameCard` (r16, 2px accent) | Become a Jeeber | `OmdsSettingsRow` `:182-189` |
| #10 `JeebSectionLabel` | LANGUAGE / NOTIFICATIONS / MORE | `OmdsSettingsSection.title` ×6 |
| #19 `JeebSegmentedToggle` | language | `_LanguageSection` + `_LanguageRow` `:220-283` |
| #3 `JeebOutlinedCard` (r16, dividers) | notifications card, MORE card, sign-out card | `OmdsSettingsSection` grouping |
| #25 `JeebListRow` | MORE rows + sign-out row | `OmdsSettingsRow` `:203-216`, `:356-367`, `:395-407`, `:462-472` |

**Kept, deliberately:** `OmdsSettingsSwitchRow` for the four toggle rows — the plan's Wave-2 note for
screen 20 says "keep `OmdsSettingsRow` semantics", the Wave-0 `switchTheme` already renders the board's
switch exactly, and `test/settings_screen_test.dart` toggles by tapping the row key.

**Not consumed:** `JeebCtaButton`/`JeebCtaFooter` — this screen's footer is not a CTA pill; it is an
outlined action card + a text action + a caption (HTML:72-79). If the kit's `JeebCtaButton.text`
variant lands with an ink override it can host "Delete account"; otherwise a plain `TextButton` in
`cs.error` is fine (the token gate bans `ElevatedButton`/`OutlinedButton`, not `TextButton`).

**Feature-local widget change:** `lib/features/settings/presentation/widgets/profile_avatar.dart` —
add optional `background`, `foreground` and `textStyle` params (defaults reproduce today's exact
output so `ProfileEditScreen` is byte-unchanged). Needed because the identity card's disc is
`rgba(255,255,255,.14)` on navy, and because `_InitialBubble` currently hardcodes
`textTheme.displaySmall`, which overflows at Ø50.

---

## 4. New functionality — there is none, and that is the finding

Screen 20 is the one spine screen with **no data gap and no new interaction**. Everything the board
and the note describe already exists:

| Note claim | Already in code |
|---|---|
| "profile promoted to a navy identity card" | `state.profile.name` / `.phoneE164` / `.photoUrl` (`settings_state.dart`, `user_profile.dart`) |
| "'Become a Jeeber' surfaced as the one growth action" | `context.pushNamed('kyc-status')` (`:188`) |
| "EN/عربي as a **live** segmented toggle" | `LocaleCubit.setLocale` (`:233-242`) — already live, already persisted (`app.locale.languageCode`) |
| "notification toggles grouped in one outlined card" | `SettingsCubit.setNotification` + `NotificationCategory` (4 categories) |
| "door-codes honestly marked always-on" | `notificationCategoryOtp` / `notificationCategoryOtpAlwaysOn` |
| "destructive actions demoted to the bottom" | `LogoutDeleteConfirmSheet.show(...)` (`:481-495`) |

**No cubit or state change is required. No new endpoint, no new field, no `TODO(redesign-24)`.**

Two honest notes that are *not* introduced by this redesign and must not be "fixed" here:
1. Notification preferences are **in-memory only** — `SettingsCubit`'s own doc says persistence
   ships "when the user-preference-v2 NSwag client lands". The redesign does not change that; the
   real persisted surface is the `settings-notifications` sub-route, which the MORE card still
   reaches.
2. The avatar photo is device-local (`ProfileAvatar._isLocalPath`). Rendering it in the identity
   card is a superset of the board (which draws an initial disc), not a fabrication.

---

## 5. New routes

**None.** `/settings`, `/settings/profile`, `/settings/addresses`, `/settings/notifications`,
`/settings/diagnostics` all exist (`app_router.dart:973-1058`). No `backFallbacks` edit —
`settings-profile`, `settings-notifications` and `language-settings` are already mapped to
`/settings` at `:478-519`, and `settings-addresses` self-wraps `RootAwareBackScope` (plan §7.4:
keep it OUT of `backFallbacks`).

`app_router.dart` is **not touched by this lane.**

---

## 6. Semantics identifiers

### 6.1 Frozen — every one must still be emitted after the rebuild (14)

| Identifier | New home |
|---|---|
| `settings-profile-row` | §1.3 identity card |
| `settings-row-become-jeeber` | §1.4 accent-frame card |
| `settings_open_addresses` | §1.7 MORE card |
| `settings_language_en_option` | §1.5 toggle segment 0 |
| `settings_language_ar_option` | §1.5 toggle segment 1 |
| `settings_notifications_offers_toggle` | §1.6 row 1 |
| `settings_notifications_chat_toggle` | §1.6 row 2 |
| `settings_notifications_status_toggle` | §1.6 row 3 |
| `settings_notifications_ratings_toggle` | §1.6 row 4 |
| `settings-row-notifications-manage` | §1.7 MORE card |
| `settings_open_diagnostics` | §1.7 MORE card (still `if (Diag.enabled)`) |
| `logout_delete_account_root` | §1.8 footer root (`container: true` + `explicitChildNodes: true` — required, §7.5) |
| `settings_delete_account_row` | §1.8 |
| `settings_sign_out_row` | §1.8 |

Keys that widget tests bind to and must also survive: `settings-screen-list`,
`settings-row-profile`, `settings-row-become-jeeber`, `settings-row-addresses`,
`settings-row-language-en`, `settings-row-language-ar`, `settings-row-notifications-offers|chat|status|ratings|manage`,
`settings-row-diagnostics`, `settings-row-delete-account`, `settings-row-sign-out`.

Retired: `Key('settings-row-app-version')` and `Key('settings-row-notifications-otp')` — plain
`Key`s, not `Semantics` identifiers, and no test or Maestro flow references either
(`grep -rn "settings-row-" test/ lib/devtool/` returns only `settings-screen-list`).

### 6.2 New identifiers proposed (`<screen>_<element>` per §7.5)

| Identifier | Element |
|---|---|
| `settings_root` | root `Semantics` on the body (`container: true`, `explicitChildNodes: true`) |
| `settings_back` | `JeebTopBar` back circle |
| `settings_language_toggle` | the segmented control container (the two segment ids stay on the segments) |
| `settings_version_label` | the footer version line (read-only, for QA screenshot diffing) |

No Maestro flow currently addresses this screen by identifier
(`grep -rn "settings_" .maestro/` → nothing), so the additions are free; the freeze list above is
what protects the 625 `find.bySemanticsIdentifier` assertions elsewhere.

---

## 7. RTL

| Risk | Mitigation |
|---|---|
| Identity-card chevron and MORE-card chevrons point the wrong way | `DirectionalIcons.disclosure(context)` (already the idiom at `:187`, `:211`, `:364`, `:469`) |
| Top-bar back arrow | `DirectionalIcons.back(context)` inside `JeebTopBar` |
| **`Icons.logout` does not mirror** and has no `DirectionalIcons` resolver | screen-local `_ExitIcon` that wraps the glyph in `Transform.scale(scaleX: -1)` when `Directionality.of(context) == TextDirection.rtl`. Do **not** substitute `Icons.login` — it is not the mirror of `Icons.logout` |
| `+961 3 123 456 · Edit profile` bidi-reorders in an AR layout | wrap the phone in an LTR isolate (`⁦…⁩`) before passing it to `l10n.settingsIdentitySubtitle`; keep the whole subtitle a single `Text` so `find.textContaining` still resolves |
| Segmented toggle segment order | plain `Row` with two `Expanded` children — auto-mirrors, so العربية lands at the start in RTL, which is correct. Selection must be driven by `locale.languageCode`, **never** by segment index position |
| Row paddings | `EdgeInsetsDirectional` everywhere. The one exception is the pinned `ListView.padding`, which is `EdgeInsets.only(left: 16, right: 16, …)` — symmetric, so mirroring is a no-op |
| `العربية` inside an LTR app | single Arabic word in a centered `Text`; no isolate needed. Do not force `TextDirection.ltr` on the segment |
| Uppercasing section labels | `JeebSectionLabel` applies `toUpperCase()` internally; a no-op on Arabic strings |

`test/settings_screen_test.dart` already has an AR/RTL case asserting
`Directionality.of(ctx) == TextDirection.rtl` on `settings-screen-list` — that stays green.

---

## 8. Test impact

### 8.1 Unchanged (must stay green with zero edits)

- **`test/core/layout/scroll_body_inset_test.dart:151-164`** — the hard constraint that shapes §1.1.
  `ListView` type, `Key('settings-screen-list')`, `padding as EdgeInsets`, `left == 16`,
  `right == 16`, `bottom >= 48`. If your change makes this test fail, **your structure is wrong**, not
  the test.
- `test/core/router/settings_profile_route_test.dart`, `dev_seam_route_pin_test.dart`,
  `w3_w4_routes_resolve_test.dart` — route names and the `SettingsScreen({cubit, appVersion})`
  constructor seam are untouched. `lib/devtool/catalog/entries/batch_10_entries.dart:311` also
  depends on that seam (§7.4: never delete a constructor seam).
- `test/language_settings_screen_test.dart` — a different screen (`LanguageSettingsScreen`,
  `/settings/language`). Not in scope. **Do not** "unify" it with the new toggle.
- `test/settings_screen_test.dart` cases that keep passing unchanged: the AR/RTL case
  (`الإعدادات`, `تسجيل الخروج`, RTL directionality), the language-tap case
  (`Key('settings-row-language-ar')` → prefs `'ar'`), the offers-toggle case
  (`Key('settings-row-notifications-offers')`), the destructive-rows case (both keys), and the
  deletion-pending case (`'Scheduled for deletion. Sign in again to cancel.'`).

### 8.2 Legitimately broken — the design genuinely changed (all in `test/settings_screen_test.dart`,
this lane's own file)

| Assertion | Why it breaks | Fix |
|---|---|---|
| `expect(find.text('Profile'), findsWidgets)` | the `settingsProfileSection` header is deleted (board has no Profile header) | assert the identity card instead: `find.byKey(const Key('settings-row-profile'))` |
| `expect(find.text('Language'), findsOneWidget)` | `JeebSectionLabel` uppercases → `'LANGUAGE'` | `find.text('LANGUAGE')` |
| `expect(find.text('Notifications'), findsWidgets)` | label becomes `'NOTIFICATIONS'`; the MORE row still reads `'Notifications'` so `findsWidgets` may pass by accident | make it explicit: `find.text('NOTIFICATIONS')` |
| `expect(find.text('About'), findsWidgets)` | About section deleted | drop the assertion |
| `expect(find.text('Account'), findsWidgets)` | Account header deleted (the *root identifier* survives) | replace with `find.bySemanticsIdentifier('logout_delete_account_root')` |
| `expect(find.text('1.2.3'), findsOneWidget)` | version moves into `'Jeeb v1.2.3 · Beirut'` | `find.textContaining('1.2.3')` |
| `expect(find.text('+96170555888'), findsOneWidget)` | phone is now part of `'+961… · Edit profile'` | `find.textContaining('+96170555888')` |

Each of these is an *assertion* change, never an identifier rename and never a weakened gate.

### 8.3 Tests to add (this lane)

1. Identity card renders the phone inside an LTR isolate under `Locale('ar')` and the card is
   tappable → `settings-profile'` route push.
2. `JeebSegmentedToggle` reports `selected: true` on exactly one segment and flips with the locale.
3. The four notification identifiers are all emitted and the ratings toggle still flips
   `state.notifications.ratingReminders`.
4. `MORE` card exposes `settings_open_addresses` and `settings-row-notifications-manage`; the
   diagnostics row is absent when `Diag.enabled` is false.
5. Footer at `textScaler: 2.0` on a 360×640 surface does not throw a `RenderFlex` overflow (the
   `IntrinsicHeight`+`Spacer` structure is the thing under test).

No goldens exist for this screen — nothing to regenerate.

---

## 9. Conflicts, refusals and requests

### Conflicts / refusals

**CF1 — 24px gutter vs a pinned 16px.** `scroll_body_inset_test.dart` pins the `ListView`'s own
horizontal padding at 16. **Not a refusal:** 16 stays on the `ListView`, the remaining 8 is applied to
the content column, and the rendered gutter is the design's 24. If the integrator would rather bump
that shared core test to 24, that is equivalent — but it is a cross-lane edit and this proposal does
not take it.

**CF2 — the board deletes Saved addresses, Notification preferences and Diagnostics. REFUSED.**
All three are live destinations with real routes, and dropping them destroys the frozen identifiers
`settings_open_addresses`, `settings-row-notifications-manage`, `settings_open_diagnostics`
(constraint 2). Rehomed into a MORE card built from the same kit primitives (§1.7). The board is a
mock of the common case, not an inventory of the screen.

**CF3 — the board shows three notification toggles; the app has four. REFUSED to drop.**
`NotificationCategory.ratingReminders` is a real, user-controllable category with a frozen
identifier. It renders as a fourth row in the same card — same pattern, one more 52px row.

**CF4 — "Door codes" vs "Security codes". Board wording NOT adopted; owner call.** The board's row is
labelled `Door codes`. The app's row governs **both** at-door handover codes and sign-in OTP —
`notificationCategoryOtpAlwaysOn` literally reads "Always on so you can sign in", and the same
category is titled "Security codes" on the `settings-notifications` sub-screen. Renaming it to "Door
codes" here would be inaccurate and would fork the copy across two screens. Proposal keeps
`notificationCategoryOtp` ("Security codes") and adds the board's `· always on` qualifier. Cheap
either way — flip it if the owner prefers the board's word.

**CF5 — `Delete account` at `rgb(198,40,40)`. REFUSED as a raw value.** §4.1 maps `--jeeb-danger` to
`colorScheme.error` (`#B00020`, set explicitly by Wave 0). Do not introduce `#C62828`.

**CF6 — the board draws an initial disc; the app has a real avatar photo.** Not a conflict — the
photo is rendered when `profile.photoUrl` is set, initials otherwise. A superset of the board.

**CF7 — `· Beirut` in the version line is static copy, not a field.** No city/region exists on any
DTO. Shipping it as a localized literal is consistent with the DS ("never promise coverage beyond
Beirut", `_ds/readme.md:41`) and is not fabricated data — but it *is* a coverage claim, so it lives in
the ARB where it can be changed without code. If the owner objects, ship `Jeeb v{version}` alone.

**CF8 — no locked-decision conflict.** `test/decision_violations_test.dart` has zero matches for
settings. Screen 20 carries no fee/commission copy (D41/D44), no rating surface (D56), no chat
composer (B04), no vehicle keys (D20), no KYC resubmit (D52), and does **not** resurrect the deleted
in-app role switch — `_LanguageSection` is a *locale* toggle, and the `settingsRole*` keys stay
unused by this screen (the deleted role switch lives in the orphan `profile_tab.dart`, which this
lane does not touch).

### Wiring requests

- **R1 — owner / shell lane:** `/settings` has **no forward-nav entry point** anywhere in `lib/`.
  Either point the shell Profile tab at it, or confirm that `customer_profile_screen.dart` is the
  real screen-20 target and re-scope. Until then this redesign is deep-link-only. (§0)
- **R2 — kit lane, `JeebSegmentedToggle`:** per-segment `key` **and** `identifier` pass-through, with
  `inMutuallyExclusiveGroup: true` + `selected:` + `button: true` semantics per segment. Without it,
  `settings_language_en_option` / `settings_language_ar_option` and
  `Key('settings-row-language-ar')` cannot survive and the a11y contract of `_LanguageRow` is lost.
- **R3 — kit lane, `JeebListRow`:** nullable trailing (or `showChevron: false`) so the Sign-out row
  can use it — the board draws no chevron there (HTML:73-76).
- **R4 — kit lane, `JeebCtaButton.text`:** an ink/foreground override (or a `destructive` tone) so
  "Delete account" can render in `colorScheme.error`. Otherwise this screen uses a plain
  `TextButton`.
- **R5 — kit lane, `JeebOutlinedCard`:** confirm `dividers: true` emits `1px cs.outlineVariant` inset
  by `Spacing.medium` between children (HTML:53) — this screen has two cards that depend on it.
- **R6 — kit lane, `JeebNavySurfaceCard`:** confirm `radius: 18` and `shadow: JeebShadows.ctaNavy`
  are both expressible, and that the leading slot accepts an arbitrary widget (the avatar may be a
  photo, not an initial).
- **R7 — l10n integrator batch** (EN key + `@key` description → real AR value → `_get` getter → call
  site; parity gate fails both directions):

| Key | EN | Notes |
|---|---|---|
| `settingsIdentitySubtitle` | `{phone} · {action}` | placeholders `phone`, `action`; AR uses the same separator |
| `settingsAlwaysOnQualifier` | ` · always on` | leading separator inside the localized string so AR can reorder it |
| `settingsMoreSection` | `More` | new section label |
| `settingsVersionFooter` | `Jeeb v{version} · Beirut` | placeholder `version`; city is copy, see CF7 |
| `settingsBecomeJeeberCta` | `Start` | **new key**, settings-scoped — do NOT change `becomeJeeberCardCta` ("Start now"), which `shell/widgets/jeeber_tab_empty_state.dart:77` uses as a button label |
| `becomeJeeberCardSubtitle` | value → `Earn on errands you're already making` | **value edit, existing key**; also improves `jeeber_tab_empty_state.dart:76`. Flag to that lane |

---

## 10. Definition of done for this screen

- [ ] Matches `20-settings.png` at the same scale — in particular the empty band above the footer
      (R1) and the four-row notifications card with **no subtitles** (R12).
- [ ] All 14 frozen identifiers emitted; 4 new ones added per §6.2; no rename.
- [ ] `scroll_body_inset_test.dart` green **without edits**.
- [ ] `settings_screen_test.dart` updated only per §8.2 (assertions, never identifiers).
- [ ] AR renders correctly; phone LTR-isolated; exit glyph mirrored; 200% text scale does not
      overflow.
- [ ] `tool/check_design_tokens.sh` clean; `dart analyze --fatal-infos` adds nothing.
- [ ] l10n batch landed in both locales with getters; parity script green.
- [ ] No edits outside `lib/features/settings/` + `test/settings_screen_test.dart`.

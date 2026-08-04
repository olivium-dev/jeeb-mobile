# W4 · settings — apply report

**Lane:** `w4-settings` · **Branch:** `feat/redesign-24-migration` · **Date:** 2026-08-03
**Reference:** no render exists for these screens. Language taken from the neighbour,
`screens/20-settings.png` / `.html`, and from the already-redesigned
`lib/features/settings/presentation/screens/settings_screen.dart` + its `presentation/widgets/`.

**Status: partial.** One of the three assigned files was migrated; the other two were deliberately
not touched, for reasons recorded below and in `wiring/w4-settings.md`.

---

## 1. What the neighbour does, and what these screens did instead

| Screen 20 (redesigned) | Edit profile (before) |
|---|---|
| In-body `JeebTopBar` — Ø40 `surfaceContainerHigh` circle + 20/w700 navy title, pad `14/24/0`, start-aligned | Material `OMDSAppBar` — 56px toolbar, **centred** `headlineSmall` title, `Icons.arrow_back` (non-directional) |
| 24px side gutters on every band | 16px (`EdgeInsets.all(Spacing.medium)`) |
| Uppercase periwinkle `JeebSectionLabel` + a 1.5px-outlined `JeebOutlinedCard.grouped` with inset dividers | `OmdsSettingsSection` + `OmdsSettingsRow` — M3 list chrome, title-cased header |
| `column → content → flex:1 real emptiness → docked footer (0/24/32)` | Everything, including the primary CTA, inside one scrolling `ListView`; no empty band, no docked footer |
| Outline over shadow; the one shadow on the screen is the navy identity card | No cards at all; flat rows |
| Avatar disc = navy fill + white initial (kit `JeebAvatar`) | `primaryContainer` pale disc + `onPrimaryContainer` letter at `textTheme.displaySmall`, Ø96 — off the system's size ramp and off its ink |
| Orange appears exactly once, on the growth card | No orange (correct — nothing here decays) |

---

## 2. `profile_edit_screen.dart` — MIGRATED

Structure now mirrors screen 20 band-for-band:

1. `JeebTopBar.back(title: l10n.profileEditTitle, identifier: 'profile_edit_back')`
2. `Expanded(ListView)` — 24px gutters, top-aligned, three bands at `Spacing.xLarge` (24) rhythm:
   avatar hero + its two text actions → name field → `PROFILE` label + the outlined phone row
3. real empty band (the `Expanded`), then
4. `SafeArea(top: false) → JeebCtaFooter.single` docking the Save pill

Kit widgets adopted: `JeebTopBar` · `JeebCtaFooter.single` · `JeebCtaButton.primary` ·
`JeebCtaButton.text` ×2 · `JeebSectionLabel` · `JeebOutlinedCard.grouped` · `JeebListRow` ·
`JeebSurfaceTone` (ink lookup) · `JeebAvatar` (via `ProfileAvatar`).

`presentation/widgets/profile_avatar.dart` now **wraps** `JeebAvatar` instead of hand-rolling a
disc (−45 LOC). It keeps one thing the kit cannot do: JEBV4-13 stores a just-picked avatar as an
absolute on-device path, and `JeebAvatar` composes `OmdsProfileAvatar`, whose image path is
network-only (`OmdsCachedImage`). Local paths keep the `Image.file` branch with the kit disc as the
error placeholder; remote and absent photos delegate straight through. Diameter moved
`Sizes.tenXLarge` (96) → `JeebAvatar.heroDiameter` (74) — the largest size the board realizes.

### Preserved byte-identically
`profile_edit_save_cta` · `profile_edit_change_avatar_cta` · `profile_edit_remove_avatar_cta` ·
`profile_edit_name_field` — all four `Semantics(identifier:, button/textField:, container:)`
wrappers are unchanged and still wrap the CTA, not the kit's own node (`JeebCtaButton` adds a node
only when given an `identifier`, so there is no duplicate). Keys `profile-edit-save`,
`profile-edit-name`, `profile-edit-change-avatar`, `profile-edit-remove-avatar`,
`profile-edit-phone-readonly` unchanged. One identifier **added**: `profile_edit_back` on the new
top bar's leading circle (`<screen>_<element>`; the old `OMDSAppBar` back had none).

### Behaviour deliberately NOT changed
- Back is still the guarded `Navigator.maybePop()` — `JeebTopBar`'s default is the same call
  `OMDSAppBar._buildBackButton` made.
- Save still swaps its **label** to `profileSaving` rather than using `JeebCtaButton.isLoading`:
  the spinner never settles, and two shipped tests drive this path with `pumpAndSettle()`.
- Change-avatar still only *disables* while a pick is in flight (same reason).
- The name field stays `OmdsTextField` — the kit has no input primitive and the board draws no
  general text field; swapping it would be churn, and `isRequired` + `errorText` carry the
  validation contract the tests read.
- No new strings, no ARB edit, no endpoint, no flow/step/affordance change.

---

## 3. `saved_addresses_screen.dart` — NOT TOUCHED (deliberate)

- It is **dead code**. `grep -rn saved_addresses_screen lib/` returns exactly one importer:
  `lib/devtool/catalog/entries/batch_10_entries.dart`. The `settings-addresses` route
  (`app_router.dart:1024`) builds `SavedLocationsScreen` from `lib/features/location/`, which is
  the real, live saved-address manager (JM-049). The file carries its own
  `// ORPHAN (JEBV4-227) … superseded by SavedLocationsScreen` banner. The migration plan's own
  sanity rule — *"confirm your file is reachable from `lib/main.dart` before editing it"* — fails.
- It is a **36-line placeholder** whose header says `Do NOT add behavior here`. Its copy
  ("Saved Addresses coming soon / This screen is not yet available") is provisional and
  intentionally un-localized. Re-skinning it to the system would make an unimplemented screen look
  implemented, and re-pointing it at the existing `savedAddressesEmptyTitle` /
  `savedAddressesEmptyBody` keys would change what it *means* — "no addresses yet" is not the same
  claim as "not built yet". A localized "coming soon" sentence does not exist in the ARB and would
  need an l10n wiring request to invent one, for a screen no user can reach.
- It also has no app bar at all (`OmdsEmptyStatePage(appBar: null)`); giving it a `JeebTopBar`
  would add a back affordance the re-skin brief explicitly forbids.

**If the integrator disagrees**, the honest fix is to delete the file and its catalog entry, not to
restyle it — the live screen already exists. That is a scope call above this lane.

---

## 4. `notification_preferences_screen.dart` — NOT TOUCHED (nothing to style)

The file is a **31-line `BlocProvider` wrapper** with zero UI: it resolves
`NotificationPrefsRepository` from DI and hands off to `NotificationPrefsScreen`. The screen the
user actually sees lives at
`lib/features/notification_prefs/presentation/notification_prefs_screen.dart` — a different feature
directory, which constraint 9 puts outside this lane.

That screen is the last surface reachable from the redesigned Settings that still ships an M3
`AppBar`, `OmdsSettingsSection` cards and a hand-rolled grey note row. A **paste-ready restyle** —
`JeebTopBar` header, 24px gutters, `JeebSectionLabel` + `JeebOutlinedCard.grouped`,
`JeebInfoNote.muted` for the push-only note, `JeebCtaButton.outline` for retry, and screen 20's
`_ToggleRow` verbatim so the row-body tap and the four test-pinned subtitles survive — is filed in
`docs/redesign-2026-08/wiring/w4-settings.md`, together with the nine frozen identifiers it must
not disturb.

---

## 5. Verification

```
dart analyze lib/features/settings                       → No issues found!
flutter test test/profile_edit_screen_test.dart \
             test/core/router/settings_profile_route_test.dart  → 9/9 pass
flutter test test/features/settings/ test/settings_screen_test.dart \
             test/settings_cubit_test.dart test/notification_prefs_screen_test.dart \
             test/language_settings_screen_test.dart             → 61/61 pass
tool/check_design_tokens.sh patterns, greped over the two changed files → 0 hits
```

One bug was found and fixed during verification: the first draft read
`Theme.of(context).extension<JeebSemanticColors>()!` for the padlock ink, which threw
`Null check operator used on a null value` in `settings_profile_route_test.dart` — that harness
mounts `MaterialApp.router` with **no theme**, so the extension is absent. It now reads
`JeebSurfaceTone.of(context).mutedInk`, the null-safe, tone-aware lookup every kit child uses.

Two ad-hoc layout checks were written, run green, and then deleted rather than left in the shared
`test/` tree mid-wave. Paste-ready if the integrator wants them permanent:

```dart
// 360x640 @ 200% text scale — the new docked footer must not overflow the column.
view.physicalSize = const Size(360, 640); view.devicePixelRatio = 1.0;
await tester.pumpWidget(harness(cubit, scale: 2.0));
await tester.pumpAndSettle();
expect(tester.takeException(), isNull);          // PASSED

// Locale('ar') — directional insets/icons on the new top bar, footer and list row.
await tester.pumpWidget(harness(cubit, locale: const Locale('ar')));
await tester.pumpAndSettle();
expect(tester.takeException(), isNull);          // PASSED
```

---

## 6. Remaining inconsistencies vs the neighbour (honest list)

1. **The name field is still OMDS input chrome.** No board screen draws a general text field and
   the kit has no input primitive, so `OmdsTextField`'s filled/underlined M3 treatment is the one
   element on the screen that does not read as Jeeb. This is the largest remaining gap and it needs
   a kit decision, not a screen decision.
2. **Docked pill vs docked outlined row.** Screen 20's footer is an *outlined* sign-out row; mine
   docks a navy `JeebCtaButton.primary` with `JeebShadows.ctaNavy`. Correct per §5 #2 (this screen's
   one job is to commit), but it means profile-edit carries a shadowed navy surface where its parent
   carries none.
3. **`Icons.lock_outline`, not R10's filled `Icons.lock`.** `test/profile_edit_screen_test.dart:93`
   pins the outline glyph as the read-only mark; screen 20's always-on row uses the filled one.
   One-glyph divergence, refused on purpose (recorded in the wiring file).
4. **The phone number is not LTR-isolated.** `SettingsIdentityCard` wraps it in U+2066/U+2069 so
   the `+` holds under Arabic; here the shipped test asserts `find.text('+96170100200')` on the raw
   string, which the isolate marks would break. Real RTL imperfection, left rather than broken.
5. **The section label reads `PROFILE` over a single phone row.** Copy preserved on purpose (the
   re-skin changes no copy meaning); `PHONE` would read better and is filed as an *optional*,
   un-applied l10n ask.
6. **The two avatar actions are a centred stack of bare text labels.** `JeebCtaFooter` has three
   forms and none covers a mid-body action pair, so this is composed by hand from two
   `JeebCtaButton.text`. It is restrained and token-clean but it is not a board pattern.
7. **No top navy band.** Profile-edit deliberately does not repeat the parent's navy identity card —
   the avatar is the editable subject here, not a summary. A reviewer expecting screen 20's rhythm
   will notice the screen opens on white.
8. **Two of three assigned screens are unchanged**, per §3 and §4. The settings *area* is therefore
   not uniformly on the system until the `notification_prefs` request is applied.

# W4 — `language` onto the Jeeb design system

**Lane:** `w4-language` · **Owns:** `lib/features/language/`
**Screen:** `lib/features/language/presentation/screens/language_settings_screen.dart`
(`/settings/language`, route name `language-settings`)
**Reference render:** none exists for this screen — neighbour used was
`docs/redesign-2026-08/screens/20-settings.{png,html}` (its `LANGUAGE` band, `tpl 1186-1190`).

## What the neighbour does

Screen 20's language block is deliberately **not** a card and **not** a row list: an uppercase
12.5/w700/ls1.2 periwinkle `LANGUAGE` label, `margin-top: 10px`, then a single 1.5px brown-outlined
999px track padded 4 with two `flex:1` segments — the active one a solid navy pill with white
13.5/w700 ink, the other transparent with navy ink. No check glyph, no chevron, no shadow. 24px
gutters, 18px band offset. The bottom ~35% of the screen is plain white.

## What this screen did before

Material `OMDSAppBar` + a `ListView` at 16px gutters holding one `OmdsSettingsSection` with two
`OmdsSettingsRow`s, selection expressed as a trailing `Icons.check`. Nothing on the screen read the
redesign tokens; it was the last surface where the language choice looked like a Material settings
list while `/settings` next door already shipped the two-up pill for the *same* choice.

## Changes

| Before | After |
|---|---|
| `OMDSAppBar` + hand-rolled `Semantics`/`ExcludeSemantics`/`IconButton` leading | `JeebTopBar.back(title:, identifier: 'language_back', onLeadingPressed:)` — in-body bar, Ø40 tonal circle, `h2` title, guarded `canPop ? pop : go('/')` preserved verbatim |
| `OmdsSettingsSection(title: …)` | `JeebSectionLabel(l10n.settingsLanguage)` — 12.5/w700/ls1.2 uppercase periwinkle, locale-gated casing |
| two `OmdsSettingsRow` + `Icons.check` | one `JeebSegmentedToggle` with two `JeebSegment`s |
| `ListView` at `Spacing.medium` (16) symmetric gutters | `ListView` at `EdgeInsetsDirectional` 24px gutters + `context.scrollBodyBottomInset`, inside `Expanded` under the bar so the empty band below is the board's real `flex:1` |
| — | `SafeArea(bottom: false)`, matching the sibling `/settings` shell |

`_LanguageRow` (the private row widget) is deleted; nothing replaced it — the kit widget carries
the whole state machine.

## Contracts preserved

- Semantics identifiers, byte-identical: `language_settings_root`, `language_back`,
  `language_english_option`, `language_arabic_option`. All four are asserted by
  `.maestro/flows/jm-059-language-settings.yaml` (and `language_back` is referenced by
  `jm-035-customer-profile.yaml`).
- Per-segment semantics shape is unchanged from the old `_LanguageRow`: `button` + `container` +
  `inMutuallyExclusiveGroup` + `selected` + label. TalkBack still announces the selection.
- Widget keys: `language-settings-list`, `language-row-en`, `language-row-ar` (the latter two ride
  `JeebSegment.key`, which lands on the segment's `InkWell`, so existing `tester.tap(find.byKey(…))`
  still hits the right target).
- Behaviour: unchanged. Same cubit call, same instant switch, same no-op on re-selecting the active
  locale (`LocaleCubit.setLocale` returns early), same back fallback, same strings. No new l10n key,
  no pubspec edit, no shared-file edit, **no wiring request needed**.

## Test delta

`test/language_settings_screen_test.dart` — the two `find.byIcon(Icons.check)` assertions could not
survive: the kit expresses selection as a **fill swap, never a glyph** (§5 #4/#19). They are replaced
by a `_segmentDecoration` helper reading the segment's own `BoxDecoration.color` against
`colorScheme.primary` / `Colors.transparent` — the same technique the kit's own
`jeeb_segmented_toggle_test.dart` uses. The RTL-flip test, the persistence assertion and the
no-op test are untouched. 3/3 pass.

## Refusals / restraint

- **No new copy.** The screen still says exactly what it said; no explanatory `JeebInfoNote` was
  added, because that would need a new ARB key and this is a re-skin, not a product change.
- **No `JeebCtaFooter`.** Selection is instant by design; adding a confirm step would be a flow
  change.
- **No `JeebOutlinedCard` wrapper** around the toggle — the board draws the language band bare, and
  boxing it would contradict the neighbour.

## Verification

```
dart analyze lib/features/language test/language_settings_screen_test.dart   → No issues found!
flutter test test/language_settings_screen_test.dart --no-pub                → 3 passed
flutter test test/core/router/w3_w4_routes_resolve_test.dart --no-pub        → 9 passed
grep 'Color(0x|fontSize:|EdgeInsets.only|Alignment.center(Left|Right)'       → 0 hits
```

Not run: the full suite / repo-wide analyze (≈20 sibling lanes editing concurrently).
Not done: a visual run on simulator or device — the RTL flip is proven by the widget test's
`Directionality.of` assertion only.

## Known remaining inconsistencies

1. **"Language" renders twice** — as the `h2` navy top-bar title and again as the periwinkle
   `LANGUAGE` section label directly beneath. The pre-redesign screen had the same duplication
   (`OMDSAppBar` title + `OmdsSettingsSection` title), so it was preserved rather than edited; on the
   neighbour the label earns its place by separating one band from three others. A designer pass
   should decide whether the label survives on a single-band screen.
2. **The band offsets are the sibling's, not the board's** — `Spacing.medium` (16) band offset and
   `Spacing.xSmall` (8) label→toggle gap vs the render's 18 and 10. Both are the nearest OMDS tokens
   and both match `settings/presentation/widgets/settings_language_toggle.dart` exactly; per-screen
   pixel exactness was traded for cross-screen alignment.
3. **The Arabic segment is lighter than the render.** The board sets `العربية` at 14px in
   `--font-arabic` (Baloo Bhaijaan 2); the kit ships both segments at 13.5/w700 Inter because the AR
   display face is deliberately not bundled (plan §4.2). Divergence accepted upstream, restated here.
4. **This screen contributes no card vocabulary** — after the migration it uses no
   `JeebOutlinedCard`, no `JeebListRow`, no orange at all. That is faithful to the neighbour's
   language band, but it means the screen is now the sparsest surface in the app: one 40px circle,
   one title, one label, one pill, and ~85% white.

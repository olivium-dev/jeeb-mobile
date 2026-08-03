# 01 · Onboarding — implementation report

**Status:** applied (rebuild complete; blocked only on the §E wiring, which is written up in
`docs/redesign-2026-08/wiring/01-onboarding.md`).

**Files changed**
- `lib/features/onboarding/presentation/onboarding_screen.dart` (547 → 1087 LOC, rebuilt)
- `test/onboarding_screen_test.dart` (6 tests edited, 4 added, 0 removed)

No new files under `presentation/widgets/` — per the instruction set everything stays in the screen
file.

---

## What landed

**Three-band column replaces the full-bleed pager + scrim.**
`Scaffold(body: Column[_OnboardingTopBar, Expanded(_MarketplaceStage), _OnboardingSheet])`.
`_BottomScrim`, `_BottomPanel`, `_LanguageToggle` and the `ColoredBox` inside
`_WalkthroughIllustration` are deleted; `_kVoiceFirstAsset` is deleted (the SVG stays declared in
`pubspec.yaml`, untouched).

**Kit consumed directly — zero inline copies.** `JeebMicHero.decorative()` (Ø118, the two-shadow
board glow), `JeebPageDots` (measured 22×8 / gap 7 defaults, `identifier` + `semanticLabel` passed),
`JeebWaveform.cardMark()` (the 4-bar orange mark on the voice card), `JeebTierChip(tier:
JeebTier.flash, …)`, `JeebCtaFooter.split(padding: EdgeInsetsDirectional.zero, leading:
OmdsSkipButton-wrapper, trailing: CTA)`. The revised doc's "build inline (kit #14/#15/#28/#7)"
sentences were written pre-Wave-1 and are void per the 🛑 STOP block; the doc's own 2026-08-03 header
already says to consume the kit.

**The one sanctioned screen-local widget** is `OnboardingLanguageToggle` (public — two tests type-
assert it; field `selectedValue` kept). §5 #19 and `jeeb_segmented_toggle.dart`'s own doc name 01 as
the dark-on-navy exception, so the kit was **not** widened.

**Bespoke pieces (not kit candidates):** `_MarketplacePreview` + its three collage cards,
`_AccentRingsPainter` (a `CustomPaint`, not two positioned Ø380 boxes — `UnconstrainedBox` throws
debug overflow errors in widget tests), `_MarketplaceStage`, `_OnboardingSheet`, `_SlideCopy`.

**Frozen inventory — all preserved byte-identically:** `onboarding_root`, `walkthrough_slide_1/2/3`,
`onboarding_headline` (still bare flags), the `onboarding_next_button` → `walkthrough_next_cta` /
`walkthrough_get_started_cta` nesting (still `OmdsPrimaryButton`, restyled in place — no
`JeebCtaButton` swap), `walkthrough_skip_cta` on an unchanged `OmdsSkipButton`. Keys
`onboarding.pager`, `.illustration`, `.dots`, `.next`, `.getStarted`, `.skip`, `.languageToggle`
survive; `onboarding.slideCopy` and `onboarding.preview` are new. `OnboardingScreen`, the
`onComplete` seam, `_completeAndNavigate → goNamed('register')`, the `// ignore:
use_build_context_synchronously` and the whole `AnnotatedRegion` block are untouched.

**New identifiers:** `onboarding_wordmark`, `onboarding_language_toggle`, `onboarding_language_en`,
`onboarding_language_ar`, `onboarding_page_dots`.

---

## Verification actually performed

1. `dart analyze lib/features/onboarding/presentation test/onboarding_screen_test.dart` →
   **10 issues, all of them the as-if-granted wiring** (9 undefined `AppLocalizations` members +
   `DirectionalIcons.forward`). Zero lints, zero warnings, nothing else introduced.
2. **Real render check.** The wiring was applied locally *for a few minutes*, a throwaway golden
   harness rendered the screen at 390×844 with the real `AppTheme.light()` + Inter test fonts in
   both `en` and `ar`, and the PNGs were compared against `screens/01-onboarding.png`. Both locales
   `pumpAndSettle` clean — no overflow, no exception. RTL mirrors correctly: toggle → start,
   wordmark → end, collage cards flip sides, `Skip`/`Next` swap, and the CTA arrow becomes
   `Icons.arrow_back`. The temporary patch and the harness were then removed.
   - ⚠️ Mid-verification another lane rewrote `lib/l10n/app_{en,ar}.arb` +
     `app_localizations.dart` (adding `requestSummary*` keys), which dropped the temporary
     onboarding keys. **Nothing of mine remains in those files** — verified by grep — and their
     content was deliberately left as that lane wrote it (no stale backup was restored over it).
     `lib/core/widgets/directional_icons.dart` was restored byte-identically (diff clean).
3. `flutter test test/onboarding_screen_test.dart` — **not green yet, by construction**: the file
   cannot load until the l10n wiring lands (`_get` asserts on missing ARB keys and the getters do
   not exist). Expected under the as-if-granted contract.

---

## Deliberate deviations from the revised instruction set

| Item | Doc says | Shipped | Why |
|---|---|---|---|
| mic / dots / waveform / tier chip | "build inline (kit #N)" | kit widgets imported | 🛑 STOP block + the doc's own post-Wave-1 header; inline copies are a review defect |
| `_MicHero`, `_kMicDiameter`, `_kMicGlyphSize`, `_kDotActiveWidth` | new private class + consts | not created | `JeebMicHero.sizeLarge` / `JeebPageDots` defaults already carry those numbers; unused consts would be analyze noise |
| CTA `textStyle` | `context.jeebText.button` | `…button.copyWith(color: colorScheme.onPrimary)` | the ramp is ink-free by design, and `OmdsPrimaryButton` only applies its own `textColor` when `textStyle` is null — without the copyWith the label inherits body ink and goes near-black on the navy pill |
| new test asserting the frozen CTA/headline ids resolve | suggested | dropped (new-ids only) | `SemanticsConfiguration.absorb` keeps the **outer** identifier when the pair merges (`semantics.dart:6790`), so `find.bySemanticsIdentifier('walkthrough_next_cta')` would read the wrong node; those ids keep their existing `gesture_log_test` / Maestro contracts |

Everything else follows §C task-for-task.

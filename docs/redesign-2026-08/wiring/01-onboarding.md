# Wiring requests — 01 · Onboarding

The screen is written **as if these are already granted**. Until the integrator applies them,
`dart analyze lib/features/onboarding/presentation` reports exactly 10 errors (9 undefined l10n
members + `DirectionalIcons.forward`) and `test/onboarding_screen_test.dart` fails to load. Nothing
else in the screen is blocked.

### l10n
file: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart`
need: nine new keys for the rebuilt onboarding (AR brand eyebrow, decorative marketplace-preview copy, short toggle labels, dots a11y label) plus getters and one parameterized method.
exact change:

`app_en.arb` — add (append-only; `onboardingLanguageEnglish`/`…Arabic` STAY as orphans, warn-only):

```json
"onboardingTagline": "جيب لي أي شي",
"@onboardingTagline": {"description": "Brand slogan eyebrow above the onboarding headline; deliberately Arabic in both locales, like the wordmark."},
"onboardingPreviewVoiceDuration": "0:04",
"@onboardingPreviewVoiceDuration": {"description": "Decorative voice-note duration on the onboarding marketplace preview."},
"onboardingPreviewVoiceTranscript": "جيب لي دوا من الفرماشية",
"@onboardingPreviewVoiceTranscript": {"description": "Decorative Lebanese-Arabic voice transcript on the preview card; Arabic in both locales."},
"onboardingPreviewRequestTitle": "Groceries — Spinneys",
"@onboardingPreviewRequestTitle": {"description": "Decorative request title on the onboarding preview card."},
"onboardingPreviewOfferQuote": "\"I can bring it in 40 mins — $8\"",
"@onboardingPreviewOfferQuote": {"description": "Decorative Jeeber offer quote on the onboarding preview card."},
"onboardingPreviewOfferMeta": "Karim · ★ 4.9 · 3 km",
"@onboardingPreviewOfferMeta": {"description": "Decorative Jeeber name/rating/distance on the onboarding preview card; the star inherits the text ink."},
"onboardingLanguageEnShort": "EN",
"@onboardingLanguageEnShort": {"description": "Short EN segment label on the onboarding language toggle."},
"onboardingLanguageArShort": "عربي",
"@onboardingLanguageArShort": {"description": "Short Arabic segment label on the onboarding language toggle."},
"onboardingPageIndicator": "Step {current} of {total}",
"@onboardingPageIndicator": {"description": "Screen-reader label for the onboarding page dots.", "placeholders": {"current": {}, "total": {}}}
```

`app_ar.arb` — add:

```json
"onboardingTagline": "جيب لي أي شي",
"onboardingPreviewVoiceDuration": "0:04",
"onboardingPreviewVoiceTranscript": "جيب لي دوا من الفرماشية",
"onboardingPreviewRequestTitle": "بقالة — سبينيس",
"onboardingPreviewOfferQuote": "«بقدر جيبها بـ 40 دقيقة — 8$»",
"onboardingPreviewOfferMeta": "كريم · ★ 4.9 · 3 كم",
"onboardingLanguageEnShort": "EN",
"onboardingLanguageArShort": "عربي",
"onboardingPageIndicator": "الخطوة {current} من {total}"
```

`app_localizations.dart` — add next to the onboarding getters (after `onboardingSlide3Semantics`):

```dart
  String get onboardingTagline => _get('onboardingTagline');
  String get onboardingPreviewVoiceDuration =>
      _get('onboardingPreviewVoiceDuration');
  String get onboardingPreviewVoiceTranscript =>
      _get('onboardingPreviewVoiceTranscript');
  String get onboardingPreviewRequestTitle =>
      _get('onboardingPreviewRequestTitle');
  String get onboardingPreviewOfferQuote => _get('onboardingPreviewOfferQuote');
  String get onboardingPreviewOfferMeta => _get('onboardingPreviewOfferMeta');
  String get onboardingLanguageEnShort => _get('onboardingLanguageEnShort');
  String get onboardingLanguageArShort => _get('onboardingLanguageArShort');
  String onboardingPageIndicator(int current, int total) =>
      _get('onboardingPageIndicator')
          .replaceFirst('{current}', '$current')
          .replaceFirst('{total}', '$total');
```

why: the rebuilt screen renders the AR eyebrow, the decorative marketplace collage, the EN/عربي toggle segments and an a11y label on the page dots; identical EN/AR values are legal (the parity guard only forbids value == key). `onboardingPageIndicator` cannot be a plain getter — this app's l10n is a custom `_get(key)` map, so placeholders use the existing `replaceFirst` method pattern (`chatBroadcastTtlLabel`).

**Verified locally** (patch applied, screen rendered at 390×844 in `en` + `ar`, then reverted): these
exact values compile, parse and render; the ARB stayed valid JSON.

### cross-feature
file: `lib/core/widgets/directional_icons.dart`
need: a mirrored "forward" resolver so the Next → arrow points left under RTL.
exact change (inside `class DirectionalIcons`, after `backIos`):

```dart
  /// Forward/advance affordance: points left in RTL, right in LTR.
  static IconData forward(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_back : Icons.arrow_forward;
```

why: 01's primary CTA carries a trailing arrow (`html:52`); `Icon` never auto-mirrors and
`DirectionalIcons` currently has back/disclosure variants only. Verified locally: with this method
present the Arabic render draws `Icons.arrow_back` on the `Next` pill and the LTR render draws
`Icons.arrow_forward`.

### cross-feature
file: `lib/core/widgets/jeeb/` (Wave-1 kit lane — reconciliation notes, no kit file changes requested)
need: record that 01 now consumes the kit directly, and that two plan-vs-render conflicts resolved in the render's favour.
exact change: documentation only —
(a) `JeebPageDots`: plan §5 #28 says active 28×8 / gap 6; 01 (the only consumer) measures 22×8 /
gap 7 (`01-onboarding.html` tpl 51-54). The kit already ships the measured defaults and 01 consumes
them unchanged — the plan row is the stale one.
(b) `JeebWaveform`: plan §5 #14 maps 01 to `live` (~11 bars); 01's board mark is the 4-bar
`cardMark` (`html:24`) and 01 consumes `JeebWaveform.cardMark()`.
(c) `JeebCtaFooter.split` / `JeebMicHero.decorative` / `JeebTierChip`: consumed as-is, no API change
needed. 01 passes its frozen `OmdsSkipButton` into `leading` and `padding:
EdgeInsetsDirectional.zero` (the sheet owns the 32px gutters).
why: closes the "01 ships inline copies, swap in Wave 5" item — there are no inline kit copies in
this screen, so the Wave-5 sweep has nothing to do here.

*(No route, DI or theme requests — `/onboarding` already mounts this screen
(`app_router.dart:276,739-740`) and Wave 0 shipped every token this screen reads.)*

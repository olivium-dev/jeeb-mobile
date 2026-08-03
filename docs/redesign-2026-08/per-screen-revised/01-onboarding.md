# 01 · Onboarding — REVISED instruction set (authoritative)

**Target file:** `lib/features/onboarding/presentation/onboarding_screen.dart` (547 LOC).
**Verdict: rebuild** — confirmed. Every citation in the Opus proposal was checked against the
render, the HTML, the current source, the 13-test widget suite, the Maestro flows, the OMDS clone
and both plan documents. The structure inversion (full-bleed pager + scrim → three-band column
with an opaque sheet) is real and not reachable by restyling. Where this doc differs from the
proposal, this doc wins.

Wave 5 (entry + integration). **Update (2026-08-03, post-Wave-1): `lib/core/widgets/jeeb/` is now
BUILT.** Verified in-tree: `JeebMicHero.decorative` (default `sizeLarge = 118`, the `html:37`
two-shadow glow, no gesture and no semantics node of its own), `JeebPageDots` (defaults already
reconciled to 01's measured 22×8 / gap 7 — `jeeb_page_dots.dart:14-17,38-46`),
`JeebWaveform.cardMark` (4 bars, h 8/14/10/15, container h16; doc lists 01 as a consumer),
`JeebTierChip` (pill `surfaceContainerHigh`, `JeebTier.flash` = ⚡) and `JeebCtaFooter.split`
(arbitrary `leading`; its doc explicitly says 01 passes `OmdsSkipButton`). The earlier
"build inline, swap in Wave 5" instruction is **void — consume the kit directly** via
`import '../../../core/widgets/jeeb/<file>.dart';` (importing core widgets is fine; only *editing*
them needs wiring). Everything else stays in this one file — the feature has no
`presentation/widgets/` directory and the remaining bespoke widgets (collage cards, toggle,
sheet, rings painter) do not justify creating one.

---

## A. Deltas from the Opus proposal (audit trail — implementer follows THIS doc)

**Cut / overruled:**
1. **C3 "ship periwinkle body copy on white" — OVERRULED, not flagged.** Plan §4.1 is categorical:
   periwinkle is "NEVER body text on white (a contrast test asserts it fails AA — that guard
   stays)", and the 02-registration revision already enforced this as a locked rule, not a
   preference. The sheet's body copy inks `colorScheme.onSurfaceVariant` (#5C4038, 7.9:1).
   Periwinkle survives only *inside the decorative collage* (the `0:04` caption and the offer meta
   line — artwork behind an `image:true` semantics label, not body text) and on navy.
2. **`onboarding_headline` flag additions (`container: true, explicitChildNodes: true`) — CUT.**
   Keep `Semantics(identifier: 'onboarding_headline')` with exactly today's (absent) flags. The
   Maestro A33 probe resolves the id today without them; changing merge shape next to an E2E probe
   is risk with zero consumer.
3. **Replacing `OmdsPrimaryButton` with a kit `JeebCtaButton.primary` — CUT.** Verified:
   `OmdsPrimaryButton` already exposes `height`, `borderRadius` (defaults to `OmdsBorderRadius.pill`),
   `textStyle`, `icon` + `iconPosition: IconPosition.trailing` (`omds_primary_button.dart:42-55`).
   Keeping the widget type keeps the a11y merge behaviour around the
   `onboarding_next_button`/`walkthrough_next_cta` pair **byte-identical by construction** — the
   single riskiest surface on this screen (smoke.yaml taps the outer id, jm-006 taps the inner).
   Restyle it in place. `JeebCtaButton` (+ `mirrorIcons`) now exists in the kit, but the swap stays
   deferred to the Wave-5 sweep with an on-device Maestro pass — do not take it in this change.
4. **"01 cannot land before Wave-1 steps 4, 8 and 12" (risk 5) — RESOLVED.** Wave 1 landed; every
   kit widget 01 consumes exists. Land now, consuming them directly (see header note).
5. **Renames `_IllustrationCarousel`→pager / `_WalkthroughIllustration`→`_SlideArtwork` — CUT.**
   Keep both class names and their doc comments (the one-visible-slide comment on the carousel is
   load-bearing for jm-006 understanding). Only their internals change as specced below.
6. **C2 "owner decision" on the decorative mic — DOWNGRADED to settled.** Plan §6's screen-01 row
   already rules: "marketplace-preview collage is static/decorative — no invented live data". Build
   it decorative (`IgnorePointer` + `ExcludeSemantics` — the proposal missed the `IgnorePointer`;
   without it the Ø118 disc blocks swipe gestures over the bottom of the pager). No flag needed.

**Corrected (factually off in the proposal):**
1. `batch_08_entries.dart` lives at `lib/devtool/catalog/entries/batch_08_entries.dart` (the
   `onComplete: () {}` injection is at `:98`), not `features/dev_tools/…:63-88`. The seam
   constraint is unchanged.
2. `onboardingPageIndicator` **cannot be a plain getter** — this app's l10n is a custom
   `_get(key)` map (`app_localizations.dart:38`); placeholders need the existing
   `replaceFirst` method pattern (e.g. `chatBroadcastTtlLabel`, `:100-101`). Wiring request below
   ships it as `String onboardingPageIndicator(int current, int total)`.
3. Plan §5 #14 maps 01 to `JeebWaveform.live` (~11 bars). The board's actual 01 mark is the
   **4-bar cardMark** (`01-onboarding.html:24`: w3 r9 gap 2, h 7/13/9/14, accent, last bar α.4).
   Measured HTML wins (02-PLAN-ENHANCED's own principle). Build the 4-bar mark inline using the
   kit cardMark heights **8/14/10/15** so the Wave-5 swap is a no-op; the plan's consumer-mapping
   slip goes in the wiring note.
4. LTR isolation (proposal RTL §7.5) is overkill as written: `$8`, `4.9`, `3km` sit *inside*
   authored l10n strings and bidi handles embedded ASCII runs. The only standalone
   digit-leading string is `0:04` — give that one `Text` an explicit
   `textDirection: TextDirection.ltr`. Do not build span-level isolation.
5. Décor rings as two positioned `SizedBox` circles — replaced with a single
   `CustomPaint` (`_AccentRingsPainter`). An Ø380 fixed box inside the stage needs
   `OverflowBox`/`UnconstrainedBox` gymnastics, and `UnconstrainedBox` **throws debug overflow
   errors in widget tests**. A painter has no layout, no semantics, and the stage's `ClipRect`
   bounds it. Same geometry: two stroked circles, centre `(w/2, h*0.375)`, r190 @ accent α.10 and
   r135 @ accent α.18, strokeWidth 1.5.

**Verified true (kept, load-bearing):**
- The full §0 Semantics/key inventory, including the ⚠️ `_OnboardingCtaButton` outer/inner nesting
  rule — `gesture_log.dart:391-397` documents the pair by name; `gesture_log_test.dart:198-251`
  asserts the merge; `.maestro/smoke.yaml:31` taps the outer id; `jm-006:52,60` taps the inner.
- Wave 0 is done and present: `jeebRoles.accent` = `#D73B00` (`jeeb_color_roles.dart:73`),
  `JeebShadows.ctaNavy`/`.heroNavy` (`jeeb_shadows.dart:64,73`), all cited `jeebText` fields exist.
- The **do-not-bang rule is real**: `test/support/sync_app_localizations.dart` wraps every widget
  test in `ThemeData.light()` (no extensions). `context.jeebText` and `context.jeebRoles` are
  null-safe (`jeeb_text_styles.dart:211-213`, `jeeb_color_roles.dart:264-270`);
  `Theme.of(context).extension<JeebSemanticColors>()!` would crash all 13 tests. Use
  `colorScheme.onSecondaryContainer` for periwinkle (same `#777FC0`, `app_theme.dart:60,140`).
- `assets/brand/jeeb_logo.svg` exists, is declared (`pubspec.yaml:256`), and is the on-navy
  variant (white fills + `#D73B00` strokes — read the SVG).
- All cited test line numbers in §8 are accurate (`:97, :118, :189, :235, :253, :283, :299, :320`);
  the slide-2 test additionally asserts `find.descendant(of: illustration, matching:
  find.byType(Icon)) findsNothing` — safe, the mic lives outside the `onboarding.illustration`
  subtree.
- `DirectionalIcons` has `back/backIos/disclosure/disclosureIos` and **no `forward`** — wiring
  request below.
- C4 (white-card shadows on navy are a legitimate R7 exception → `JeebShadows.heroNavy`),
  C5 (Skip is legitimate; D56 is the mutual-rating screen only — `decision_violations_test.dart:90`
  confirms), C6 (sheet gutter 32), C7 (no `flex:1` spacer inside the sheet), C8 (no dark-mode
  invention), C1 (slides 2–3 keep their SVGs; do NOT invent two more collages), and the B04
  clarification (B04 is the *chat composer* mic ban, screen 21 — not in play here).
- `JeebPageDots` measured 22×8 / gap 7 vs plan's 28×8 / gap 6 (`html:45-48`) — real conflict, 01
  is the only consumer; build inline at measured values, reconcile via the wiring note.

---

## B. Frozen inventory — every one must survive byte-identical

| Semantics identifier | Today | After |
|---|---|---|
| `onboarding_root` | `:132` (container:true, wraps Scaffold) | unchanged wrapper |
| `walkthrough_slide_1/_2/_3` | `:248` (pager item, container:true) | unchanged, still in `_IllustrationCarousel.itemBuilder` |
| `onboarding_headline` | `:381` (bare, no flags) | moves to wrap `_SlideCopy` in the sheet — **same bare flags** |
| `onboarding_next_button` | `:452` (OUTER, bare) | unchanged |
| `walkthrough_next_cta` / `walkthrough_get_started_cta` | `:454-455` (INNER, `button:true`, slide-dependent) | unchanged |
| `walkthrough_skip_cta` | `:483` (`button:true`) | unchanged |

Widget keys: `onboarding.pager` (:242), `onboarding.illustration` (:275), `onboarding.dots`
(:396), `onboarding.next`/`onboarding.getStarted` (:458), `onboarding.skip` (:486),
`onboarding.languageToggle` (:522). Also frozen: the `OnboardingScreen` **class name**
(`fr_gating_first_run_test.dart` finds by type), the `onComplete` constructor seam (:59-65;
injected by `batch_08_entries.dart:98`, `onboarding_screen_test.dart:33`,
`batch_b_additional_ac_tests.dart:76`), `_completeAndNavigate` → `goNamed('register')` (:108,
DEFECT-3 — never `/sign-up`), the `// ignore: use_build_context_synchronously` at :107, the
`AnnotatedRegion` block (:121-130, a test at `:71` asserts its exact values), and Skip staying
`isA<OmdsSkipButton>` (test `:111-114`).

New identifiers (convention `onboarding_<element>`): `onboarding_wordmark` (image),
`onboarding_language_toggle` (container:true, explicitChildNodes:true, label:
`l10n.onboardingChooseLanguage`), `onboarding_language_en` / `onboarding_language_ar`
(button:true, selected:…), `onboarding_page_dots` (container:true, label:
`l10n.onboardingPageIndicator(current+1, total)`).
New keys: `onboarding.slideCopy`, `onboarding.preview`.

---

## C. Tasks — execute in order, no backtracking

Write all code **as if the wiring requests in §E are already granted** (l10n getters exist,
`DirectionalIcons.forward` exists). Use only: `colorScheme` roles, `context.jeebText`,
`context.jeebRoles`, `JeebShadows`, `Spacing`/`Sizes`/`OmdsBorderRadius` tokens. No raw `Color(0x…)`,
no `fontSize:` literals, no `BorderRadius.circular(<number>)` (token args are fine). Never read
`JeebSemanticColors` on this screen (§A).

### 1. File-private constants + `_OnboardingPage` flag

- Delete `_kVoiceFirstAsset` (:162) — slide 1 stops referencing it and an unused private const is
  an analyze warning. **Leave the SVG in `pubspec.yaml`** (Wave-0-frozen file; harmless bytes).
- Add to `_OnboardingPage`: `final bool showsMarketplacePreview;` (constructor default `false`;
  `sort_constructors_first`). Slide 1: `showsMarketplacePreview: true, asset: null`. Slides 2–3
  unchanged.
- New consts with one-line *why* comments: `_kMicDiameter = 118.0`, `_kMicGlyphSize = 54.0`,
  `_kDotActiveWidth = 22.0`, `_kSlideCopyMinHeight = 120.0` (replaces `OmdsWalkthroughSwitcher`'s
  fixed 170px box so the sheet height does not jump per swipe), `_kSheetMaxHeightFactor = 0.62`
  (200%-text-scale guard).

### 2. `_OnboardingTopBar` (new) + `OnboardingLanguageToggle` (new, public) — delete `_LanguageToggle` (:506-547)

Top bar (`html:13-19`): `SafeArea(bottom: false)` →
`Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.large, Spacing.xLarge, 0))` →
`Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)`:
- Wordmark: `Semantics(identifier: 'onboarding_wordmark', image: true, label:
  l10n.splashLogoSemantic, child: SvgPicture.asset('assets/brand/jeeb_logo.svg', height:
  Sizes.large))` (design h20 = token-exact). SVG must NOT mirror in RTL (SvgPicture never does).
- The toggle. Top bar watches the cubit and owns the callback:
  `OnboardingLanguageToggle(key: const Key('onboarding.languageToggle'), selectedValue:
  context.watch<LocaleCubit>().state.languageCode, onChanged: (code) =>
  context.read<LocaleCubit>().setLocale(Locale(code)))`.

`OnboardingLanguageToggle` — **public** (two tests type-assert it), field named **`selectedValue`**
(test `:336-340` reads it), `onChanged: ValueChanged<String>`. Plan §5 #19: this is the sanctioned
screen-local dark-on-navy variant — do NOT widen the kit. Spec (`html:15-18`):
- Track: `DecoratedBox(color: cs.onPrimary.withValues(alpha: 0.08), border:
  Border.all(color: cs.onPrimary.withValues(alpha: 0.16)), borderRadius: OmdsBorderRadius.pill)`,
  inner `Padding(EdgeInsets.all(Spacing.twoXSmall))`.
- Wrap in `Semantics(identifier: 'onboarding_language_toggle', container: true,
  explicitChildNodes: true, label: l10n.onboardingChooseLanguage)`.
- Two segments (`_kLangEn`/`_kLangAr` consts stay), each: `Semantics(identifier:
  'onboarding_language_en'|'onboarding_language_ar', button: true, selected: <isSelected>)` →
  `GestureDetector` → `AnimatedContainer(duration: UIConstants.animationNormal, padding:
  EdgeInsetsDirectional.symmetric(vertical: Spacing.twoXSmall, horizontal: Spacing.medium),
  borderRadius pill)`. Selected: fill `cs.onPrimary`, ink `cs.primary`; unselected: no fill, ink
  `cs.onPrimary.withValues(alpha: 0.75)`. Style `context.jeebText.bodySmall.copyWith(fontWeight:
  FontWeight.w700)`. Labels `l10n.onboardingLanguageEnShort` / `l10n.onboardingLanguageArShort`.
  Row order EN→عربي; the Row auto-mirrors under RTL — no manual flip.

### 3. The collage pieces (new): `_MarketplacePreview`, `_MicHero`, `_AccentRingsPainter`

`_MarketplacePreview` — root gets `key: const Key('onboarding.preview')`. `LayoutBuilder` →
`Stack` with three cards, tops as fractions of stage height h so they scale on short devices:

| Card | HTML (`:22-36`) | Build |
|---|---|---|
| A voice note | left 26, top 64, white, tail bottom-left, shadow | `PositionedDirectional(start: Spacing.xLarge, top: h * 0.10)`; `Container(constraints: BoxConstraints(maxWidth: Sizes.twoHundredLarge), padding: EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium, vertical: Spacing.small), decoration: color cs.surface, borderRadius: BorderRadiusDirectional.only(topStart/topEnd/bottomEnd: Radius.circular(Spacing.medium), bottomStart: Radius.circular(Spacing.twoXSmall)), boxShadow: JeebShadows.heroNavy)`. Content: `Row`[4-bar mark, `SizedBox(width: Spacing.xSmall)`, `Text(l10n.onboardingPreviewVoiceDuration, textDirection: TextDirection.ltr, style: caption.copyWith(fontWeight: w700, color: cs.onSecondaryContainer))`], gap `Spacing.twoXSmall`, `Directionality(textDirection: TextDirection.rtl, child: Text(l10n.onboardingPreviewVoiceTranscript, style: cardTitle.copyWith(color: cs.primary)))` |
| B request | right 22, top 158, white, tail bottom-right | `PositionedDirectional(end: Spacing.large, top: h * 0.25)`; same card decoration but tail on `bottomEnd`. Content: `Text(l10n.onboardingPreviewRequestTitle, style: body.copyWith(fontWeight: w700, color: cs.primary))`, gap `Spacing.twoXSmall`, tier chip: `Container(padding: EdgeInsetsDirectional.symmetric(horizontal: Spacing.xSmall, vertical: Spacing.threeXSmall), decoration: cs.surfaceContainerHigh + pill, child: Text('⚡ ${l10n.tierFlashTitle}', style: caption.copyWith(fontWeight: w700, color: cs.primary)))` (inline kit #7) |
| C offer | left 38, top 236, translucent, tail bottom-left, **no shadow** | `PositionedDirectional(start: Spacing.threeXLarge, top: h * 0.375)`; `Container(padding: EdgeInsetsDirectional.symmetric(horizontal: Spacing.small, vertical: Spacing.xSmall), decoration: color cs.onPrimary.withValues(alpha: 0.10), border: Border.all(color: cs.onPrimary.withValues(alpha: 0.18)), same tail radii as A)`. Content: `Text(l10n.onboardingPreviewOfferQuote, style: body.copyWith(fontWeight: w600, color: cs.onPrimary))`, gap `Spacing.threeXSmall`, `Text(l10n.onboardingPreviewOfferMeta, style: caption.copyWith(fontWeight: w700, color: cs.onSecondaryContainer))` — the ★ inherits that ink; **never tint it yellow** (plan §4.1) |

4-bar mark (inline kit #14 `cardMark`): `Row` of four `Container`s, width 3, heights **8/14/10/15**,
`borderRadius: OmdsBorderRadius.pill`, gap 2 (use `SizedBox(width: Spacing.threeXSmall)`), color
`context.jeebRoles.accent`, last bar `.withValues(alpha: 0.4)`.

`_MicHero` (inline kit #15, decorative mode): `Container(width/height: _kMicDiameter,
decoration: BoxDecoration(shape: BoxShape.circle, color: jeebRoles.accent, boxShadow: [
BoxShadow(color: accent.withValues(alpha: 0.18), spreadRadius: 10),
BoxShadow(color: accent.withValues(alpha: 0.5), offset: Offset(0, 18), blurRadius: 40)]),
child: Icon(Icons.mic, size: _kMicGlyphSize, color: jeebRoles.onAccent))` (`html:37`). No gesture,
no semantics — the callers wrap it (task 4).

`_AccentRingsPainter extends CustomPainter`: two stroked circles at `Offset(size.width / 2,
size.height * 0.375)`, radii 190 and 135, `PaintingStyle.stroke`, strokeWidth 1.5, colors
`accent.withValues(alpha: 0.10)` and `0.18` (`html:11-12` — deliberately NOT the α.30
`accentRing` token). `shouldRepaint` → false on equal color.

### 4. `_MarketplaceStage` (new) + rework `_WalkthroughIllustration` (:262-283)

`_MarketplaceStage(controller, pages, onPageChanged)`:
```
ClipRect                                  // MANDATORY: Ø380 ring on a 360dp device
└ Stack(children: [
    Positioned.fill(IgnorePointer(CustomPaint(painter: _AccentRingsPainter(...)))),
    _IllustrationCarousel(...),           // class kept verbatim except the item below
    Align(alignment: Alignment.bottomCenter,
      child: Padding(padding: EdgeInsetsDirectional.only(bottom: Spacing.xLarge),
        child: IgnorePointer(child: ExcludeSemantics(child: _MicHero())))),
  ])
```
The mic and rings are stage chrome, persistent across all three slides; only the pager page
changes. The `IgnorePointer` on the mic keeps swipes reaching the pager beneath it.

`_IllustrationCarousel` (:228-254): keep the class, the `Key('onboarding.pager')`, the
`walkthrough_slide_${i + 1}` Semantics and its doc comment **byte-identical**.

`_WalkthroughIllustration` (:262-283): delete the `ColoredBox` (:269-270 — it would paint over
the rings; the navy comes from the Scaffold). New body:
- if `page.showsMarketplacePreview`: `Semantics(key: const Key('onboarding.illustration'),
  image: true, label: page.semanticsLabel, child: ExcludeSemantics(child:
  LayoutBuilder(... _MarketplacePreview(...))))` — the `ExcludeSemantics` stops screen readers
  reading the decorative card texts after the label; the Semantics widget itself keeps today's
  exact key and properties (test `:202-206` asserts `image` + non-empty label).
- else: today's `Align(Alignment(0.0, -0.35))` + the same Semantics wrapper +
  `_IllustrationArtwork(page: page)` — `_IllustrationArtwork` (:287-314) is untouched.

### 5. The sheet: `_OnboardingSheet` + `_SlideCopy` + `_PageDots` (new) — delete `_BottomScrim` (:319-345) and `_BottomPanel` (:349-419)

```
_OnboardingSheet(pages, currentPage, onNext, onSkip, onGetStarted)
└ DecoratedBox(color: cs.surface,
    borderRadius: BorderRadius.vertical(top: Radius.circular(Spacing.twoXLarge)))  // 32 vs 36: no token
  └ SafeArea(top: false)
    └ ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * _kSheetMaxHeightFactor)
      └ SingleChildScrollView(physics: ClampingScrollPhysics())   // never scrolls at 1.0x
        └ Padding(EdgeInsets.all(Spacing.twoXLarge))              // html:41 pad 32/32/28
          └ Column(mainAxisSize: min, crossAxisAlignment: stretch, [
              Semantics(identifier: 'onboarding_headline', child: _SlideCopy(...)),  // BARE flags
              SizedBox(height: Spacing.medium),
              _PageDots(key: Key('onboarding.dots'), currentIndex, itemCount),
              SizedBox(height: Spacing.large),
              Row([ _OnboardingSkipButton(label: l10n.onboardingSkip, onTap: onSkip),
                    SizedBox(width: Spacing.small),
                    Expanded(_OnboardingCtaButton(...)) ]),       // split footer, html:50-53
            ])
```

`_SlideCopy` — root gets `key: const Key('onboarding.slideCopy')`, then
`ConstrainedBox(minHeight: _kSlideCopyMinHeight)` around
`AnimatedSwitcher(duration: UIConstants.animationNormal, <fade>)` whose child is
`Column(key: ValueKey(currentPage))`:
1. AR eyebrow: `Directionality(textDirection: TextDirection.rtl, child:
   Text(l10n.onboardingTagline, textAlign: TextAlign.center, style:
   context.jeebText.titleProminent.copyWith(color: context.jeebRoles.accent)))` (html:42, 16/w700
   orange; token 17/w700, +1 accepted).
2. `SizedBox(height: Spacing.twoXSmall)`.
3. `OmdsWalkthroughStep(label: page.title, description: page.body, labelStyle:
   context.jeebText.h1.copyWith(letterSpacing: -0.6, color: cs.primary), descriptionStyle:
   context.jeebText.body.copyWith(color: cs.onSurfaceVariant))` — keeps
   `find.byType(OmdsWalkthroughStep)` green (verified: the Step forwards both styles,
   `omds_walkthrough_step.dart:22-24`; it is the *Switcher* that cannot). Headline 24/w700 vs
   design 27 — accepted (R3: heavier, not bigger). Body ink is `onSurfaceVariant`, NOT periwinkle
   (§A cut 1). Defaults for `textAlign` (center) and `spacing` (8) are already right — pass nothing.

`_PageDots` (inline kit #28, measured values): `Semantics(identifier: 'onboarding_page_dots',
container: true, label: l10n.onboardingPageIndicator(currentIndex + 1, itemCount), child:
Row(mainAxisAlignment: center))` of `AnimatedContainer(duration: UIConstants.animationNormal,
width: active ? _kDotActiveWidth : Spacing.xSmall, height: Spacing.xSmall, borderRadius pill,
color: active ? jeebRoles.accent : cs.surfaceContainerHighest)`, separated by
`SizedBox(width: Spacing.xSmall)` (design gap 7 → token 8). Plain Row = correct RTL for free
(test `:136` reads `Directionality` at this key).

`_OnboardingCtaButton` (:432-466) — **keep the class and BOTH Semantics wrappers byte-identical**
(outer `onboarding_next_button`, inner slide-flipping id, `button: true`, no container flags —
`gesture_log.dart` rule). Changes are inside the inner Semantics only: wrap the button in
`DecoratedBox(decoration: BoxDecoration(borderRadius: OmdsBorderRadius.pill, boxShadow:
JeebShadows.ctaNavy))` (board-exact `0 10 24 rgba(11,19,81,.28)`), and pass to the existing
`OmdsPrimaryButton`: `height: Sizes.fiveXLarge` (56 board-exact), `textStyle:
context.jeebText.button`, `icon: Icon(DirectionalIcons.forward(context), size: Sizes.large,
color: cs.onPrimary)`, `iconPosition: IconPosition.trailing` (mirrors via the Row's
directionality). Keep `key`, `text`, `onTap`, `width: double.infinity` as they are. Same arrow on
both Next and Get Started (board draws slide 1 only; a state-dependent glyph is invention).

`_OnboardingSkipButton` (:474-493) — **unchanged** (type, key, identifier, padding). Board ink
`#5C4038` = whatever `OmdsSkipButton` resolves; do not fork it for a text style.

### 6. Rewire `build()` (:112-158) and update the class doc comment

Keep `:121-133` byte-identical (`AnnotatedRegion` + `Semantics(onboarding_root)`). Replace the
`Stack` body:
```dart
child: Scaffold(
  backgroundColor: colorScheme.secondaryContainer,
  body: Column(children: [
    const _OnboardingTopBar(),
    Expanded(child: _MarketplaceStage(
      controller: _pageController, pages: pages,
      onPageChanged: (i) => setState(() => _currentPage = i))),
    _OnboardingSheet(pages: pages, currentPage: _currentPage,
      onNext: () => _onNext(pages.length),
      onSkip: _completeAndNavigate, onGetStarted: _completeAndNavigate),
  ]),
),
```
Delete `_BottomScrim`, `_BottomPanel`, `_LanguageToggle` classes and their call sites. `_onNext` /
`_completeAndNavigate` (:81-110) untouched.

Doc comment (:12-57): rewrite ONLY the structure paragraph (¶1-2) and the slide-artwork paragraph
(¶4) to describe the three-band column, the collage on slide 1 and the top-bar toggle — keep them
short. Keep the DEFECT-3 destination paragraph and the Semantics-contract paragraph **verbatim**.

Add the one new import: `../../../core/widgets/directional_icons.dart` (importing core widgets is
fine; only *editing* them needs wiring).

### 7. Update the screen's own tests (`test/onboarding_screen_test.dart` — this lane owns it)

Mechanical edits (6 tests, none weakened):
1. `:97` — swap `find.byType(OmdsWalkthroughSwitcher)` (`:104`) for
   `find.byKey(const Key('onboarding.slideCopy'))`. Keep the `OmdsWalkthroughStep`, pager,
   illustration and `OmdsSkipButton` assertions.
2. `:183-187` — scope the helper: `tester.widget<SvgPicture>(find.descendant(of:
   find.byKey(const Key('onboarding.illustration')), matching: find.byType(SvgPicture)))` (the
   wordmark is a second SvgPicture now).
3. `:189` — rewrite: slide 1 renders `find.byKey(const Key('onboarding.preview'))` and no
   descendant SvgPicture under `onboarding.illustration`; keep the `image: true` + non-empty-label
   assertions (`:202-206`).
4. `:283` — `isA<OnboardingLanguageToggle>()`; `find.text('EN')` / `find.text('عربي')`.
5. `:299` — tap `find.text('عربي')` (or `find.bySemanticsIdentifier('onboarding_language_ar')`).
6. `:320` — `tester.widget<OnboardingLanguageToggle>(…).selectedValue` (field name kept, one-word
   type swap).

`:235` and `:253` (slides 3/2) need no edit beyond the shared helper fix in (2) — their
descendant-scoped SVG/Icon assertions still hold. `:59, :71, :118, :142, :159, :208` stay
untouched and green.

Add (additive only): the five new identifiers resolve; slide 1 shows `onboarding.preview` while
slides 2–3 show their SVGs; RTL smoke under `Locale('ar')` — the CTA glyph is `Icons.arrow_back`
and the toggle still works; 200% `textScaler` pump throws no exceptions and `onboarding.next` is
still tappable. Expected net: 6 edited, 4 added, 0 removed.

### 8. Write the wiring file and gate

Write §E verbatim to `docs/redesign-2026-08/wiring/01-onboarding.md`. Then:
- `flutter analyze` — bar: nothing beyond the pre-existing baseline (11 issues / 6 errors: 2×
  `Semantics identifier` + 4× `DioExceptionType.transformTimeout`). Do not fix those.
- `flutter test test/onboarding_screen_test.dart test/features/batch_b_additional_ac_tests.dart
  test/core/router/fr_gating_first_run_test.dart test/core/diagnostics/gesture_log_test.dart` —
  the widget tests go green only after the integrator applies the l10n wiring (`_get` asserts on
  missing ARB keys). Expected under the as-if-granted contract; say so in the hand-off.
- Visual pass: compare against `screens/01-onboarding.png` at the same scale. The stage is
  *supposed* to be ~45% empty — do NOT scale the cards up to fill it (plan risk #13).

---

## D. Stop conditions

**Done means:** all seven identifiers and six keys in §B emitted, spelled identically, CTA
nesting byte-identical; three-band layout (wordmark+toggle / navy stage with rings+collage+mic /
opaque white r32 sheet with eyebrow→headline→body→dots→split footer); scrim and `ColoredBox`
gone; slide 1 = collage, slides 2–3 = their existing SVGs; all orange through
`context.jeebRoles.accent`; sheet body ink `onSurfaceVariant`; analyze delta zero; test delta
exactly §C-7; wiring file written.

**Do NOT touch:** `lib/core/onboarding/onboarding_cubit.dart` and `lib/core/locale/locale_cubit.dart`
(consumed, not edited); `lib/core/router/*`, `lib/core/di/*`, `lib/core/theme/*`,
`lib/core/widgets/*` (wiring request only), `lib/l10n/*` (arb AND `app_localizations.dart`),
`pubspec.yaml`, OMDS, `.maestro/`, `tool/`, `lib/devtool/`, any other feature. Do not: make the
mic tappable or give it semantics; invent slide-2/3 collages; re-point Skip/Get Started anywhere
but `goNamed('register')`; add `readTick`/cyan anywhere; tint the ★ yellow; use
`JeebSemanticColors` with a `!`; rename `OnboardingScreen`; remove `onboarding_voice_first.svg`
from pubspec; add a dark-mode treatment; add `container:`/`explicitChildNodes:` to
`onboarding_headline` or the CTA pair.

---

## E. Wiring requests — final text, ready to paste into `docs/redesign-2026-08/wiring/01-onboarding.md`

### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: nine new keys for the rebuilt onboarding (AR brand eyebrow, decorative marketplace-preview copy, short toggle labels, dots a11y label) plus getters and one parameterized method.
exact change:
app_en.arb — add (append-only; `onboardingLanguageEnglish`/`…Arabic` STAY as orphans, warn-only):
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
app_ar.arb — add:
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
app_localizations.dart — add next to the onboarding getters (`:388-396`):
```dart
String get onboardingTagline => _get('onboardingTagline');
String get onboardingPreviewVoiceDuration => _get('onboardingPreviewVoiceDuration');
String get onboardingPreviewVoiceTranscript => _get('onboardingPreviewVoiceTranscript');
String get onboardingPreviewRequestTitle => _get('onboardingPreviewRequestTitle');
String get onboardingPreviewOfferQuote => _get('onboardingPreviewOfferQuote');
String get onboardingPreviewOfferMeta => _get('onboardingPreviewOfferMeta');
String get onboardingLanguageEnShort => _get('onboardingLanguageEnShort');
String get onboardingLanguageArShort => _get('onboardingLanguageArShort');
String onboardingPageIndicator(int current, int total) =>
    _get('onboardingPageIndicator')
        .replaceFirst('{current}', '$current')
        .replaceFirst('{total}', '$total');
```
why: the rebuilt screen renders the AR eyebrow, the decorative marketplace collage, the EN/عربي toggle segments and an a11y label on the page dots; identical EN/AR values are legal (the parity guard only forbids value == key).

### cross-feature
file: lib/core/widgets/directional_icons.dart
need: a mirrored "forward" resolver so the Next → arrow points left under RTL.
exact change (inside `class DirectionalIcons`, after `backIos`):
```dart
  /// Forward/advance affordance: points left in RTL, right in LTR.
  static IconData forward(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_back : Icons.arrow_forward;
```
why: 01's primary CTA carries a trailing arrow (`html:52`); `Icon` never auto-mirrors and `DirectionalIcons` currently has back/disclosure variants only.

### cross-feature
file: lib/core/widgets/jeeb/ (Wave-1 kit lane — reconciliation notes, no app file changes yet)
need: reconcile three kit specs with 01's measured board values before the Wave-5 swap.
exact change: (a) `JeebPageDots`: plan §5 #28 says active 28×8 / gap 6, but 01 — the only consumer — measures active 22×8 / gap 7 (`01-onboarding.html:45-48`); 01 ships inline at 22×8. (b) `JeebWaveform`: plan §5 #14 maps 01 to `live` (~11 bars); 01's board mark is the 4-bar `cardMark` (`html:24`) and ships inline with cardMark heights 8/14/10/15. (c) `JeebCtaFooter.split`: the leading slot must accept an arbitrary widget — 01 must pass its existing `OmdsSkipButton` (a test pins the type). (d) `JeebMicHero`: needs the decorative/non-interactive mode with the Ø118 two-shadow glow `0 0 0 10 rgba(215,59,0,.18)` + `0 18 40 rgba(215,59,0,.5)` (`html:37`).
why: the Wave-5 kit swap on this screen must be a behavioural and visual no-op.

*(No route, DI or theme requests — `/onboarding` already mounts this screen (`app_router.dart:276,739-740`) and Wave 0 shipped every token this screen reads.)*

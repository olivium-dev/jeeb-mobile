# Screen 01 — Onboarding · change proposal

- **Design:** `docs/redesign-2026-08/screens/01-onboarding.{png,html,note.md}`
- **File to edit:** `lib/features/onboarding/presentation/onboarding_screen.dart` (547 LOC)
  — confirmed live: `lib/features/onboarding/onboarding_screen.dart` is a 9-line re-export and
  `app_router.dart:91` imports *that*, so the presentation file is what `/onboarding` mounts.
  The map (`screen-repo-map.md:50`) is correct for this screen; no trap here.
- **Wave:** 5 (entry + integration). Depends on Wave-1 kit items #2, #7, #14, #15, #28.
- **Verdict: `rebuild`.** The token layer is a restyle, but the *structure* inverts: today a
  full-bleed `PageView` with a gradient scrim and floating copy; the board is a hard three-band
  column (top bar / navy stage / opaque white sheet). The scrim dies, the sheet is opaque, and the
  pager stops being full-bleed. That is not reachable by restyling.

---

## 0. Semantics inventory (frozen — grep result, all must survive)

`grep -rn "identifier:" lib/features/onboarding/` →

| Identifier | Current home | Consumers |
|---|---|---|
| `onboarding_root` | `:132` (Semantics around Scaffold) | — |
| `walkthrough_slide_1` / `_2` / `_3` | `:248` (per-page container) | `.maestro/flows/jm-006-splash-routing.yaml:45,56,64` |
| `onboarding_headline` | `:381` (wraps `OmdsWalkthroughSwitcher`) | `.maestro/jeeb/INDEX.md:63` (A33 semantics probe) |
| `onboarding_next_button` | `:452` (OUTER of the CTA pair) | `.maestro/smoke.yaml:31`; `test/core/diagnostics/gesture_log_test.dart:198,208,220,229,241` |
| `walkthrough_next_cta` | `:455` (INNER, slides 1–2) | `jm-006:52,60`; `gesture_log_test.dart:199,212,250` |
| `walkthrough_get_started_cta` | `:455` (INNER, last slide) | `jm-006:68` |
| `walkthrough_skip_cta` | `:483` | — (coined, JM-010 §2.2/§4) |

Non-identifier keys that tests assert and must also survive: `onboarding.pager` (:242),
`onboarding.illustration` (:275), `onboarding.dots` (:396), `onboarding.next` /
`onboarding.getStarted` (:458), `onboarding.skip` (:486), `onboarding.languageToggle` (:522).

⚠️ **`_OnboardingCtaButton`'s Semantics nesting (`:451-456`) must stay byte-identical** — outer
`onboarding_next_button`, inner slide-dependent id, **no** `container:`/`explicitChildNodes:` flags.
`lib/core/diagnostics/gesture_log.dart:394-395` documents this exact outer/inner pairing by name and
five assertions in `gesture_log_test.dart` depend on the merge behaviour. Adding
`explicitChildNodes: true` here would un-merge the pair and is a silent E2E break.

---

## 1. Layout & structure

### 1.1 The new skeleton

The HTML root (`01-onboarding.html:10`) is `display:flex; flex-direction:column` over a navy field
with three bands: header → `flex:1` stage → sheet. Replace the `Stack` at `:136-152`.

```
Semantics(identifier: 'onboarding_root', container: true)
└ Scaffold(backgroundColor: cs.secondaryContainer)
  └ Column
    ├ _OnboardingTopBar            // NEW  (wordmark + on-navy language toggle)
    ├ Expanded(child: _MarketplaceStage)   // rings + PageView + decorative mic
    └ _OnboardingSheet             // NEW  (opaque white, top radius, copy + dots + footer)
```

**Deleted**
- `_BottomScrim` (`:319-345`) — the sheet is opaque `#FFFFFF` (`html:41`), a gradient fade over the
  artwork no longer exists. Delete the class outright.
- The root `Stack` (`:136`) and the `Align`-over-`Stack` positioning of `_BottomPanel` /
  `_LanguageToggle`. The board is a column; overlap is gone.
- `ColoredBox(color: cs.secondaryContainer)` inside `_WalkthroughIllustration` (`:269-270`) — it
  would paint over the accent rings that now sit behind the pager.
- The `IgnorePointer` around the copy (`:376`). Its only purpose was letting swipes reach the pager
  through the floating copy; the copy is no longer over the pager.

**Added**
- `_OnboardingTopBar` — `SafeArea(bottom: false)` + `Padding(EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge, Spacing.large, Spacing.xLarge, 0))` (design `18/24/0`; 18→20 rounded to the
  nearest token, §4.3) + `Row(mainAxisAlignment: spaceBetween)`.
- `_MarketplaceStage` — `ClipRect(child: Stack(...))`. **The `ClipRect` is load-bearing**: `html:11`
  sets `overflow:hidden` on the frame and the outer décor ring is Ø380 on a 440 canvas; without the
  clip it paints over the header and the sheet on narrow devices.
- `_OnboardingSheet` — opaque `cs.surface`, top radius, `padding 32/32/28`.

### 1.2 The stage (`html:21-40`)

`Stack` children, back to front:

1. **`_AccentRings`** — two concentric stroked circles, centre at `Alignment(0, -0.25)` of the
   stage. Ø380 · 1.5px · accent @ **10%** (`html:11`); Ø270 · 1.5px · accent @ **18%** (`html:12`).
   Note these are **not** `JeebSemanticColors.accentRing` (which is 30%) — see §2.
2. **The pager** — `PageView.builder(key: const Key('onboarding.pager'))`, unchanged item count and
   `onPageChanged`. Each item stays wrapped in
   `Semantics(identifier: 'walkthrough_slide_${i + 1}', container: true, child: _SlideArtwork(...))`.
3. **`JeebMicHero`** (kit #15) — `Align(bottomCenter)` + bottom padding `Spacing.xLarge` (design 26).
   Ø118 orange disc, 54px white mic, glow stack `0 0 0 10 rgba(215,59,0,.18)` +
   `0 18 40 rgba(215,59,0,.5)` (`html:37`). **Decorative, non-interactive** (see §9-C2).

The mic and the rings are **stage chrome — persistent across all three slides**. Only layer 2
changes with the page.

### 1.3 The per-slide artwork — and the one honest gap

`_SlideArtwork` keeps today's resilient-fallback idiom (`:287-314`) but inverts which branch is
"real":

- **Slide 1** renders `_MarketplacePreview` — the three floating cards, pixel-derived from
  `html:22-36`. This is the designer's "live marketplace preview".
- **Slides 2 and 3** keep `SvgPicture.asset(onboarding_trusted_jeebers.svg / _live_tracking.svg)`
  on the same navy stage.

**The board draws only slide 1.** There is no design for a slide-2 or slide-3 preview collage, and
composing two more of them is the lane inventing brand artwork. Refused — flagged as a designer
gap (§9-C1). `onboarding_voice_first.svg` becomes unreferenced; **leave it in `pubspec.yaml`**
(removing it is a Wave-0-owned file edit for zero benefit).

Both branches stay wrapped in the existing
`Semantics(key: const Key('onboarding.illustration'), image: true, label: page.semanticsLabel)`
(`:274-278`) so the key survives on every slide. `_OnboardingPage.semanticsLabel` for slide 1
(`onboardingSlide1Semantics`, "a person speaks a delivery request into the Jeeb app") still
describes the preview accurately — **no new key needed**.

Card geometry (positions are fractions of the stage height, taken from the mock's ~630px stage, so
they scale instead of colliding with the mic on a 640-tall device — use `LayoutBuilder`):

| Card | HTML | Flutter |
|---|---|---|
| A · voice note | `left 26, top 64`, max-w 200 | `PositionedDirectional(start: Spacing.xLarge, top: h * 0.10)`, `ConstrainedBox(maxWidth: Sizes.twoHundredLarge)` |
| B · request | `right 22, top 158` | `PositionedDirectional(end: Spacing.large, top: h * 0.25)` |
| C · offer | `left 38, top 236` | `PositionedDirectional(start: Spacing.threeXLarge, top: h * 0.375)` |

### 1.4 The sheet (`html:41-54`)

```
_OnboardingSheet
└ DecoratedBox(color: cs.surface,
    borderRadius: BorderRadius.vertical(top: Radius.circular(Spacing.twoXLarge)))
  └ SafeArea(top: false)
    └ ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * 0.62)
      └ SingleChildScrollView(physics: ClampingScrollPhysics())
        └ Padding(EdgeInsetsDirectional.all-32)
          └ Column(mainAxisSize: min, crossAxisAlignment: stretch)
            ├ Semantics(identifier: 'onboarding_headline', child: _SlideCopy)
            ├ SizedBox(height: Spacing.medium)          // design 18
            ├ JeebPageDots(key: Key('onboarding.dots'))
            ├ SizedBox(height: Spacing.large)           // design 20
            └ JeebCtaFooter.split(leading: <Skip>, action: <Next>)
```

The `ConstrainedBox` + `SingleChildScrollView` is the 200%-text-scale guard (DoD). The design has
no scroll; at 1.0× it never scrolls.

`_SlideCopy` replaces `OmdsWalkthroughSwitcher` (see §3):

```
AnimatedSwitcher(duration: UIConstants.animationNormal, fade)
└ Column(key: ValueKey(currentPage), children: [
    Directionality(rtl, Text(l10n.onboardingTagline))    // AR eyebrow, orange
    SizedBox(height: Spacing.twoXSmall)                  // design 6
    OmdsWalkthroughStep(label: page.title, description: page.body,
      textAlign: center, labelStyle: ..., descriptionStyle: ...,
      spacing: Spacing.xSmall)                           // design 9
  ])
```

Give the `AnimatedSwitcher` child a `ConstrainedBox(minHeight: _kSlideCopyMinHeight)` (a named
file-private const ≈ 120) — the old `OmdsWalkthroughSwitcher` reserved a fixed 170px box, and
without a floor the sheet height (and therefore the stage, and therefore the floating cards) jumps
on every swipe.

---

## 2. Tokens — every hardcoded value and where it goes

Nothing in this file is a raw `Color(0x…)` today, but almost everything is *semantically* wrong
(navy via `secondaryContainer`, copy via stock `displaySmall`). Target values:

| Design (HTML) | Value | Flutter token |
|---|---|---|
| stage / screen field | `--jeeb-navy #0B1351` | `cs.secondaryContainer` (already used at `:135`) — keep |
| sheet fill | `#FFFFFF` | `cs.surface` |
| sheet top radius | `36 36 0 0` | `BorderRadius.vertical(top: Radius.circular(Spacing.twoXLarge))` → **32** (nearest token; §4.4 has no 36) |
| headline ink | `--jeeb-navy` | `cs.primary` |
| body / meta ink | `--jeeb-periwinkle #777FC0` | **`cs.onSecondaryContainer`** — same hex as `JeebSemanticColors.mutedText`, and null-safe (see the ⚠️ below) |
| `Skip` ink | `--jeeb-brown-subtitle #5C4038` | `cs.onSurfaceVariant` |
| AR eyebrow, mic, dots-active, waveform | `--jeeb-orange #D73B00` | `context.jeebRoles.accent` |
| décor ring outer / inner | `rgba(215,59,0,.10)` / `.18` | `context.jeebRoles.accent.withValues(alpha: 0.10 / 0.18)` — **not** `accentRing` (that is fixed at 30%) |
| Flash chip fill | `--jeeb-surface-high #EAE7EB` | `cs.surfaceContainerHigh` (inside `JeebTierChip`) |
| inactive page dot | `--jeeb-surface-highest #E5E1E5` | `cs.surfaceContainerHighest` (inside `JeebPageDots`) |
| white-on-navy ink & overlays | `#FFF`, `rgba(255,255,255,.08/.10/.16/.18/.75)` | `cs.onPrimary.withValues(alpha: …)` (§4.1 maps `--jeeb-white` → `onPrimary`) |
| white card shadow | `0 12 26 rgba(0,0,0,.3)` | **`JeebShadows.heroNavy`** (`0 12 28 rgba(11,19,81,.30)`) — same geometry, navy instead of black; on a navy field the difference is imperceptible and it avoids a raw color |
| Next-pill shadow | `0 10 24 rgba(11,19,81,.28)` | `JeebShadows.ctaNavy` |
| mic glow | `0 0 0 10 rgba(215,59,0,.18)` + `0 18 40 rgba(215,59,0,.5)` | parameter of `JeebMicHero` (kit-internal) |

Type — all via `context.jeebText` (`fontSize:` literals are banned in `lib/features`):

| Element | Design | Ramp field | Delta |
|---|---|---|---|
| AR eyebrow | 16 / w700 | `titleProminent` (17/w700) + `color: jeebRoles.accent` | +1 |
| EN headline | 27 / w700 / ls −0.6 | `h1` (24/w700) `.copyWith(letterSpacing: -0.6, color: cs.primary)` | **−3, accepted** (R3: no ramp entry between 24 and 38; "make it heavier, not bigger") |
| body | 15 / 22 / w500 | `body` (13.5/w500, 19px line) + `cs.onSecondaryContainer` | **−1.5, accepted** |
| `Skip` | 15.5 / w600 | `cardTitle.copyWith(fontWeight: w600, color: cs.onSurfaceVariant)` | **exact** |
| `Next` | 17 / w600 | `button` | exact |
| toggle segments | 12.5 / w700 | `bodySmall.copyWith(fontWeight: w700)` | −0.5 |
| voice duration `0:04` | 11 / w700 | `caption.copyWith(fontWeight: w700)` | +0.5 |
| AR transcript | 14.5 / w700 | `cardTitle` (15.5/w700) | +1 |
| `Groceries — Spinneys` | 13.5 / w700 | `body.copyWith(fontWeight: w700)` | **exact** |
| offer quote | 13 / w600 | `body.copyWith(fontWeight: w600, color: cs.onPrimary)` | +0.5 |
| offer meta | 11 / w700 | `caption.copyWith(fontWeight: w700)` | +0.5 |

⚠️ **Do NOT read `JeebSemanticColors` on this screen.** The plan's idiom is
`Theme.of(context).extension<JeebSemanticColors>()!` — a bang. `test/support/sync_app_localizations.dart:41`
wraps every onboarding widget test in `theme: ThemeData.light()`, where that extension is **absent**,
so the bang would null-crash all 13 tests. `cs.onSecondaryContainer` carries the identical
`#777FC0` and `context.jeebText` / `context.jeebRoles` both have null-safe fallbacks
(`jeeb_text_styles.dart:211`, `jeeb_color_roles.dart:268`).

Radii — no raw `BorderRadius.circular(N)` anywhere:
- bubble tails: `BorderRadiusDirectional.only(topStart: Radius.circular(Spacing.medium), topEnd: …,
  bottomEnd: …, bottomStart: Radius.circular(Spacing.twoXSmall))` (16/16/16/4 → card A and C;
  card B swaps the 4 to `bottomEnd`).
- pills: `OmdsBorderRadius.pill`.

---

## 3. Shared components this screen consumes

| Kit widget (§5) | Replaces | Notes for the kit owner |
|---|---|---|
| **#28 `JeebPageDots`** | `OmdsDotIndicator` (`:395-399`) | `OmdsDotIndicator` renders `shape: BoxShape.circle` and a single `activeSize` diameter — it **cannot** draw the 22×8 pill. 01 is the widget's only consumer, and the measured values here are **active 22×8, gap 7** (`html:45-48`), not the plan's "28×8, gap 6". Ask the kit owner to adopt 22×8 / gap 7. Keep `key: const Key('onboarding.dots')` on it. |
| **#2 `JeebCtaFooter.split` + `JeebCtaButton.primary`** | `_BottomPanel`'s CTA + Skip stack (`:400-412`) | The footer must accept an arbitrary `leading` **widget** — 01 has to pass the existing `OmdsSkipButton` (a test pins its type), not the kit's own text button. `JeebCtaButton.primary` needs `trailingIcon` and must mirror it in RTL. |
| **#15 `JeebMicHero`** | net-new | Needs a **decorative/non-interactive** mode (no `onPressStart/End`) and the Ø118 two-shadow glow from `html:37`. |
| **#14 `JeebWaveform.cardMark`** | net-new | 01's bars are `h 7/13/9/14` (`html:24`) vs the kit spec's `8/14/10/15` — inside tolerance, use the kit value; do not fork. |
| **#7 `JeebTierChip`** | net-new | `⚡ Flash` on the preview request card. Label from the existing `l10n.tierFlashTitle`. |
| **#19 `JeebSegmentedToggle`** — *screen-local variant* | `_LanguageToggle` / `OmdsFilterChips` (`:506-547`) | §5 #19 already says "01 uses a screen-local dark-on-navy variant" — build it in this file as `OnboardingLanguageToggle` (public, so the test can type-assert), do **not** widen the kit. |

**Not** consumed: `JeebOutlinedCard` / `JeebNavySurfaceCard` (the preview cards are white-on-navy
floating bubbles with asymmetric tails, not list cards); `JeebTopBar` (01 has a wordmark, not a
title + back circle); `JeebInfoNote`.

---

## 4. New functionality & what the state layer needs

**Nothing.** This is the one screen on the board with zero new data needs.

- The preview collage is **static and decorative** — plan §6 Wave 5: "marketplace-preview collage is
  static/decorative — no invented live data". Its strings are l10n constants, not offers.
- `OnboardingCubit` (complete/persist) and `LocaleCubit` (setLocale) are unchanged. No new cubit, no
  new state field, no new repository, no gateway call.
- The `onComplete` constructor seam (`:59-65`) is preserved verbatim (§7.4 — the devtool catalog
  `batch_08_entries.dart:63-88` and 3 tests inject it).
- Destination is unchanged: `context.goNamed('register')` (`:108`). **Do not** re-point Skip / Get
  Started at `/sign-up` — that funnel was removed in JEBV4-199 (Q-044 RATIFIED).

New l10n keys (integrator batch — EN key + `@description` + real AR + `_get` getter):

| Key | EN value | AR value |
|---|---|---|
| `onboardingTagline` | `جيب لي أي شي` | `جيب لي أي شي` (brand slogan — deliberately Arabic in both locales, like the wordmark) |
| `onboardingPreviewVoiceDuration` | `0:04` | `0:04` |
| `onboardingPreviewVoiceTranscript` | `جيب لي دوا من الفرماشية` | same |
| `onboardingPreviewRequestTitle` | `Groceries — Spinneys` | `بقالة — سبينيس` |
| `onboardingPreviewOfferQuote` | `"I can bring it in 40 mins — $8"` | `«بقدر جيبها بـ 40 دقيقة — 8$»` |
| `onboardingPreviewOfferMeta` | `Karim · ★ 4.9 · 3 km` | `كريم · ★ 4.9 · 3 كم` |
| `onboardingLanguageEnShort` | `EN` | `EN` |
| `onboardingLanguageArShort` | `عربي` | `عربي` |
| `onboardingPageIndicator` | `Step {current} of {total}` | `الخطوة {current} من {total}` |

Reused, **no new key**: `l10n.splashLogoSemantic` ("Jeeb") for the wordmark alt text;
`l10n.tierFlashTitle` ("Flash") for the preview chip; `onboardingSlide1Semantics` for slide 1's
alt text; `onboardingNext` / `onboardingGetStarted` / `onboardingSkip` / `onboardingChooseLanguage`
unchanged.

The two short language keys are **additive** — `onboardingLanguageEnglish` / `…Arabic` stay in both
ARBs (unused by this screen). Append-only, per §7.4.

---

## 5. New routes

**None.** `/onboarding` (`app_router.dart:276`) already mounts this screen and is a pre-auth
destination in the first-run gate. No `backFallbacks` entry (it is the root of the gate, not a
pushed surface).

---

## 6. Semantics identifiers

**Preserved unchanged** (values, nesting and flags): `onboarding_root`, `walkthrough_slide_1/2/3`,
`onboarding_headline`, `onboarding_next_button` (outer), `walkthrough_next_cta` /
`walkthrough_get_started_cta` (inner, slide-dependent), `walkthrough_skip_cta`. Plus the six widget
keys listed in §0.

Re-homing map:
- `onboarding_headline` moves from wrapping `OmdsWalkthroughSwitcher` to wrapping `_SlideCopy`
  (eyebrow + headline + body). Same screen role, richer subtree — add
  `container: true, explicitChildNodes: true` here **only**, since it now wraps three `Text`s and
  nothing nested carries an id.
- `walkthrough_slide_N` moves from the illustration to `_SlideArtwork` (same pager item position).

**New** (convention `<screen>_<element>`):

| Identifier | Element | Flags |
|---|---|---|
| `onboarding_language_toggle` | the segmented control container | `container: true, explicitChildNodes: true`, `label: l10n.onboardingChooseLanguage` |
| `onboarding_language_en` | EN segment | `button: true, selected: …` |
| `onboarding_language_ar` | عربي segment | `button: true, selected: …` |
| `onboarding_page_dots` | `JeebPageDots` | `container: true`, `label: l10n.onboardingPageIndicator` |
| `onboarding_wordmark` | brand SVG | `image: true`, `label: l10n.splashLogoSemantic` |

The mic is decorative and does nothing — wrap it in `ExcludeSemantics` rather than giving it a
button id (see §9-C2).

---

## 7. RTL

Six things in this design break mirrored if built literally:

1. **Absolute card positions.** `left:26 / right:22 / left:38` (`html:22,29,33`) must be
   `PositionedDirectional(start:/end:)`, never `Positioned(left:/right:)`.
2. **Bubble tails.** `border-radius: 16 16 16 4` puts the tail on the bottom-**left** in LTR; in RTL
   the tail must flip to bottom-right. Use `BorderRadiusDirectional` (`bottomStart` / `bottomEnd`),
   not `BorderRadius.only`.
3. **The `Next →` arrow.** `Icon` does not auto-mirror (`directional_icons.dart:5-8`).
   `DirectionalIcons` has `back`, `backIos`, `disclosure`, `disclosureIos` — **no `forward`**. Either
   `JeebCtaButton` resolves the glyph internally, or `DirectionalIcons.forward(context)` gets added
   (3 lines, `lib/core/widgets/` — integrator-owned). See §wiringRequests.
4. **Arabic runs inside an EN tree.** `html:27` and `html:42` both set `direction: rtl` explicitly.
   Wrap the AR transcript and the AR eyebrow in `Directionality(textDirection: TextDirection.rtl)`
   so they lay out correctly when the app locale is `en`.
5. **Digits and money.** `0:04`, `$8`, `4.9`, `3 km` must be LTR-isolated
   (`Directionality(textDirection: TextDirection.ltr)`), matching
   `handover_code_display.dart:61` and `chat_message_bubble.dart:566`.
6. **The wordmark position.** Top-start in LTR → top-end in RTL. A plain
   `Row(mainAxisAlignment: spaceBetween)` inside a directional `Padding` handles it; the SVG glyph
   itself must not mirror (`SvgPicture` never does — correct).

Everything else is directional by construction: the page dots are a plain `Row` (active dot lands at
the logical start automatically), the sheet's top radius is symmetric, and the footer is a `Row`.

---

## 8. Test impact

`test/onboarding_screen_test.dart` (13 tests) + 3 files that only touch the class or its keys.

**Stay green — no edit:**
- `renders all 3 onboarding slides and the Skip CTA` (keys preserved)
- `sets LIGHT status-bar icons…` — the `AnnotatedRegion` at `:121-130` is unchanged; the top band is
  still navy, the bottom band is still the light surface
- `localizes slide copy under Arabic (RTL-safe)` — `OmdsWalkthroughStep` still renders the AR title
  via `RichText`, and `Key('onboarding.dots')` still resolves for the `Directionality` check
- `Next CTA advances to the last slide and becomes Get Started`
- `tapping Skip marks onboarding as complete in SharedPreferences`
- `slide 3 title keeps "end to end" unbreakable` (pure l10n)
- `test/features/batch_b_additional_ac_tests.dart` (keys only)
- `test/core/router/fr_gating_first_run_test.dart` (`find.byType(OnboardingScreen)` only)
- `test/core/diagnostics/gesture_log_test.dart` (unit test — **green only because §0's nesting rule
  is honoured**)
- `.maestro/flows/jm-006-splash-routing.yaml`, `.maestro/smoke.yaml` — all four ids preserved, and
  the pager still shows exactly one `walkthrough_slide_N` at a time

**Break legitimately — the design changed:**

| Test | Breaks on | Why it is legitimate | Fix |
|---|---|---|---|
| `slide copy + Skip flow through OMDS components` (`:97`) | `find.byType(OmdsWalkthroughSwitcher)` | `OmdsWalkthroughSwitcher` hardcodes `textTheme.displaySmall` (36/w400) + `titleMedium`, both inked `colorScheme.primary`, inside a fixed 170px box, and does **not** forward `labelStyle`/`descriptionStyle` to its child (`omds_walkthrough_step.dart:189-194`). The board needs 24/w700 navy + 13.5/w500 periwinkle + an AR eyebrow above. It is structurally unable to express the design. | Swap that one line for `find.byKey(const Key('onboarding.slideCopy'))`; **keep** the `OmdsWalkthroughStep`, `onboarding.pager`, `onboarding.illustration` and `OmdsSkipButton` assertions — all still true |
| `slide 1 renders the real voice-first SVG illustration` (`:189`) | asset name + `findsOneWidget` | The designer note is explicit: "abstract slide art **replaced** with a live marketplace preview". Slide 1 no longer has an SVG. | Rewrite as: slide 1 renders `Key('onboarding.preview')`, and `Key('onboarding.illustration')` still carries `image: true` + a non-empty label |
| `slide 2 …` (`:253`) and `slide 3 …` (`:235`) | the `svgAssetName` helper (`:183-187`) does `tester.widget<SvgPicture>(find.byType(SvgPicture))` — now **two** matches (wordmark + illustration) | Not a design regression; the screen gained a brand wordmark | Scope the helper: `find.descendant(of: find.byKey(const Key('onboarding.illustration')), matching: find.byType(SvgPicture))`. Assets and assertions otherwise unchanged |
| `renders the EN/AR language toggle` (`:283`) | `isA<OmdsFilterChips<String>>` + `find.text('English')` / `('العربية')` | Plan §5 #19 states outright that 01 uses a screen-local on-navy segmented variant; the board's segments read `EN` / `عربي` in a 4px-padded translucent pill | Assert `isA<OnboardingLanguageToggle>()` and `find.text('EN')` / `find.text('عربي')` |
| `selecting Arabic drives LocaleCubit.setLocale` (`:299`) | `tester.tap(find.text('العربية'))` | same label change | Retarget to `find.bySemanticsIdentifier('onboarding_language_ar')` — more robust than text |
| `language toggle reflects the active locale` (`:320`) | `tester.widget<OmdsFilterChips<String>>(…).selectedValue` | same | Keep the field name `selectedValue` on `OnboardingLanguageToggle` so this is a one-word type swap |

Net: **6 of 13 tests get a mechanical edit, none is weakened, no identifier is renamed.** Two of the
six (the `svgAssetName` scoping) are not even design-driven. No goldens exist for this screen.

**New tests to add** (the DoD's "updated only by ADDING"):
- the five new identifiers resolve;
- slide 1 renders the preview and slides 2–3 render their SVGs;
- RTL smoke: under `Locale('ar')`, card A sits at the logical start and the `Next` glyph is
  `Icons.arrow_back`;
- 200% `textScaler` does not overflow the sheet.

---

## 9. Conflicts and refusals

**C1 — the board designs one slide, the app has three. REFUSED to invent.**
`01-onboarding.html` renders a single frame with `JeebPageDots` showing 3 pages. There is no
slide-2 or slide-3 marketplace collage anywhere in the package. Composing two more from the same
card primitives is the lane inventing brand artwork, which is the design-side analogue of the
JEBV4-176 fabrication lesson. Slides 2 and 3 keep `onboarding_trusted_jeebers.svg` /
`onboarding_live_tracking.svg` on the new navy stage. **Designer/owner decision** — either two more
collages arrive, or slide 1 is the only preview and that is the shipped design.

**C2 — a Ø118 orange mic that does nothing.** `html:37` draws the mic with a full glow stack, and
plan §6 Wave 5 classifies the collage as "static/decorative". A 118px accent disc under three
floating cards will read as tappable. Build it decorative (`ExcludeSemantics`, no gesture) and flag
it. **Owner decision:** either accept a decorative mark, or make it a second affordance for
`_completeAndNavigate` — which is a product change, not an engineering one, and must not be
invented here. (For a reviewer grepping "mic": **B04 is not in play.** B04 bans a mic in the *chat
composer* — `test/features/chat/chat_composer_no_mic_b04_test.dart` — which is screen 21. Do not
refuse 01's mic on those grounds.)

**C3 — periwinkle body copy on white.** The sheet's body is `#777FC0` on `#FFFFFF` (`html:44`),
≈3.6:1 — below AA for 15px text. `test/core/theme/color_role_contrast_test.dart` asserts this
failure as a *fact* (the guard §4.1 says "stays"), so it is not a hard gate on usage, and R4 makes
periwinkle the board-wide qualifier ink. Today's screen renders this line in **navy** and is
accessible. Shipping the design is a small a11y regression. **Recommendation: ship periwinkle**
(consistency with the other 23 screens wins) and record the finding; the accessible alternative is
`cs.onSurfaceVariant` (#5C4038, 7.9:1) at the cost of a warmer, off-board subtitle.

**C4 — white cards carrying shadows contradicts R7** ("a white card with a shadow does not exist
anywhere on this board"). It does here: `html:22,29` both set `0 12 26 rgba(0,0,0,.3)`. This is a
legitimate exception, not a mistake — those cards float on navy, not on white. Use
`JeebShadows.heroNavy` and note the exception so the Wave-5 sweep does not "fix" it.

**C5 — `Skip` is legitimate (02-PLAN §4 C9).** D56's no-skip / no-close / no-back rule is the
**mutual-rating** screen only (`test/decision_violations_test.dart`, screen 15). `walkthrough_skip_cta`
stays, and its `_completeAndNavigate` → `goNamed('register')` behaviour is untouched.

**C6 — sheet gutter is 32, not the board's 24** (`html:41` vs §4.3's `--screen-gutter`). 01's sheet
is a marketing surface; keep 32 (`Spacing.twoXLarge`) and note the deliberate divergence.

**C7 — no `flex:1` spacer, and that is correct.** R1 says 22 of 24 screens are
`content → flex:1 → footer`. 01 is one of the two exceptions (plan §6 Wave 5 says so explicitly):
the *stage* is the flex, and the sheet is packed. A lane applying R1 mechanically here would insert
empty space inside the sheet and break the design.

**C8 — dark mode.** The white-on-navy overlays resolve through `cs.onPrimary`, which inverts in the
dark scheme (`ColorScheme.fromSeed(navy)`), so the translucent cards and toggle track will be
off-spec in dark. That is the plan's accepted position (§9.4, dark is out of scope) — do **not**
invent a dark treatment for this screen.

---

## 10. Risks

1. **The `AnimatedSwitcher` height jump.** Losing `OmdsWalkthroughSwitcher`'s fixed 170px box means
   the sheet — and therefore the stage, and therefore the floating cards — resizes on every swipe,
   worst in AR where copy lengths differ most. Mitigated by `_kSlideCopyMinHeight`; verify on the
   S22 in both locales.
2. **Swipe area shrinks.** The pager is no longer full-bleed; swipes only register on the navy
   stage (~55% of the screen). Maestro drives the carousel by tapping `walkthrough_next_cta`, so E2E
   is safe, but a real user swiping over the sheet gets nothing. Acceptable per the design; worth a
   pass on the S22.
3. **Ø380 décor ring.** Overflows a 360dp-wide device. `ClipRect` on the stage is mandatory, not
   cosmetic.
4. **`JeebPageDots` measurement conflict.** Plan §5 #28 says 28×8 / gap 6; 01 (its only consumer)
   measures 22×8 / gap 7. If the kit ships the plan's numbers this screen is 6px off — cheap either
   way, but it must be settled in Wave 1, not here.
5. **Kit dependency on three unbuilt widgets.** `lib/core/widgets/jeeb/` does not exist yet.
   `JeebMicHero` (decorative mode), `JeebCtaFooter.split` (arbitrary `leading`) and `JeebPageDots`
   are all on 01's critical path; 01 cannot land before Wave-1 steps 4, 8 and 12.
6. **Density.** The board's stage is ~45% empty around three small cards (risk #13 in the plan). The
   temptation will be to scale the preview cards up to fill it. Compare against the PNG at the same
   scale, not against a checklist.
7. **`onboarding_voice_first.svg` goes unreferenced** but stays bundled. Harmless (~few KB); removing
   it means editing Wave-0-frozen `pubspec.yaml`.

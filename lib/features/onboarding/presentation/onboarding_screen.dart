import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/onboarding_screen_fixtures.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext(int pageCount) {
    if (_currentPage < pageCount - 1) {
      _pageController.nextPage(
        duration: UIConstants.animationNormal,
        curve: Curves.easeInOut,
      );
    } else {
      _completeAndNavigate();
    }
  }

  Future<void> _completeAndNavigate() async {
    if (!mounted) return;
    await context.read<OnboardingCubit>().complete();
    if (!mounted) return;
    final onComplete = widget.onComplete;
    if (onComplete != null) {
      onComplete();
    } else {
      // DEFECT-3: Get Started + Skip land on the phone-OTP entry (`/register`,
      // ignore: use_build_context_synchronously
      context.goNamed('register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pages = _onboardingPages(AppLocalizations.of(context));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Semantics(
        identifier: 'onboarding_root',
        container: true,
        child: Scaffold(
        backgroundColor: colorScheme.secondaryContainer,
        body: Stack(
          children: [
            _IllustrationCarousel(
              controller: _pageController,
              pages: pages,
              onPageChanged: (i) => setState(() => _currentPage = i),
            ),
            const _BottomScrim(),
            _BottomPanel(
              pages: pages,
              currentPage: _currentPage,
              onNext: () => _onNext(pages.length),
              onSkip: _completeAndNavigate,
              onGetStarted: _completeAndNavigate,
            ),
            const _LanguageToggle(),
          ],
        ),
      ),
      ),
    );
  }
}

const String _kVoiceFirstAsset = 'assets/illustrations/onboarding_voice_first.svg';
const String _kTrustedJeebersAsset =
    'assets/illustrations/onboarding_trusted_jeebers.svg';
const String _kLiveTrackingAsset =
    'assets/illustrations/onboarding_live_tracking.svg';

List<_OnboardingPage> _onboardingPages(AppLocalizations l10n) => [
      _OnboardingPage(
        icon: Icons.mic_none_rounded,
        asset: _kVoiceFirstAsset,
        title: l10n.onboardingSlide1Title,
        body: l10n.onboardingSlide1Body,
        semanticsLabel: l10n.onboardingSlide1Semantics,
      ),
      _OnboardingPage(
        icon: Icons.verified_user_outlined,
        asset: _kTrustedJeebersAsset,
        title: l10n.onboardingSlide2Title,
        body: l10n.onboardingSlide2Body,
        semanticsLabel: l10n.onboardingSlide2Semantics,
      ),
      _OnboardingPage(
        icon: Icons.map_outlined,
        asset: _kLiveTrackingAsset,
        title: l10n.onboardingSlide3Title,
        body: l10n.onboardingSlide3Body,
        semanticsLabel: l10n.onboardingSlide3Semantics,
      ),
    ];

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.asset,
    required this.title,
    required this.body,
    required this.semanticsLabel,
  });

  final IconData icon;

  final String? asset;

  final String title;
  final String body;

  final String semanticsLabel;
}

class _IllustrationCarousel extends StatelessWidget {
  const _IllustrationCarousel({
    required this.controller,
    required this.pages,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<_OnboardingPage> pages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const Key('onboarding.pager'),
      controller: controller,
      itemCount: pages.length,
      onPageChanged: onPageChanged,
      itemBuilder: (_, i) => Semantics(
        identifier: 'walkthrough_slide_${i + 1}',
        container: true,
        child: _WalkthroughIllustration(page: pages[i]),
      ),
    );
  }
}

class _WalkthroughIllustration extends StatelessWidget {
  const _WalkthroughIllustration({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Align(
        alignment: const Alignment(0.0, -0.35),
        child: Semantics(
          key: const Key('onboarding.illustration'),
          image: true,
          label: page.semanticsLabel,
          child: _IllustrationArtwork(page: page),
        ),
      ),
    );
  }
}

class _IllustrationArtwork extends StatelessWidget {
  const _IllustrationArtwork({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final asset = page.asset;
    if (asset == null) {
      return Icon(
        page.icon,
        size: Sizes.twoHundredLarge,
        color: colorScheme.onSecondaryContainer,
      );
    }
    return SvgPicture.asset(
      asset,
      width: Sizes.twoHundredLarge,
      height: Sizes.twoHundredLarge,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => const SizedBox.square(
        dimension: Sizes.twoHundredLarge,
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.55,
          widthFactor: 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [surface.withValues(alpha: 0.0), surface, surface],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.pages,
    required this.currentPage,
    required this.onNext,
    required this.onSkip,
    required this.onGetStarted,
  });

  final List<_OnboardingPage> pages;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLast = currentPage >= pages.length - 1;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IgnorePointer(
                // PoC Maestro identifier: the animated step copy is the screen's
                // headline. Exposing a stable `identifier` lets Maestro assert on
                child: Semantics(
                  identifier: 'onboarding_headline',
                  child: OmdsWalkthroughSwitcher(
                    currentIndex: currentPage,
                    steps: [
                      for (final page in pages)
                        OmdsWalkthroughStepData(
                          label: page.title,
                          description: page.body,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.large),
              OmdsDotIndicator(
                key: const Key('onboarding.dots'),
                currentIndex: currentPage,
                itemCount: pages.length,
              ),
              const SizedBox(height: Spacing.xLarge),
              _OnboardingCtaButton(
                isLast: isLast,
                nextLabel: l10n.onboardingNext,
                getStartedLabel: l10n.onboardingGetStarted,
                onNext: onNext,
                onGetStarted: onGetStarted,
              ),
              const SizedBox(height: Spacing.medium),
              _OnboardingSkipButton(
                label: l10n.onboardingSkip,
                onTap: onSkip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCtaButton extends StatelessWidget {
  const _OnboardingCtaButton({
    required this.isLast,
    required this.nextLabel,
    required this.getStartedLabel,
    required this.onNext,
    required this.onGetStarted,
  });

  final bool isLast;
  final String nextLabel;
  final String getStartedLabel;
  final VoidCallback onNext;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'onboarding_next_button',
      child: Semantics(
        identifier:
            isLast ? 'walkthrough_get_started_cta' : 'walkthrough_next_cta',
        button: true,
        child: OmdsPrimaryButton(
          key: Key(isLast ? 'onboarding.getStarted' : 'onboarding.next'),
          text: isLast ? getStartedLabel : nextLabel,
          onTap: isLast ? onGetStarted : onNext,
          width: double.infinity,
        ),
      ),
    );
  }
}

class _OnboardingSkipButton extends StatelessWidget {
  const _OnboardingSkipButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'walkthrough_skip_cta',
      button: true,
      child: OmdsSkipButton(
        key: const Key('onboarding.skip'),
        text: label,
        padding: const EdgeInsets.all(Spacing.small),
        onTap: onTap,
      ),
    );
  }
}

const String _kLangEn = 'en';
const String _kLangAr = 'ar';

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;
    return SafeArea(
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Semantics(
            container: true,
            label: l10n.onboardingChooseLanguage,
            child: OmdsFilterChips<String>(
              key: const Key('onboarding.languageToggle'),
              showCounts: false,
              selectedValue: locale.languageCode,
              onFilterChanged: (code) => _onLanguageSelected(context, code),
              filters: [
                OmdsFilterOption<String>(
                  label: l10n.onboardingLanguageEnglish,
                  value: _kLangEn,
                ),
                OmdsFilterOption<String>(
                  label: l10n.onboardingLanguageArabic,
                  value: _kLangAr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onLanguageSelected(BuildContext context, String? code) {
    if (code == null) return;
    context.read<LocaleCubit>().setLocale(Locale(code));
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/onboarding/onboarding_screen_preview_test.dart
// ===========================================================================
//
// [OnboardingScreen] is a three-slide carousel over STATIC, localized copy.
// There is no repository, no `cubit:` seam, nothing async of its own and no
// failure path in the widget — so there is no empty state, no loading state and
// no error state to preview, and saying so is the point rather than an
// omission. What varies between the designed states is exactly two things:
// which SLIDE the carousel is parked on, and which locale [LocaleCubit]
// resolved to.
//
// The cubits, the in-memory prefs behind them and the seating are NOT declared
// here. They live in
// `lib/devtool/catalog/fixtures/onboarding_screen_fixtures.dart`, shared with
// the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_08_entries.dart`), so the designer's browser
// and this canvas cannot drift into showing two different "Slides — AR".
// Nothing there can reach the network or the DI graph: [OnboardingCubit] only
// ever touches prefs, a [LocaleCubit] with no `LanguagePreferenceRepository`
// never makes a call, and the prefs are a map. The guard in [jeebPreviewHost]
// is the net here, not the plan.
//
// Four things about this harness before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + Stack` paints inside it. Same nesting the Screen
//    Catalog produces.
//  * **The device frame is pinned in the TREE, not just in `size:`.** `size:`
//    boxes the canvas only; calling a preview function from a render test gets
//    the tester's 800x600 desktop surface. [OnboardingScreenPreviewHost] pins
//    the same box in the widget tree, so a measurement in the test is a
//    measurement of the card — and on this screen every finding below is a
//    measurement.
//  * **A [LocaleCubit] ancestor is mandatory, not optional.** [_LanguageToggle]
//    calls `context.watch<LocaleCubit>()` on every build, so a bare
//    `OnboardingScreen` throws in the canvas. [OnboardingCubit] is only read
//    from a gesture, but Skip and Get Started are live in the canvas and both
//    call `complete()`, so the host supplies it too — over a map, not the
//    device's prefs.
//  * **Slides 2 and 3 are reached by DRIVING the carousel, not by asking for
//    them.** The screen builds its own `PageController` in a field and exposes
//    no `initialPage`, so `OnboardingScreenPreviewHost(slide: n)` jumps the
//    pager after the first frame — through the same `onPageChanged` a swipe
//    goes through. Two consequences for anyone writing a test against these:
//    the FIRST frame of a slide-2/3 card is always slide 1, and pumping a
//    second preview into a tester that already holds one does not re-run the
//    jump (same widget types, so the element is updated, not replaced).
//
// What these previews surfaced in the screen — none of it changed here. Every
// number was measured with the real Inter faces and the deterministic Noto
// Arabic subset (`loadInterTestFont` + `withGoldenTestFonts`); under Flutter's
// 1-em test face they would all be fiction.
//
//  * **The slide copy does not fit its box, and the box cannot grow.**
//    [OmdsWalkthroughSwitcher] hard-codes `SizedBox(height: 170)` around
//    [OmdsWalkthroughStep], whose `Column` is `mainAxisSize: min` with no
//    `maxLines`, no ellipsis and nothing scrollable. Copy that stops fitting is
//    painted outside the box and clipped — silently in release, striped in
//    debug. Measured overflow of the body, by frame and locale:
//
//                        100% EN   100% AR   200% EN   200% AR
//        390x844 slide 1     ok        ok      118px      31px
//        390x844 slide 2     ok        ok      166px      75px
//        390x844 slide 3     ok        ok      118px      75px
//        320x568 slide 1     ok        ok      166px     124px
//        320x568 slide 2   42px        ok      258px      77px
//        320x568 slide 3     ok        ok      166px     126px
//
//    So the app's FIRST screen already loses the last line of slide 2 in
//    English on the narrowest phone it supports, at the default text size, and
//    loses copy on every slide in both locales at the accessibility ceiling.
//    Note where the ceiling is not: `_BottomPanel`'s own `Column` never
//    overflows, and neither does the 200 pt illustration — the whole failure is
//    the fixed copy box. Arabic survives 100%/320 only because it says the same
//    thing in fewer glyphs; that is a copy-length margin, not a layout one.
//  * **The illustration fallback cannot be reached from anywhere.**
//    [_IllustrationArtwork] degrades to the tinted [_OnboardingPage.icon] glyph
//    when `asset` is null, and [_WalkthroughIllustration] documents that as the
//    resilient path — but `_onboardingPages` hard-codes all three assets and
//    takes no injection, so no dev surface and no test can render it. It is
//    dead in practice: the only observable degraded state is the blank
//    `SizedBox.square` from `placeholderBuilder` while the SVG decodes.
//  * **Skip and Get Started WRITE before they navigate.** Both call
//    `_completeAndNavigate`, which awaits `OnboardingCubit.complete()` and
//    persists `app.onboarding.completed`. Harmless here (the fixtures' prefs
//    are a map, and `onComplete` is a no-op), but it is why the Screen Catalog
//    entry had to stop using the device's real `SharedPreferences`: one tap
//    while browsing the catalog used to suppress the real walkthrough forever.
//  * **The language chips are fully live, and there is no way back.** Tapping
//    a chip drives `LocaleCubit.setLocale`, which persists — in the canvas
//    that flips the chip but NOT the copy, because the card's own locale comes
//    from the preview's `localizations:` rather than from the cubit. In the
//    shipped app `app.dart` binds `MaterialApp.locale` to the same cubit, so
//    the two cannot disagree there. `LocaleCubit.resetToDeviceLocale()` still
//    has no caller anywhere.

/// The phone this screen is designed against.
const Size _onboardingScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate) — and roughly what an Android multi-window split leaves a
/// foreground app.
const Size _onboardingScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist: the headline goes through `RichText` (invisible to a plain
/// `find.text`) and the compact cards repaint the phone cards' copy at another
/// frame size, so no production string separates them. Dev chrome, never
/// shipped copy.
final class OnboardingScreenCaptions {
  OnboardingScreenCaptions._();

  /// The entry state every first-launch user sees.
  static const String slide1 = 'preview · slide 1 of 3 · 390x844';

  /// The longest body copy of the three.
  static const String slide2 = 'preview · slide 2 of 3 · 390x844';

  /// The only slide whose CTA says "Get Started".
  static const String lastSlide = 'preview · slide 3 of 3 · 390x844';

  /// The cubit pinned to Arabic while the card renders in the app's locale.
  static const String arabicResolved = 'preview · locale cubit pinned to ar';

  /// The layout ceiling: the longest copy on the narrowest phone.
  static const String compactCeiling = 'preview · slide 2 · 320x568 ceiling';

  /// The narrow frame with the longer CTA label.
  static const String compactLastSlide = 'preview · slide 3 · 320x568 ceiling';
}

/// Puts a dev caption above the device frame, so a card that repeats another
/// card's copy at a different frame size still says which state it is.
class _OnboardingScreenCaptioned extends StatelessWidget {
  const _OnboardingScreenCaptioned({
    required this.caption,
    required this.child,
  });

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            // one latin line and the 200% card does not spend a third of the
            // device on a label.
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}

/// Seats [OnboardingScreen] over a fixture pair of cubits, at a pinned device
/// box, parked on [slide].
Widget _onboardingScreenHosted(
  OnboardingScreenCubitFactory create,
  String caption, {
  int slide = 0,
  Size box = _onboardingScreenPhoneBox,
}) =>
    _OnboardingScreenCaptioned(
      caption: caption,
      child: OnboardingScreenPreviewHost(
        create: create,
        box: box,
        slide: slide,
        // `onComplete` is a no-op so Skip and Get Started never reach for
        // `goNamed('register')`, which needs a GoRouter no preview card has.
        child: OnboardingScreen(onComplete: () {}),
      ),
    );

/// The reference reading: first launch, slide 1 of 3, the CTA still says
/// "Next" and Skip is already offered.
///
/// The locale follows the card's own, exactly as in the shipped app — so the AR
/// rendering is a coherent Arabic walkthrough with العربية selected, not an
/// Arabic screen with the English chip ticked.
///
/// Matrixed because all three renderings say something different here. The AR
/// card is the RTL mirror of a screen whose only directional chrome is the
/// top-trailing language toggle (`AlignmentDirectional.topEnd`, so it moves to
/// top-leading). The 200% card is where the copy box starts bursting: 118 px of
/// the body is painted outside the 170 pt frame and clipped, on the reference
/// phone, at the accessibility ceiling.
@JeebPreview(
  group: 'onboarding',
  name: 'Slide 1 · voice-first',
  size: _onboardingScreenPhoneBox,
  matrix: true,
)
Widget onboardingScreenSlide1() => _onboardingScreenHosted(
      OnboardingScreenPreviewFixtures.followsAmbient,
      OnboardingScreenCaptions.slide1,
    );

/// Slide 2 of 3 — the longest body copy the walkthrough ships in either
/// language ("Every Jeeber is vetted, rated, and accountable…", 86 characters).
///
/// The content ceiling of this screen: the copy is fixed, so "the longest
/// plausible content" is not a fixture someone invents, it is this slide. On
/// the 390 pt frame at 100% it fits with little to spare; the compact card
/// below is the same slide at 320 pt, where it does not.
@JeebPreview(
  group: 'onboarding',
  name: 'Slide 2 · longest copy',
  size: _onboardingScreenPhoneBox,
)
Widget onboardingScreenSlide2() => _onboardingScreenHosted(
      OnboardingScreenPreviewFixtures.followsAmbient,
      OnboardingScreenCaptions.slide2,
      slide: 1,
    );

/// Slide 3 of 3 — the only state in which the primary CTA says "Get Started"
/// and carries `walkthrough_get_started_cta` instead of `walkthrough_next_cta`
/// (60_W0_TEST_PLAN §2.2). Both it and Skip land on the phone-OTP entry
/// (DEFECT-3).
///
/// Also the slide with a past bug worth looking at rather than reading about:
/// the headline used to wrap as "Live tracking, end to / end", orphaning a
/// trailing "end". The fix binds the phrase with non-breaking spaces (U+00A0)
/// in the ARB, so the break falls after the comma. `test/onboarding_screen_test.dart`
/// asserts the ARB entry; this card is where the WRAP is visible, and the
/// render test asserts the rendered string still carries the NBSPs.
@JeebPreview(
  group: 'onboarding',
  name: 'Slide 3 · Get Started',
  size: _onboardingScreenPhoneBox,
)
Widget onboardingScreenLastSlide() => _onboardingScreenHosted(
      OnboardingScreenPreviewFixtures.followsAmbient,
      OnboardingScreenCaptions.lastSlide,
      slide: 2,
    );

/// The Screen Catalog's "Slides — AR", made honest: the cubit is pinned to
/// Arabic through the PERSISTED key, so it does not move with the card.
///
/// In the EN rendering this is the divergent reading only a dev surface can
/// produce — an English, LTR walkthrough with العربية selected. The shipped app
/// cannot show it (`app.dart` drives `MaterialApp.locale` from this same
/// cubit); a surface that pins the cubit without pinning the app locale always
/// can, and the catalog is exactly that surface. Kept as its own card so the
/// state a designer signs off against is visible here too.
@JeebPreview(
  group: 'onboarding',
  name: 'Arabic resolved · chip pinned',
  size: _onboardingScreenPhoneBox,
)
Widget onboardingScreenArabicResolved() => _onboardingScreenHosted(
      OnboardingScreenPreviewFixtures.arabic,
      OnboardingScreenCaptions.arabicResolved,
    );

/// Layout ceiling: the longest slide on the narrowest supported phone.
///
/// **This card overflows, and that is what it is for.** At 320x568, in English,
/// at the DEFAULT text size, the slide-2 body needs 42 px more than
/// `OmdsWalkthroughSwitcher`'s hard-coded 170 pt box — so the last line is
/// painted outside it and clipped. Nothing in the chain can absorb it: the box
/// is a constant, `OmdsWalkthroughStep`'s `Column` has no `maxLines` and no
/// ellipsis, and it is not inside anything scrollable.
///
/// Matrixed because the three renderings are three different verdicts on the
/// same frame: EN light already clips, AR RTL dark is clean (Arabic says it in
/// fewer glyphs — a copy-length margin, not a layout one), and EN 200% clips
/// 258 px, more than the box is tall. The render test pins all of it, including
/// the Arabic pass, so a copy edit in either ARB fails here.
@JeebPreview(
  group: 'onboarding',
  name: 'Compact 320x568 · layout ceiling',
  size: _onboardingScreenCompactBox,
  matrix: true,
)
Widget onboardingScreenCompactCeiling() => _onboardingScreenHosted(
      OnboardingScreenPreviewFixtures.followsAmbient,
      OnboardingScreenCaptions.compactCeiling,
      slide: 1,
      box: _onboardingScreenCompactBox,
    );

/// The narrow frame carrying the LONGER CTA label ("Get Started" / "ابدأ الآن")
/// and the shortest body copy.
///
/// The counterweight to the ceiling card: same 320 pt frame, and clean in both
/// locales at 100%. It is what says the compact frame itself is fine and the
/// problem is the slide-2 copy — without it, "320 pt is broken" would be the
/// obvious and wrong reading of the card above.
@JeebPreview(
  group: 'onboarding',
  name: 'Compact 320x568 · Get Started',
  size: _onboardingScreenCompactBox,
)
Widget onboardingScreenCompactLastSlide() => _onboardingScreenHosted(
      OnboardingScreenPreviewFixtures.followsAmbient,
      OnboardingScreenCaptions.compactLastSlide,
      slide: 2,
      box: _onboardingScreenCompactBox,
    );

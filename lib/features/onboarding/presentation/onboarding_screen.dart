import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../l10n/app_localizations.dart';

/// Three-page introductory onboarding carousel shown to first-launch users
/// (JM-010 `walkthrough`).
///
/// Structure mirrors the Olivium fleet reference walkthroughs (Salehly /
/// rahmah / creamati / saawt): a full-bleed [PageView] of branded
/// illustrations behind a bottom gradient scrim, with the animated step copy
/// ([OmdsWalkthroughSwitcher]), the page dots ([OmdsDotIndicator]), the
/// primary CTA ([OmdsPrimaryButton]) and the Skip affordance
/// ([OmdsSkipButton]) anchored along the bottom edge. The illustration is the
/// swipeable back layer; the text + controls float over the scrim
/// (`IgnorePointer` on the copy so swipes still reach the carousel).
///
/// JM-010 destination (CTO-D1, email-first funnel): "Get Started" on the last
/// slide AND "Skip" from any slide route to **sign-up** (`/sign-up`,
/// `signup_name_field`), NOT the legacy phone-first `/register`. The
/// phone-first `/register` is now reachable only as the phone-OTP verify step
/// behind sign-up/social (JM-009). See `docs/build-out/01_CTO_DECISIONS.md`
/// CTO-D1 and `30_BACKLOG.md` JM-010.
///
/// Semantics contract (`docs/build-out/60_W0_TEST_PLAN.md` §2.2; coined §4):
///   - `walkthrough_slide_1` / `_slide_2` / `_slide_3` — the per-slide root
///     containers (each becomes visible as the carousel advances).
///   - `walkthrough_next_cta` — the advance button on slides 1–2.
///   - `walkthrough_get_started_cta` — the primary CTA on the last slide only.
///   - `walkthrough_skip_cta` — the Skip affordance, present from slide 1.
/// The foundation-era `onboarding_next_button` (primary CTA) and
/// `onboarding_headline` (animated step copy) identifiers are preserved so the
/// pre-existing Phase-2 PoC flow keeps asserting on them.
///
/// Slide artwork (FR-WALKTHROUGH / FR-P1-1; slide 2 completed in FR-D1D2): all
/// three slides render real exported brand vectors via [SvgPicture.asset] —
/// `assets/illustrations/onboarding_voice_first.svg` (voice-first),
/// `onboarding_trusted_jeebers.svg` (trusted Jeebers) and
/// `onboarding_live_tracking.svg` (live tracking). [_WalkthroughIllustration]
/// isolates the per-slide treatment: a slide with an `asset` renders the SVG; a
/// slide without one degrades to the tinted [_OnboardingPage.icon] glyph on the
/// brand field — preserving the resilient fallback for any future slide.
///
/// FR-P1-2: an EN/AR language toggle ([_LanguageToggle], built on
/// [OmdsFilterChips]) is anchored top-trailing; selecting a locale drives
/// [LocaleCubit.setLocale], which rebuilds `MaterialApp.locale` and flips the
/// entire tree to RTL live (no restart).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  /// Optional override for navigation. Tests inject this so the screen
  /// does not need a GoRouter in scope. Production leaves it null and
  /// `context.goNamed('sign-up')` handles navigation (CTO-D1).
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
    // Persist seen_onboarding so cold restarts skip the carousel.
    if (!mounted) return;
    await context.read<OnboardingCubit>().complete();
    if (!mounted) return;
    final onComplete = widget.onComplete;
    if (onComplete != null) {
      onComplete();
    } else {
      // JM-010 / CTO-D1: Get Started + Skip both land on the email-first
      // sign-up screen (`signup_name_field`), not the phone-first `/register`.
      // ignore: use_build_context_synchronously
      context.goNamed('sign-up');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pages = _onboardingPages(AppLocalizations.of(context));
    // The hero illustration band is brand-navy (`secondaryContainer`), so the
    // status bar must paint LIGHT (white) icons to stay legible — the global
    // `Brightness.dark` set in `main()` is for the light auth/client screens.
    // The bottom band is the light `surface` scrim, so the system nav-bar icons
    // resolve from the active theme brightness (dark icons in light mode).
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
    );
  }
}

/// Asset paths for the wired walkthrough slide illustrations (FR-P1-1; the
/// trusted-Jeebers slide-2 asset landed in FR-D1D2).
const String _kVoiceFirstAsset = 'assets/illustrations/onboarding_voice_first.svg';
const String _kTrustedJeebersAsset =
    'assets/illustrations/onboarding_trusted_jeebers.svg';
const String _kLiveTrackingAsset =
    'assets/illustrations/onboarding_live_tracking.svg';

/// Static slide content. All three slides carry real exported SVGs; the [icon]
/// remains as a resilient fallback only (rendered if a future slide ever ships
/// without an `asset` — see [_WalkthroughIllustration]).
List<_OnboardingPage> _onboardingPages(AppLocalizations l10n) => [
      _OnboardingPage(
        icon: Icons.mic_none_rounded,
        asset: _kVoiceFirstAsset,
        title: l10n.onboardingSlide1Title,
        body: l10n.onboardingSlide1Body,
        semanticsLabel: l10n.onboardingSlide1Semantics,
      ),
      _OnboardingPage(
        // FR-D1D2: the real "Trusted Jeebers" brand vector. The verified-user
        // glyph is retained only as the resilient decode fallback.
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

  /// Interim glyph, used only when [asset] is null.
  final IconData icon;

  /// Bundled SVG illustration path, or null to fall back to the [icon] glyph.
  final String? asset;

  final String title;
  final String body;

  /// Localized screen-reader alt text for the illustration.
  final String semanticsLabel;
}

/// Full-bleed, swipeable illustration carousel — the back layer of the stack.
///
/// Each page's artwork is wrapped in the per-slide
/// `walkthrough_slide_<n>` Semantics container (JM-010 / 60_W0_TEST_PLAN
/// §2.2). Because a [PageView] keeps only the centered page on-screen and
/// translates the neighbours out of bounds, exactly one `walkthrough_slide_<n>`
/// node is reported visible at a time — which is what the Maestro
/// `extendedWaitUntil { visible: walkthrough_slide_N }` steps assert as the
/// carousel advances.
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
        // walkthrough_slide_1 / _slide_2 / _slide_3 — per-slide root container.
        identifier: 'walkthrough_slide_${i + 1}',
        container: true,
        child: _WalkthroughIllustration(page: pages[i]),
      ),
    );
  }
}

/// The branded full-bleed slide artwork.
///
/// Renders the page's exported SVG ([SvgPicture.asset]) when [_OnboardingPage.asset]
/// is set; otherwise degrades to a tinted Material glyph on the brand-navy
/// field. Either way the artwork floats above the bottom copy/control band and
/// carries a localized semantic label so screen readers announce the slide.
class _WalkthroughIllustration extends StatelessWidget {
  const _WalkthroughIllustration({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Align(
        // Float the artwork above the bottom copy/control band.
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

/// The artwork itself: the real SVG, or the interim brand glyph when no asset
/// exists for this slide.
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
      // A failed/slow decode degrades to the brand field, never a broken glyph.
      placeholderBuilder: (_) => const SizedBox.square(
        dimension: Sizes.twoHundredLarge,
      ),
    );
  }
}

/// Bottom gradient that fades the illustration into a readable surface band
/// for the copy + controls. Ignores pointers so swipes still reach the
/// carousel behind it.
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

/// Bottom-anchored content: animated step copy, page dots, the primary CTA
/// (Next on slides 1–2 / Get Started on the last slide), and Skip.
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
                // the headline by id (i18n-safe), independent of visible text.
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

/// The primary CTA at the foot of the carousel.
///
/// Carries TWO Semantics contracts at once:
///   - the foundation-era `onboarding_next_button` (kept so the Phase-2 PoC
///     flow keeps asserting the primary CTA by id across both labels/locales);
///   - the JM-010 contract id, which switches with the slide:
///     `walkthrough_next_cta` on slides 1–2, `walkthrough_get_started_cta` on
///     the last slide (60_W0_TEST_PLAN §2.2 — "Next … becomes Get Started on
///     slide 3" / "Get Started … visible on last slide only").
/// On the last slide the tap routes to sign-up (CTO-D1); on earlier slides it
/// advances the carousel.
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
    // JM-010 id flips with the slide; the legacy `onboarding_next_button` id
    // wraps it so both contracts resolve to the same button.
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

/// The Skip affordance, present from slide 1.
///
/// Carries the JM-010 coined id `walkthrough_skip_cta` (60_W0_TEST_PLAN §2.2/§4)
/// and routes to sign-up (CTO-D1). The legacy `Key('onboarding.skip')` is kept
/// for the existing widget tests that find it by key.
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

/// Supported onboarding locale language codes (FR-P1-2).
const String _kLangEn = 'en';
const String _kLangAr = 'ar';

/// Top-trailing EN/AR language toggle (FR-P1-2).
///
/// Built on [OmdsFilterChips] (there is no `OmdsButtonGroup` in OMDS — see
/// design spec §2b). Selecting a chip drives [LocaleCubit.setLocale], which
/// persists the choice and rebuilds `MaterialApp.locale`, flipping the whole
/// tree to RTL for Arabic live (no restart). Anchored top-trailing so it
/// mirrors to top-leading in RTL automatically.
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

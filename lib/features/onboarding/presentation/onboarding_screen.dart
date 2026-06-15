import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../l10n/app_localizations.dart';

/// Three-page introductory onboarding carousel shown to first-launch users.
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
/// Slide artwork (FR-WALKTHROUGH / FR-P1-1; slide 2 completed in FR-D1D2): all
/// three slides now render real exported brand vectors via [SvgPicture.asset] —
/// `assets/illustrations/onboarding_voice_first.svg` (voice-first),
/// `onboarding_trusted_jeebers.svg` (trusted Jeebers) and
/// `onboarding_live_tracking.svg` (live tracking). The slide-2 illustration was
/// added in FR-D1D2 to replace the interim shield/check glyph Codex QA flagged
/// as a placeholder; it is drawn in the same 300x300 navy/orange/periwinkle
/// idiom as the other two (a vetted courier with a verification badge, a
/// five-star rating, and a trust shield). [_WalkthroughIllustration] still
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
  /// `context.go('/register')` handles navigation.
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
      // ignore: use_build_context_synchronously
      context.go('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _onboardingPages(AppLocalizations.of(context));
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
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
          ),
          const _LanguageToggle(),
        ],
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
      itemBuilder: (_, i) => _WalkthroughIllustration(page: pages[i]),
    );
  }
}

/// The branded full-bleed slide artwork.
///
/// Renders the page's exported SVG ([SvgPicture.asset]) when [_OnboardingPage.asset]
/// is set (slides 1 and 3); otherwise degrades to a tinted Material glyph on
/// the brand-navy field (the INTERIM slide-2 treatment). Either way the artwork
/// floats above the bottom copy/control band and carries a localized semantic
/// label so screen readers announce the slide.
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

/// Bottom-anchored content: animated step copy, page dots, CTA, and Skip.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.pages,
    required this.currentPage,
    required this.onNext,
    required this.onSkip,
  });

  final List<_OnboardingPage> pages;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onSkip;

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
              const SizedBox(height: Spacing.large),
              OmdsDotIndicator(
                key: const Key('onboarding.dots'),
                currentIndex: currentPage,
                itemCount: pages.length,
              ),
              const SizedBox(height: Spacing.xLarge),
              _OnboardingCtaButton(
                isLast: isLast,
                label:
                    isLast ? l10n.onboardingGetStarted : l10n.onboardingNext,
                onTap: onNext,
              ),
              const SizedBox(height: Spacing.medium),
              OmdsSkipButton(
                key: const Key('onboarding.skip'),
                text: l10n.onboardingSkip,
                padding: const EdgeInsets.all(Spacing.small),
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
    required this.label,
    required this.onTap,
  });

  final bool isLast;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OmdsPrimaryButton(
      key: Key(isLast ? 'onboarding.getStarted' : 'onboarding.next'),
      text: label,
      onTap: onTap,
      width: double.infinity,
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

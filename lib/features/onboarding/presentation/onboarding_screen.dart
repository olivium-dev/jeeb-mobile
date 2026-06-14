import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

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
/// FLAG(figma): the per-slide artwork is still a placeholder glyph. The
/// branded full-bleed illustrations live in Figma `ZOi3kKtw7sd42ssSVX3Kn4`
/// but the slide node ids are unresolved (Dev Mode MCP unreachable in this
/// pass — see design/SCREEN-SPEC.md §0/§7). [_WalkthroughIllustration]
/// isolates the swap point: drop the three exported assets into
/// `assets/illustrations/` and replace the placeholder glyph with a full-bleed
/// `Image.asset(..., fit: BoxFit.cover)` / [OmdsCachedImage] — no layout change
/// needed. We deliberately do NOT invent pixel values for unconfirmed designs.
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
        ],
      ),
    );
  }
}

/// Static slide content. Icons are placeholders for the Figma illustrations
/// (see [OnboardingScreen] FLAG).
List<_OnboardingPage> _onboardingPages(AppLocalizations l10n) => [
      _OnboardingPage(
        icon: Icons.delivery_dining,
        title: l10n.onboardingSlide1Title,
        body: l10n.onboardingSlide1Body,
      ),
      _OnboardingPage(
        icon: Icons.mic,
        title: l10n.onboardingSlide2Title,
        body: l10n.onboardingSlide2Body,
      ),
      _OnboardingPage(
        icon: Icons.star,
        title: l10n.onboardingSlide3Title,
        body: l10n.onboardingSlide3Body,
      ),
    ];

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
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
      itemBuilder: (_, i) => _WalkthroughIllustration(icon: pages[i].icon),
    );
  }
}

/// Placeholder swap-point for the branded full-bleed slide artwork.
///
/// FLAG(figma): renders a tinted Material glyph on the brand-navy field
/// because the Figma slide illustrations have unresolved node ids in this
/// pass. Replace with `Image.asset(..., fit: BoxFit.cover)` once the three
/// exported assets land in `assets/illustrations/` — no layout change needed.
class _WalkthroughIllustration extends StatelessWidget {
  const _WalkthroughIllustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.secondaryContainer,
      child: Align(
        // Float the artwork above the bottom copy/control band.
        alignment: const Alignment(0.0, -0.35),
        child: Icon(
          key: const Key('onboarding.illustration'),
          icon,
          size: Sizes.twoHundredLarge,
          color: colorScheme.onSecondaryContainer,
        ),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// Three-page introductory onboarding carousel shown to first-launch users.
///
/// All visual primitives flow through OMDS: page indicator dots come from
/// [OmdsDotIndicator], the primary call-to-action uses [OmdsPrimaryButton],
/// spacing and sizing pull from [Spacing] / [Sizes], and animation timings
/// pull from [UIConstants].
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

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
      context.go('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = <_OnboardingPage>[
      _OnboardingPage(
        icon: Icons.delivery_dining,
        title: l10n.onboardingSlide1Title,
        subtitle: l10n.onboardingSlide1Body,
      ),
      _OnboardingPage(
        icon: Icons.mic,
        title: l10n.onboardingSlide2Title,
        subtitle: l10n.onboardingSlide2Body,
      ),
      _OnboardingPage(
        icon: Icons.star,
        title: l10n.onboardingSlide3Title,
        subtitle: l10n.onboardingSlide3Body,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            _BottomBar(
              pageCount: pages.length,
              currentPage: _currentPage,
              onNext: () => _onNext(pages.length),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pageCount,
    required this.currentPage,
    required this.onNext,
  });

  final int pageCount;
  final int currentPage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLastPage = currentPage >= pageCount - 1;
    return Padding(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OmdsDotIndicator(
            key: const Key('onboarding.dots'),
            currentIndex: currentPage,
            itemCount: pageCount,
          ),
          _OnboardingCtaButton(
            isLastPage: isLastPage,
            label: isLastPage ? l10n.onboardingGetStarted : l10n.onboardingNext,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _OnboardingCtaButton extends StatelessWidget {
  const _OnboardingCtaButton({
    required this.isLastPage,
    required this.label,
    required this.onTap,
  });

  final bool isLastPage;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OmdsPrimaryButton(
      key: Key(isLastPage ? 'onboarding.getStarted' : 'onboarding.next'),
      text: label,
      onTap: onTap,
      width: Sizes.twoHundredLarge,
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.twoXLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _OnboardingHeroIcon(icon: icon),
          const SizedBox(height: Spacing.fourXLarge),
          _OnboardingTitle(title: title),
          const SizedBox(height: Spacing.medium),
          _OnboardingSubtitle(subtitle: subtitle),
        ],
      ),
    );
  }
}

class _OnboardingHeroIcon extends StatelessWidget {
  const _OnboardingHeroIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Sizes.elevenXLarge (100dp) is the closest existing OMDS size token
    // to the original 120dp onboarding hero icon. Promotion of a
    // `Sizes.onboardingHero` token is tracked under JEEB-57.
    return Icon(
      icon,
      size: Sizes.elevenXLarge,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _OnboardingTitle extends StatelessWidget {
  const _OnboardingTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium,
      textAlign: TextAlign.center,
    );
  }
}

class _OnboardingSubtitle extends StatelessWidget {
  const _OnboardingSubtitle({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Text(
      subtitle,
      style: Theme.of(context).textTheme.bodyLarge,
      textAlign: TextAlign.center,
    );
  }
}

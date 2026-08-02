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
      // ignore: use_build_context_synchronously
      // DEFECT-3: Get Started + Skip land on the phone-OTP entry (`/register`,
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

/// The phone this screen is designed against.
const Size _onboardingScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate) — and roughly what an Android multi-window split leaves a
const Size _onboardingScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
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
        child: OnboardingScreen(onComplete: () {}),
      ),
    );

/// The reference reading: first launch, slide 1 of 3, the CTA still says
/// "Next" and Skip is already offered.
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
/// **This card overflows, and that is what it is for.** At 320x568, in English,
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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_page_dots.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/walkthrough_tracking_art.dart';
import 'widgets/walkthrough_trust_art.dart';
import 'widgets/walkthrough_voice_art.dart';

/// The three-slide walkthrough (JM-010), rebuilt on the MIDNIGHT board's
/// R5 + W1–W3 tiles.
///
/// Structure is a three-band column on the Midnight field: the wordmark +
/// EN/عربي toggle ([_OnboardingTopBar]), the swipeable [_WalkthroughStage], and
/// a **frosted navy sheet** ([_OnboardingSheet]) carrying the Arabic eyebrow,
/// the step copy, the page dots and the `Skip` / `Next →` footer. The stage is
/// deliberately ~40% empty — that emptiness is the design.
///
/// The field changes with the slide, because the tiles do: W1 draws an ORANGE
/// glow at centre-upper, W2 a PERIWINKLE wash at the same anchor and no orange
/// at all, and W3 draws no radial whatsoever under its night map.
///
/// Motion is the point of this screen — 19 of the board's 76 in-scope animated
/// elements live on these four tiles. Every period and delay is wired in the
/// three `widgets/walkthrough_*_art.dart` files, straight from
/// `docs/redesign-midnight/03-MOTION-NOTES.md`; nothing else on the screen
/// moves.
///
/// JM-010 destination (DEFECT-3, phone-OTP entry): "Get Started" on the last
/// slide AND "Skip" from any slide route to the **phone-OTP** flow
/// (`/register`, `registration_root`), NOT the email-first `/sign-up`. The LIVE
/// gateway has no `/v1/auth/login` or `/v1/auth/signup` route, so the email
/// funnel dead-ends (both 401).
///
/// Semantics contract (`docs/build-out/60_W0_TEST_PLAN.md` §2.2; coined §4):
///   - `walkthrough_slide_1` / `_slide_2` / `_slide_3` — the per-slide root
///     containers (each becomes visible as the carousel advances).
///   - `walkthrough_next_cta` — the advance button on slides 1–2.
///   - `walkthrough_get_started_cta` — the primary CTA on the last slide only.
///   - `walkthrough_skip_cta` — the Skip affordance, present from slide 1.
/// The foundation-era `onboarding_next_button` (primary CTA) and
/// `onboarding_headline` (the step copy) identifiers are preserved.
///
/// FR-P1-2: the EN/AR toggle ([OnboardingLanguageToggle]) drives
/// [LocaleCubit.setLocale], which rebuilds `MaterialApp.locale` and flips the
/// whole tree to RTL live (no restart).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete, this.slideOneVariant});

  /// Optional override for navigation. Tests inject this so the screen
  /// does not need a GoRouter in scope. Production leaves it null and
  /// `context.goNamed('register')` (the phone-OTP entry) handles navigation
  /// (DEFECT-3).
  final VoidCallback? onComplete;

  /// Which of the board's two placements of the same slide-1 art to draw.
  /// The app ships W1 (the walkthrough series W1–W3 is one coherent set); R5 is
  /// the same composition shifted, and the catalog mounts it for capture.
  final WalkthroughVoicePlacement? slideOneVariant;

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
      // DEFECT-3: Get Started + Skip land on the phone-OTP entry (`/register`,
      // `registration_root`), NOT the email-first `/sign-up`.
      // ignore: use_build_context_synchronously
      context.goNamed('register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _onboardingPages(
      AppLocalizations.of(context),
      slideOneVariant: widget.slideOneVariant ?? WalkthroughVoicePlacement.w1,
    );
    final page = pages[_currentPage.clamp(0, pages.length - 1)];
    // Every band of this screen is navy, so the status bar must paint LIGHT
    // icons; the nav bar sits on the frosted sheet, which is navy too.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Semantics(
        identifier: 'onboarding_root',
        container: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: JeebMidnightField(
            variant: JeebFieldVariant.content,
            glowPlacement: JeebFieldGlowPlacement.centerUpper,
            glowColor: _fieldGlow(context, page.field),
            // The tiles draw their own rings inside the art; the field's own
            // orbit decor is not on any of these four.
            showRings: false,
            showTwinkles: false,
            child: Column(
              children: [
                const _OnboardingTopBar(),
                Expanded(
                  child: _WalkthroughStage(
                    controller: _pageController,
                    pages: pages,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                  ),
                ),
                _OnboardingSheet(
                  pages: pages,
                  currentPage: _currentPage,
                  onNext: () => _onNext(pages.length),
                  onSkip: _completeAndNavigate,
                  onGetStarted: _completeAndNavigate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The radial each tile draws over the base wash, resolved to a colour the
/// field paints at [JeebFieldGlowPlacement.centerUpper].
///
/// W2's is a periwinkle WASH, not an orange glow — the distinction the board is
/// explicit about, and the reason this is not one constant.
Color _fieldGlow(BuildContext context, _SlideField field) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return switch (field) {
    // Board `rgba(215,59,0,.3) … 62%`; §8's hero band is .26–.30.
    _SlideField.accentGlow => context.jeebRoles.accent.withValues(
      alpha: _kAccentGlowAlpha,
    ),
    // Board `rgba(119,127,192,.28)`; §8 bands the wash at .18–.22 and the
    // wave-C ruling clamps to the top of it.
    _SlideField.periwinkleWash => scheme.secondary.withValues(
      alpha: _kWashAlpha,
    ),
    // W3 draws no radial at all under its night map.
    _SlideField.none => Colors.transparent,
  };
}

/// Board top bar: `padding:18px 24px 0`; 18 sits between two spacing rungs.
const double _kTopBarTopPadding = 18;

/// The Jeeb wordmark on the navy field (white fills + accent strokes).
const String _kWordmarkAsset = 'assets/brand/jeeb_logo.svg';

/// Minimum height reserved for the animated slide copy, so the docked sheet
/// does not change height as the pager advances.
const double _kSlideCopyMinHeight = 120.0;

/// The sheet never grows past this fraction of the viewport — the guard that
/// keeps a 200% text scale scrolling inside the sheet instead of squeezing the
/// stage to nothing.
const double _kSheetMaxHeightFactor = 0.62;

/// R5/W1's `radial-gradient(… rgba(215,59,0,.3) …)`. §8 bands the HERO glow at
/// .26–.30, so the tile's own figure needs no clamp; .28 is the ratified rung.
const double _kAccentGlowAlpha = 0.28;

/// W2's `rgba(119,127,192,.28)`, clamped to the ratified .18–.22 wash band.
const double _kWashAlpha = 0.22;

/// Board sheet: `rgba(13,19,74,.7)` over a `1px rgba(255,255,255,.14)` hairline,
/// `border-radius:34px 34px 0 0`, `padding:30px 32px 28px`.
const double _kSheetFillOpacity = 0.7;
const EdgeInsetsGeometry _kSheetPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.twoXLarge,
  30,
  Spacing.twoXLarge,
  28,
);

/// Which radial the slide's tile draws over the base wash.
enum _SlideField { accentGlow, periwinkleWash, none }

/// Static slide content. Each slide's art is the tile's own composition; there
/// is no shared illustration asset left on this screen.
List<_OnboardingPage> _onboardingPages(
  AppLocalizations l10n, {
  required WalkthroughVoicePlacement slideOneVariant,
}) => [
  _OnboardingPage(
    title: l10n.onboardingSlide1Title,
    body: l10n.onboardingSlide1Body,
    tagline: l10n.onboardingTagline,
    semanticsLabel: l10n.onboardingSlide1Semantics,
    field: _SlideField.accentGlow,
    art: WalkthroughVoiceArt(placement: slideOneVariant),
  ),
  _OnboardingPage(
    title: l10n.onboardingSlide2Title,
    body: l10n.onboardingSlide2Body,
    tagline: l10n.walkthroughSlide2Tagline,
    semanticsLabel: l10n.onboardingSlide2Semantics,
    field: _SlideField.periwinkleWash,
    art: const WalkthroughTrustArt(),
  ),
  _OnboardingPage(
    title: l10n.onboardingSlide3Title,
    body: l10n.onboardingSlide3Body,
    tagline: l10n.walkthroughSlide3Tagline,
    semanticsLabel: l10n.onboardingSlide3Semantics,
    field: _SlideField.none,
    art: const WalkthroughTrackingArt(),
  ),
];

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.tagline,
    required this.semanticsLabel,
    required this.field,
    required this.art,
  });

  final String title;
  final String body;

  /// The Arabic brand eyebrow above the headline; Arabic in both locales.
  final String tagline;

  /// Localized screen-reader alt text for the slide art.
  final String semanticsLabel;

  /// Which radial this slide's tile draws.
  final _SlideField field;

  /// The tile-drawn stage composition.
  final Widget art;
}

/// Band 1: the wordmark and the EN/عربي language toggle on the navy field.
class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          _kTopBarTopPadding,
          Spacing.xLarge,
          0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              identifier: 'onboarding_wordmark',
              image: true,
              label: l10n.splashLogoSemantic,
              child: SvgPicture.asset(
                _kWordmarkAsset,
                height: Sizes.large,
                // A failed/slow decode leaves the navy field, never a broken
                // glyph.
                placeholderBuilder: (_) => const SizedBox(height: Sizes.large),
              ),
            ),
            OnboardingLanguageToggle(
              key: const Key('onboarding.languageToggle'),
              selectedValue: locale.languageCode,
              onChanged: (code) =>
                  context.read<LocaleCubit>().setLocale(Locale(code)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Supported onboarding locale language codes (FR-P1-2).
const String _kLangEn = 'en';
const String _kLangAr = 'ar';

/// The EN/عربي pill switch on the walkthrough's navy field (FR-P1-2).
///
/// The screen-local on-navy variant the kit sanctions: [JeebSegmentedToggle] is
/// the surface switch used elsewhere and must not be widened for a translucent
/// on-field track. Public because the screen's widget tests type-assert it.
class OnboardingLanguageToggle extends StatelessWidget {
  const OnboardingLanguageToggle({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  /// Board `padding:4` around the segments, `gap:5`.
  static const double trackPadding = Spacing.twoXSmall;
  static const double segmentGap = 5;

  /// The active locale's language code (`en` / `ar`).
  final String selectedValue;

  /// Fires with the tapped segment's language code.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      identifier: 'onboarding_language_toggle',
      container: true,
      explicitChildNodes: true,
      label: l10n.onboardingChooseLanguage,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: semantics.glassFill,
          border: Border.all(color: semantics.glassBorderStrong),
          borderRadius: BorderRadius.circular(JeebRadii.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.all(trackPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: segmentGap,
            children: [
              _LanguageSegment(
                identifier: 'onboarding_language_en',
                label: l10n.onboardingLanguageEnShort,
                isSelected: selectedValue == _kLangEn,
                onTap: () => onChanged(_kLangEn),
              ),
              _LanguageSegment(
                identifier: 'onboarding_language_ar',
                label: l10n.onboardingLanguageArShort,
                isSelected: selectedValue == _kLangAr,
                onTap: () => onChanged(_kLangAr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One segment: a WHITE pill with NAVY ink when selected (board `#fff` on
/// `--jeeb-navy`), bare periwinkle ink when not.
class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({
    required this.identifier,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// Board `padding:5px 13px`.
  static const EdgeInsetsGeometry padding = EdgeInsetsDirectional.symmetric(
    horizontal: 13,
    vertical: 5,
  );

  final String identifier;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: identifier,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // M5: R5/W1 list the `عربي` pill as still — selection swaps, no tween.
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isSelected ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(JeebRadii.pill),
          ),
          child: Text(
            label,
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              // Navy knockout on the white pill; periwinkle when idle.
              color: isSelected ? scheme.surface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Band 2: the swipeable stage. Each slide owns its whole composition — the
/// rings, the mic and the map all belong to a tile, not to the stage.
class _WalkthroughStage extends StatelessWidget {
  const _WalkthroughStage({
    required this.controller,
    required this.pages,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<_OnboardingPage> pages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    // MANDATORY: the Ø370 rings are wider than a 360dp device.
    return ClipRect(
      child: PageView.builder(
        key: const Key('onboarding.pager'),
        controller: controller,
        itemCount: pages.length,
        onPageChanged: onPageChanged,
        itemBuilder: (_, i) => Semantics(
          // walkthrough_slide_1 / _slide_2 / _slide_3 — per-slide root.
          identifier: 'walkthrough_slide_${i + 1}',
          container: true,
          child: Semantics(
            key: const Key('onboarding.illustration'),
            image: true,
            label: pages[i].semanticsLabel,
            child: ExcludeSemantics(
              child: KeyedSubtree(
                key: i == 0 ? const Key('onboarding.preview') : null,
                child: pages[i].art,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Band 3: the frosted navy sheet — Arabic eyebrow, step copy, page dots and
/// the `Skip` / `Next →` split footer.
///
/// This is the ONE surface on the screen that spends a real `BackdropFilter`
/// (§4 budgets ≤2); the floating art all ships pre-baked translucency.
class _OnboardingSheet extends StatelessWidget {
  const _OnboardingSheet({
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final isLast = currentPage >= pages.length - 1;
    const BorderRadius radius = BorderRadius.vertical(
      top: Radius.circular(JeebRadii.hero),
    );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: JeebGlassCapsule.heroBlur,
          sigmaY: JeebGlassCapsule.heroBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: _kSheetFillOpacity),
            borderRadius: radius,
            border: BorderDirectional(
              top: BorderSide(color: scheme.outline),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height * _kSheetMaxHeightFactor,
              ),
              child: SingleChildScrollView(
                // The sheet never scrolls at 1.0x text scale; this only rescues
                // very large accessibility scales.
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: _kSheetPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        // PoC Maestro identifier: the animated step copy is the
                        // screen's headline, asserted by id (i18n-safe).
                        identifier: 'onboarding_headline',
                        child: _SlideCopy(
                          key: const Key('onboarding.slideCopy'),
                          pages: pages,
                          currentPage: currentPage,
                        ),
                      ),
                      const SizedBox(height: Spacing.medium),
                      JeebPageDots(
                        key: const Key('onboarding.dots'),
                        count: pages.length,
                        activeIndex: currentPage,
                        identifier: 'onboarding_page_dots',
                        semanticLabel: l10n.onboardingPageIndicator(
                          currentPage + 1,
                          pages.length,
                        ),
                      ),
                      const SizedBox(height: Spacing.large),
                      JeebCtaFooter.split(
                        // The sheet already owns the 32px gutters.
                        padding: EdgeInsetsDirectional.zero,
                        leading: _OnboardingSkipButton(
                          label: l10n.onboardingSkip,
                          onTap: onSkip,
                        ),
                        trailing: _OnboardingCtaButton(
                          isLast: isLast,
                          nextLabel: l10n.onboardingNext,
                          getStartedLabel: l10n.onboardingGetStarted,
                          onNext: onNext,
                          onGetStarted: onGetStarted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet's copy block: Arabic eyebrow over the slide headline + body.
/// M5: R5/W1–W3 all list the headline as still, so it swaps, never fades.
class _SlideCopy extends StatelessWidget {
  const _SlideCopy({
    super.key,
    required this.pages,
    required this.currentPage,
  });

  final List<_OnboardingPage> pages;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final index = currentPage.clamp(0, pages.length - 1);
    final page = pages[index];
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kSlideCopyMinHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            // The brand slogan is Arabic in both locales, like the wordmark.
            textDirection: TextDirection.rtl,
            child: Text(
              page.tagline,
              textAlign: TextAlign.center,
              style: context.jeebText.titleProminent.copyWith(
                fontWeight: FontWeight.w700,
                color: context.jeebRoles.accent,
              ),
            ),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          OmdsWalkthroughStep(
            label: page.title,
            description: page.body,
            labelStyle: context.jeebText.h1.copyWith(
              color: scheme.onSurface,
            ),
            descriptionStyle: context.jeebText.body.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The primary CTA at the foot of the carousel — ORANGE on this board.
///
/// Carries TWO Semantics contracts at once:
///   - the foundation-era `onboarding_next_button`;
///   - the JM-010 contract id, which switches with the slide:
///     `walkthrough_next_cta` on slides 1–2, `walkthrough_get_started_cta` on
///     the last slide.
class _OnboardingCtaButton extends StatelessWidget {
  const _OnboardingCtaButton({
    required this.isLast,
    required this.nextLabel,
    required this.getStartedLabel,
    required this.onNext,
    required this.onGetStarted,
  });

  /// Board `gap:9` between the label and the arrow, glyph 18.
  static const double iconSpacing = 9;
  static const double iconSize = 18;

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
        child: JeebCtaButton.accent(
          key: Key(isLast ? 'onboarding.getStarted' : 'onboarding.next'),
          label: isLast ? getStartedLabel : nextLabel,
          onTap: isLast ? onGetStarted : onNext,
          // The last slide's CTA is a bare label on the tile — the arrow is the
          // advance affordance only.
          trailingIcon: isLast ? null : Icons.arrow_forward,
          mirrorIcons: true,
          iconSize: iconSize,
          iconSpacing: iconSpacing,
        ),
      ),
    );
  }
}

/// The Skip affordance, present from slide 1.
///
/// Carries the JM-010 coined id `walkthrough_skip_cta` and routes to the
/// phone-OTP entry (`/register`, DEFECT-3). Stays an [OmdsSkipButton]: the kit's
/// split footer documents 01 as its one consumer that passes one, and a test
/// pins the type.
class _OnboardingSkipButton extends StatelessWidget {
  const _OnboardingSkipButton({required this.label, required this.onTap});

  /// Board `padding:0 22px`, `height:56`, `15.5px / w600 / #8A93D8`.
  static const EdgeInsetsGeometry padding = EdgeInsetsDirectional.symmetric(
    horizontal: 22,
    vertical: Spacing.medium,
  );

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'walkthrough_skip_cta',
      button: true,
      child: OmdsSkipButton(
        key: const Key('onboarding.skip'),
        text: label,
        padding: padding,
        onTap: onTap,
        textStyle: context.jeebText.cardTitle.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

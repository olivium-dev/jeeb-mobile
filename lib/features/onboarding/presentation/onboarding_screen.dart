import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/directional_icons.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_mic_hero.dart';
import '../../../core/widgets/jeeb/jeeb_page_dots.dart';
import '../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../core/widgets/jeeb/jeeb_waveform.dart';
import '../../../l10n/app_localizations.dart';

/// Three-page introductory onboarding carousel shown to first-launch users
/// (JM-010 `walkthrough`).
///
/// Structure (redesign-2026-08 screen 01) is a **three-band column**, not a
/// full-bleed pager under a scrim: the wordmark + EN/عربي toggle
/// ([_OnboardingTopBar]) sit on the navy field, the swipeable
/// [_MarketplaceStage] fills the middle (decorative accent rings, the per-slide
/// artwork and the persistent decorative mic), and an opaque white
/// [_OnboardingSheet] is docked at the foot carrying the AR eyebrow, the step
/// copy, the page dots and the `Skip` / `Next →` split footer. The stage is
/// deliberately ~45% empty — that emptiness is the design.
///
/// JM-010 destination (DEFECT-3, phone-OTP entry): "Get Started" on the last
/// slide AND "Skip" from any slide route to the **phone-OTP** flow
/// (`/register`, `registration_root`), NOT the email-first `/sign-up`. The LIVE
/// gateway has no `/v1/auth/login` or `/v1/auth/signup` route, so the email
/// funnel dead-ends (both 401); the phone-OTP flow
/// (`/v1/auth/otp/request` → `/v1/auth/otp/verify`) is the only auth that
/// authenticates against it. The email `/login` + `/sign-up` screens are kept
/// (a later gateway fix may add those routes) and stay reachable FROM
/// `/register`, but they are no longer the forced entry. (Previously routed to
/// `/sign-up` under the CTO-D1 email-first funnel.)
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
/// Slide artwork: slide 1 is the **marketplace preview collage**
/// ([_MarketplacePreview]) — a static, decorative voice-note / request / offer
/// stack that shows what the product does, with no invented live data behind
/// it. Slides 2 and 3 keep their real exported brand vectors via
/// [SvgPicture.asset] (`onboarding_trusted_jeebers.svg`,
/// `onboarding_live_tracking.svg`). [_WalkthroughIllustration] isolates the
/// per-slide treatment; a slide with neither a collage nor an `asset` degrades
/// to the tinted [_OnboardingPage.icon] glyph, preserving the resilient
/// fallback for any future slide.
///
/// FR-P1-2: an EN/AR language toggle ([OnboardingLanguageToggle]) is anchored
/// in the top bar; selecting a locale drives [LocaleCubit.setLocale], which
/// rebuilds `MaterialApp.locale` and flips the entire tree to RTL live (no
/// restart).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  /// Optional override for navigation. Tests inject this so the screen
  /// does not need a GoRouter in scope. Production leaves it null and
  /// `context.goNamed('register')` (the phone-OTP entry) handles navigation
  /// (DEFECT-3).
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
      // DEFECT-3: Get Started + Skip land on the phone-OTP entry (`/register`,
      // `registration_root`), NOT the email-first `/sign-up`. The LIVE gateway
      // has no `/v1/auth/login` or `/v1/auth/signup` route, so the email funnel
      // dead-ends; the phone-OTP flow (`/v1/auth/otp/request` →
      // `/v1/auth/otp/verify`) is the only auth that works. The email screens
      // remain reachable from `/register` for a later gateway fix.
      // ignore: use_build_context_synchronously
      context.goNamed('register');
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
      child: Semantics(
        identifier: 'onboarding_root',
        container: true,
        child: Scaffold(
        backgroundColor: colorScheme.secondaryContainer,
        body: Column(
          children: [
            const _OnboardingTopBar(),
            Expanded(
              child: _MarketplaceStage(
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
    );
  }
}

/// Asset paths for the wired walkthrough slide illustrations (FR-P1-1; the
/// trusted-Jeebers slide-2 asset landed in FR-D1D2). Slide 1 no longer renders
/// an SVG — it carries the marketplace-preview collage instead.
const String _kTrustedJeebersAsset =
    'assets/illustrations/onboarding_trusted_jeebers.svg';
const String _kLiveTrackingAsset =
    'assets/illustrations/onboarding_live_tracking.svg';

/// The Jeeb wordmark on the navy field (white fills + accent strokes).
const String _kWordmarkAsset = 'assets/brand/jeeb_logo.svg';

/// Minimum height reserved for the animated slide copy, so the docked sheet
/// does not change height as the pager advances (it replaces
/// `OmdsWalkthroughSwitcher`'s fixed 170px box, which was taller than the
/// redesign's copy block).
const double _kSlideCopyMinHeight = 120.0;

/// The sheet never grows past this fraction of the viewport — the guard that
/// keeps a 200% text scale scrolling inside the sheet instead of squeezing the
/// stage to nothing.
const double _kSheetMaxHeightFactor = 0.62;

/// The two decorative accent rings behind the collage (`01-onboarding.html`
/// tpl 20-21: Ø380 @ α.10 and Ø270 @ α.18).
const double _kOuterRingRadius = 190.0;
const double _kInnerRingRadius = 135.0;
const double _kOuterRingAlpha = 0.10;
const double _kInnerRingAlpha = 0.18;

/// Vertical centre of the rings, as a fraction of the stage height — the board
/// draws them around the collage, not around the mic.
const double _kRingCentreFactor = 0.375;

/// Card tops as fractions of the stage height, so the collage scales on short
/// devices instead of colliding with the mic (board: 64 / 158 / 236 of a 618px
/// stage).
const double _kVoiceCardTop = 0.10;
const double _kRequestCardTop = 0.25;
const double _kOfferCardTop = 0.375;

/// On-navy glass fills for the offer card and the language toggle track
/// (`html` tpl 24, 40).
const double _kGlassFill = 0.10;
const double _kGlassBorder = 0.18;
const double _kToggleTrackFill = 0.08;
const double _kToggleTrackBorder = 0.16;
const double _kToggleIdleInk = 0.75;

/// Static slide content. Slide 1 renders the marketplace-preview collage;
/// slides 2–3 carry real exported SVGs. The [_OnboardingPage.icon] remains as a
/// resilient fallback only (rendered if a future slide ever ships without an
/// `asset` and without the collage — see [_WalkthroughIllustration]).
List<_OnboardingPage> _onboardingPages(AppLocalizations l10n) => [
      _OnboardingPage(
        icon: Icons.mic_none_rounded,
        asset: null,
        showsMarketplacePreview: true,
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
    this.showsMarketplacePreview = false,
  });

  /// Interim glyph, used only when [asset] is null and the slide carries no
  /// collage.
  final IconData icon;

  /// Bundled SVG illustration path, or null to fall back to the [icon] glyph.
  final String? asset;

  final String title;
  final String body;

  /// Localized screen-reader alt text for the illustration.
  final String semanticsLabel;

  /// Whether this slide renders the decorative marketplace-preview collage
  /// instead of an illustration asset (slide 1 only).
  final bool showsMarketplacePreview;
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
          Spacing.large,
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

/// The EN/عربي pill switch that sits on screen 01's navy field (FR-P1-2).
///
/// This is the **screen-local dark-on-navy variant** the kit sanctions
/// (redesign-2026-08 §5 #19): [JeebSegmentedToggle] is the light-surface
/// switch used by screen 20 and must not be widened for a translucent
/// on-navy track. Public because the screen's widget tests type-assert it.
///
/// Selecting a segment drives [LocaleCubit.setLocale] (via [onChanged]), which
/// persists the choice and rebuilds `MaterialApp.locale`, flipping the whole
/// tree to RTL for Arabic live (no restart). The segment [Row] mirrors under
/// RTL for free — nothing here is positioned.
class OnboardingLanguageToggle extends StatelessWidget {
  const OnboardingLanguageToggle({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  /// The active locale's language code (`en` / `ar`).
  final String selectedValue;

  /// Fires with the tapped segment's language code.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'onboarding_language_toggle',
      container: true,
      explicitChildNodes: true,
      label: l10n.onboardingChooseLanguage,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.onPrimary.withValues(alpha: _kToggleTrackFill),
          border: Border.all(
            color: colorScheme.onPrimary.withValues(alpha: _kToggleTrackBorder),
          ),
          borderRadius: OmdsBorderRadius.pill,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.twoXSmall),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageSegment(
                identifier: 'onboarding_language_en',
                label: l10n.onboardingLanguageEnShort,
                isSelected: selectedValue == _kLangEn,
                onTap: () => onChanged(_kLangEn),
              ),
              const SizedBox(width: Spacing.twoXSmall),
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

/// One segment of [OnboardingLanguageToggle]: a white pill when selected, bare
/// translucent ink when not.
class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({
    required this.identifier,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String identifier;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: identifier,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: UIConstants.animationNormal,
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: Spacing.twoXSmall,
            horizontal: Spacing.medium,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.onPrimary : Colors.transparent,
            borderRadius: OmdsBorderRadius.pill,
          ),
          child: Text(
            label,
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onPrimary.withValues(alpha: _kToggleIdleInk),
            ),
          ),
        ),
      ),
    );
  }
}

/// Band 2: the navy stage — decorative rings, the swipeable slide artwork and
/// the persistent decorative mic.
///
/// The rings and the mic are stage *chrome*: they do not move with the pager,
/// which is why they live here and not inside a slide. Both ignore pointers so
/// a swipe that starts on them still reaches the carousel beneath.
class _MarketplaceStage extends StatelessWidget {
  const _MarketplaceStage({
    required this.controller,
    required this.pages,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<_OnboardingPage> pages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    // MANDATORY: the Ø380 ring is wider than a 360dp device.
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AccentRingsPainter(color: context.jeebRoles.accent),
              ),
            ),
          ),
          _IllustrationCarousel(
            controller: controller,
            pages: pages,
            onPageChanged: onPageChanged,
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsetsDirectional.only(bottom: Spacing.xLarge),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: JeebMicHero.decorative(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two faint accent rings behind the collage.
///
/// A painter rather than two positioned circles: an Ø380 box inside a narrower
/// stage would need `UnconstrainedBox`, which throws debug overflow errors in
/// widget tests. A painter has no layout and no semantics, and the stage's
/// `ClipRect` bounds it.
class _AccentRingsPainter extends CustomPainter {
  const _AccentRingsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(
      size.width / 2,
      size.height * _kRingCentreFactor,
    );
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = UIConstants.strokeWidthThin;
    canvas.drawCircle(
      centre,
      _kOuterRingRadius,
      stroke..color = color.withValues(alpha: _kOuterRingAlpha),
    );
    canvas.drawCircle(
      centre,
      _kInnerRingRadius,
      stroke..color = color.withValues(alpha: _kInnerRingAlpha),
    );
  }

  @override
  bool shouldRepaint(_AccentRingsPainter oldDelegate) =>
      oldDelegate.color != color;
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

/// The per-slide artwork on the navy stage.
///
/// Slide 1 renders the decorative [_MarketplacePreview] collage; the other
/// slides render their exported SVG ([SvgPicture.asset]) when
/// [_OnboardingPage.asset] is set, and otherwise degrade to a tinted Material
/// glyph. Either way the artwork carries a localized semantic label so screen
/// readers announce the slide — and the collage's own decorative strings are
/// excluded beneath it, so the label is all that is read.
class _WalkthroughIllustration extends StatelessWidget {
  const _WalkthroughIllustration({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    if (page.showsMarketplacePreview) {
      return Semantics(
        key: const Key('onboarding.illustration'),
        image: true,
        label: page.semanticsLabel,
        child: const ExcludeSemantics(
          child: _MarketplacePreview(key: Key('onboarding.preview')),
        ),
      );
    }
    return Align(
      // Float the artwork above the bottom copy/control band.
      alignment: const Alignment(0.0, -0.35),
      child: Semantics(
        key: const Key('onboarding.illustration'),
        image: true,
        label: page.semanticsLabel,
        child: _IllustrationArtwork(page: page),
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

/// Slide 1's marketplace-preview collage: a voice note, the request it became
/// and a Jeeber's offer, stacked around the mic.
///
/// **Decorative and static by contract** (plan §6, screen-01 row): no live data
/// is invented here, nothing is tappable, and the whole subtree sits under an
/// `ExcludeSemantics` so the slide's own label is the only announcement.
class _MarketplacePreview extends StatelessWidget {
  const _MarketplacePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double stageHeight = constraints.maxHeight;
        return Stack(
          children: [
            PositionedDirectional(
              start: Spacing.xLarge,
              top: stageHeight * _kVoiceCardTop,
              child: const _VoiceNoteCard(),
            ),
            PositionedDirectional(
              end: Spacing.large,
              top: stageHeight * _kRequestCardTop,
              child: const _RequestCard(),
            ),
            PositionedDirectional(
              start: Spacing.threeXLarge,
              top: stageHeight * _kOfferCardTop,
              child: const _OfferCard(),
            ),
          ],
        );
      },
    );
  }
}

/// Radii for a chat-style card whose tail sits on the start (leading) corner.
const BorderRadiusDirectional _kTailStartRadius = BorderRadiusDirectional.only(
  topStart: Radius.circular(Spacing.medium),
  topEnd: Radius.circular(Spacing.medium),
  bottomEnd: Radius.circular(Spacing.medium),
  bottomStart: Radius.circular(Spacing.twoXSmall),
);

/// The same card with the tail on the end (trailing) corner.
const BorderRadiusDirectional _kTailEndRadius = BorderRadiusDirectional.only(
  topStart: Radius.circular(Spacing.medium),
  topEnd: Radius.circular(Spacing.medium),
  bottomStart: Radius.circular(Spacing.medium),
  bottomEnd: Radius.circular(Spacing.twoXSmall),
);

/// Collage card A: the recorded ask, transcribed in Lebanese Arabic.
class _VoiceNoteCard extends StatelessWidget {
  const _VoiceNoteCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: Sizes.twoHundredLarge),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: _kTailStartRadius,
        // R7 exception: a white card carries no shadow anywhere else on the
        // board, but this one floats on navy and needs the lift to read.
        boxShadow: JeebShadows.heroNavy,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const JeebWaveform.cardMark(),
              const SizedBox(width: Spacing.xSmall),
              Text(
                l10n.onboardingPreviewVoiceDuration,
                // The one standalone digit-leading run on this screen: without
                // an explicit direction `0:04` reorders under RTL.
                textDirection: TextDirection.ltr,
                style: context.jeebText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l10n.onboardingPreviewVoiceTranscript,
              style: context.jeebText.cardTitle.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collage card B: the structured request the voice note became.
class _RequestCard extends StatelessWidget {
  const _RequestCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: _kTailEndRadius,
        boxShadow: JeebShadows.heroNavy,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingPreviewRequestTitle,
            style: context.jeebText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          JeebTierChip(
            tier: JeebTier.flash,
            label: l10n.tierFlashTitle,
          ),
        ],
      ),
    );
  }
}

/// Collage card C: a Jeeber's reply — the only translucent card, so it reads as
/// the far side of the conversation.
class _OfferCard extends StatelessWidget {
  const _OfferCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: _kGlassFill),
        border: Border.all(
          color: colorScheme.onPrimary.withValues(alpha: _kGlassBorder),
        ),
        borderRadius: _kTailStartRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingPreviewOfferQuote,
            style: context.jeebText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: Sizes.threeXSmall),
          Text(
            // The ★ inherits this ink on purpose — a rating star is never
            // tinted yellow on this board.
            l10n.onboardingPreviewOfferMeta,
            style: context.jeebText.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Band 3: the opaque docked sheet — AR eyebrow, step copy, page dots and the
/// `Skip` / `Next →` split footer.
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
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = currentPage >= pages.length - 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Spacing.twoXLarge),
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
              padding: const EdgeInsets.all(Spacing.twoXLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    // PoC Maestro identifier: the animated step copy is the
                    // screen's headline. Exposing a stable `identifier` lets
                    // Maestro assert on the headline by id (i18n-safe),
                    // independent of visible text.
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
    );
  }
}

/// The sheet's copy block: the Arabic brand eyebrow over the slide's
/// headline + body, cross-faded as the pager advances.
///
/// A [ConstrainedBox] floor (not a fixed-height box) keeps the sheet from
/// jumping between slides while still letting a long translation grow.
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
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final index = currentPage.clamp(0, pages.length - 1);
    final page = pages[index];
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kSlideCopyMinHeight),
      child: AnimatedSwitcher(
        duration: UIConstants.animationNormal,
        child: Column(
          key: ValueKey<int>(index),
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              // The brand slogan is Arabic in both locales, like the wordmark.
              textDirection: TextDirection.rtl,
              child: Text(
                l10n.onboardingTagline,
                textAlign: TextAlign.center,
                style: context.jeebText.titleProminent.copyWith(
                  color: context.jeebRoles.accent,
                ),
              ),
            ),
            const SizedBox(height: Spacing.twoXSmall),
            OmdsWalkthroughStep(
              label: page.title,
              description: page.body,
              labelStyle: context.jeebText.h1.copyWith(
                letterSpacing: -0.6,
                color: colorScheme.primary,
              ),
              // Body ink is the warm brown `onSurfaceVariant`, never
              // periwinkle: periwinkle on white fails AA and a contrast test
              // guards it (plan §4.1).
              descriptionStyle: context.jeebText.body.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
/// On the last slide the tap routes to the phone-OTP entry (`/register`,
/// DEFECT-3); on earlier slides it advances the carousel.
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
    final colorScheme = Theme.of(context).colorScheme;
    // JM-010 id flips with the slide; the legacy `onboarding_next_button` id
    // wraps it so both contracts resolve to the same button.
    return Semantics(
      identifier: 'onboarding_next_button',
      child: Semantics(
        identifier:
            isLast ? 'walkthrough_get_started_cta' : 'walkthrough_next_cta',
        button: true,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: OmdsBorderRadius.pill,
            boxShadow: JeebShadows.ctaNavy,
          ),
          child: OmdsPrimaryButton(
            key: Key(isLast ? 'onboarding.getStarted' : 'onboarding.next'),
            text: isLast ? getStartedLabel : nextLabel,
            onTap: isLast ? onGetStarted : onNext,
            width: double.infinity,
            height: Sizes.fiveXLarge,
            // `jeebText.button` is ink-free by design, so the on-navy ink is
            // added here rather than inherited from the ambient body style.
            textStyle: context.jeebText.button.copyWith(
              color: colorScheme.onPrimary,
            ),
            icon: Icon(
              DirectionalIcons.forward(context),
              size: Sizes.large,
              color: colorScheme.onPrimary,
            ),
            iconPosition: IconPosition.trailing,
          ),
        ),
      ),
    );
  }
}

/// The Skip affordance, present from slide 1.
///
/// Carries the JM-010 coined id `walkthrough_skip_cta` (60_W0_TEST_PLAN §2.2/§4)
/// and routes to the phone-OTP entry (`/register`, DEFECT-3). The legacy
/// `Key('onboarding.skip')` is kept for the existing widget tests that find it
/// by key.
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

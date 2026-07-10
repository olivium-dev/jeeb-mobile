import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/shared/first_run/first_run.dart';

import 'support/sync_app_localizations.dart';

/// Wraps [OnboardingScreen] with the [OnboardingCubit] + [LocaleCubit] and a
/// minimal [MaterialApp] so widget tests don't need a full router in scope.
///
/// [localeCubit] is injected so a test can assert that selecting a language
/// chip drives [LocaleCubit.setLocale] (FR-P1-2).
Widget _harness({
  required OnboardingCubit cubit,
  required LocaleCubit localeCubit,
  VoidCallback? onComplete,
  Locale locale = const Locale('en'),
}) {
  return wrapForTest(
    MultiBlocProvider(
      providers: [
        BlocProvider<OnboardingCubit>.value(value: cubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
      ],
      child: OnboardingScreen(onComplete: onComplete),
    ),
    locale: locale,
  );
}

void main() {
  late SharedPreferences prefs;
  late OnboardingCubit cubit;
  late LocaleCubit localeCubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cubit = OnboardingCubit(prefs: prefs);
    localeCubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );
  });

  tearDown(() async {
    await cubit.close();
    await localeCubit.close();
  });

  testWidgets('renders all 3 onboarding slides and the Skip CTA', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    expect(find.byKey(const Key('onboarding.skip')), findsOneWidget);
    expect(find.byKey(const Key('onboarding.next')), findsOneWidget);
    expect(find.byKey(const Key('onboarding.dots')), findsOneWidget);
  });

  testWidgets('surfaces Maestro Semantics ids for walkthrough controls', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    expect(
      find.bySemanticsIdentifier(FirstRunSemanticsIds.onboardingScreen),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(FirstRunSemanticsIds.onboardingPager),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(
        FirstRunSemanticsIds.onboardingIllustrationSlide(0),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(FirstRunSemanticsIds.onboardingDots),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(FirstRunSemanticsIds.onboardingNextButton),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(FirstRunSemanticsIds.onboardingSkipButton),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(FirstRunSemanticsIds.onboardingLanguageToggle),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier(
        FirstRunSemanticsIds.onboardingGetStartedButton,
      ),
      findsOneWidget,
    );
  });

  // ---- Status-bar contrast: LIGHT icons over the navy hero ----

  testWidgets(
    'sets LIGHT status-bar icons so they stay legible on the navy hero',
    (tester) async {
      // The global overlay set in main() is Brightness.dark (for the light auth
      // screens); the walkthrough hero is brand-navy and must override to light
      // icons, scoped via an AnnotatedRegion so it never forces light icons on
      // the light screens elsewhere in the app.
      await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
      await tester.pump();

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(OnboardingScreen),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(
        region.value.statusBarIconBrightness,
        Brightness.light,
        reason: 'walkthrough status-bar icons must be light on the navy hero',
      );
      // statusBarBrightness is the iOS counterpart of the same intent: a DARK
      // bar background expects light content (SystemUiOverlayStyle.light).
      expect(region.value.statusBarBrightness, Brightness.dark);
    },
  );

  testWidgets('slide copy + Skip flow through OMDS components (OMDS upgrade)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Slide copy is rendered by OmdsWalkthroughStep via OmdsWalkthroughSwitcher
    // (was hand-rolled Text), matching the fleet reference walkthrough layout.
    expect(find.byType(OmdsWalkthroughSwitcher), findsOneWidget);
    expect(find.byType(OmdsWalkthroughStep), findsWidgets);
    // Full-bleed swipeable illustration carousel is the back layer.
    expect(find.byKey(const Key('onboarding.pager')), findsOneWidget);
    // The placeholder illustration is isolated behind a stable key so the
    // Figma asset swap is a one-line change (see FLAG in onboarding_screen.dart).
    expect(find.byKey(const Key('onboarding.illustration')), findsWidgets);
    // Skip is the sanctioned OmdsSkipButton, not OmdsPrimaryButton.text.
    expect(
      tester.widget(find.byKey(const Key('onboarding.skip'))),
      isA<OmdsSkipButton>(),
    );
  });

  testWidgets('localizes slide copy under Arabic (RTL-safe)', (tester) async {
    await tester.pumpWidget(
      _harness(
        cubit: cubit,
        localeCubit: localeCubit,
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    // The Arabic slide-1 title renders (proves ARB ar parity + RTL tree).
    // OmdsWalkthroughStep draws the label via RichText, so findRichText.
    expect(find.text('توصيل بالصوت أولًا', findRichText: true), findsWidgets);
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('onboarding.dots'))),
      ),
      TextDirection.rtl,
    );
  });

  testWidgets('Next CTA advances to the last slide and becomes Get Started', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Advance to slide 2
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    // Advance to slide 3 (last)
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding.getStarted')), findsOneWidget);
  });

  testWidgets(
    'tapping Skip marks onboarding as complete in SharedPreferences',
    (tester) async {
      expect(cubit.state, isFalse);
      var navigated = false;

      await tester.pumpWidget(
        _harness(
          cubit: cubit,
          localeCubit: localeCubit,
          onComplete: () => navigated = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('onboarding.skip')));
      await tester.pump(); // allow async complete() to run

      expect(cubit.state, isTrue);
      expect(navigated, isTrue);
    },
  );

  // ---- FR-P1-1: real slide illustrations wired ----

  String? svgAssetName(WidgetTester tester) {
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = svg.bytesLoader;
    return loader is SvgAssetLoader ? loader.assetName : null;
  }

  testWidgets('slide 1 renders the real voice-first SVG illustration', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Slide 1 is showing on first frame; its artwork is the exported SVG.
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(
      svgAssetName(tester),
      'assets/illustrations/onboarding_voice_first.svg',
    );
    // The illustration is announced to screen readers as an image.
    final semantics = tester.widget<FirstRunSemanticTarget>(
      find.byKey(const Key('onboarding.illustration')),
    );
    expect(semantics.image, isTrue);
    expect(semantics.label, isNotEmpty);
  });

  testWidgets('slide 3 title keeps "end to end" unbreakable so it wraps cleanly', (
    tester,
  ) async {
    // Bug fix: the headline previously wrapped as "Live tracking, end to / end",
    // orphaning a trailing "end". Non-breaking spaces (U+00A0) bind "end to end"
    // into one unit so the break falls after the comma instead.
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(OnboardingScreen)),
    );
    const nbsp = '\u00A0';
    expect(
      l10n.onboardingSlide3Title,
      'Live tracking, end${nbsp}to${nbsp}end',
      reason:
          'slide-3 headline must bind "end to end" with non-breaking spaces',
    );
    // Guard against a regression that reintroduces breakable spaces in the
    // bound phrase (which is what caused the orphaned "end").
    expect(
      l10n.onboardingSlide3Title.contains('end to end'),
      isFalse,
      reason: 'plain-space "end to end" reintroduces the awkward orphan wrap',
    );
  });

  testWidgets('slide 3 renders the real live-tracking SVG illustration', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Advance to the last slide.
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(
      svgAssetName(tester),
      'assets/illustrations/onboarding_live_tracking.svg',
    );
  });

  testWidgets(
    'slide 2 renders the real trusted-Jeebers SVG illustration (FR-D1D2)',
    (tester) async {
      await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
      await tester.pump();

      // Advance to slide 2.
      await tester.tap(find.byKey(const Key('onboarding.next')));
      await tester.pumpAndSettle();

      // FR-D1D2: slide 2's placeholder shield/check glyph was replaced with a
      // real exported brand vector, matching slides 1 and 3. The illustration
      // slot now hosts the trusted-Jeebers SvgPicture, NOT a Material Icon.
      final illustration = find.byKey(const Key('onboarding.illustration'));
      expect(
        find.descendant(of: illustration, matching: find.byType(SvgPicture)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: illustration, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        svgAssetName(tester),
        'assets/illustrations/onboarding_trusted_jeebers.svg',
      );
    },
  );

  // ---- FR-P1-2: EN/AR language toggle ----

  testWidgets('renders the EN/AR language toggle on onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    final toggle = find.byKey(const Key('onboarding.languageToggle'));
    expect(toggle, findsOneWidget);
    expect(tester.widget(toggle), isA<OmdsFilterChips<String>>());
    // Both options are present (native Arabic script + English).
    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
  });

  testWidgets(
    'selecting Arabic drives LocaleCubit.setLocale and persists the choice',
    (tester) async {
      await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
      await tester.pump();

      expect(localeCubit.state.languageCode, 'en');

      // Tap the Arabic chip.
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      // The toggle's contract: it flips the LocaleCubit + persists the choice.
      // In production app.dart binds MaterialApp.locale to this cubit via a
      // BlocBuilder, so the whole tree re-lays-out RTL live (no restart). The
      // 'localizes slide copy under Arabic (RTL-safe)' test above proves the
      // RTL render path itself under Locale('ar').
      expect(localeCubit.state.languageCode, 'ar');
      expect(prefs.getString('app.locale.languageCode'), 'ar');
    },
  );

  testWidgets(
    'language toggle reflects the active locale as the selected chip',
    (tester) async {
      // The toggle's selection tracks the LocaleCubit (the source of truth that
      // drives MaterialApp.locale in production), so seed it to Arabic.
      await localeCubit.setLocale(const Locale('ar'));

      await tester.pumpWidget(
        _harness(
          cubit: cubit,
          localeCubit: localeCubit,
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();

      final toggle = tester.widget<OmdsFilterChips<String>>(
        find.byKey(const Key('onboarding.languageToggle')),
      );
      // The chip bound to the active locale is the selected one.
      expect(toggle.selectedValue, 'ar');
    },
  );
}

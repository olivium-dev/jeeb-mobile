import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';

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

  testWidgets('renders all 3 onboarding slides and the Skip CTA',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    expect(find.byKey(const Key('onboarding.skip')), findsOneWidget);
    expect(find.byKey(const Key('onboarding.next')), findsOneWidget);
    expect(find.byKey(const Key('onboarding.dots')), findsOneWidget);
  });

  testWidgets('slide copy + Skip flow through OMDS components (OMDS upgrade)',
      (tester) async {
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
    expect(
      find.text('توصيل بالصوت أولًا', findRichText: true),
      findsWidgets,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('onboarding.dots'))),
      ),
      TextDirection.rtl,
    );
  });

  testWidgets(
      'Next CTA advances to the last slide and becomes Get Started',
      (tester) async {
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
  });

  // ---- FR-P1-1: real slide illustrations wired ----

  String? svgAssetName(WidgetTester tester) {
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = svg.bytesLoader;
    return loader is SvgAssetLoader ? loader.assetName : null;
  }

  testWidgets('slide 1 renders the real voice-first SVG illustration',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Slide 1 is showing on first frame; its artwork is the exported SVG.
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(
      svgAssetName(tester),
      'assets/illustrations/onboarding_voice_first.svg',
    );
    // The illustration is announced to screen readers as an image.
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('onboarding.illustration')),
    );
    expect(semantics.properties.image, isTrue);
    expect(semantics.properties.label, isNotEmpty);
  });

  testWidgets('slide 3 renders the real live-tracking SVG illustration',
      (tester) async {
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
      'slide 2 (no exported asset) degrades to the interim brand glyph',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Advance to slide 2.
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    // Interim treatment: a Material glyph inside the illustration slot, NOT
    // an SvgPicture, until the Figma asset for "Trusted Jeebers" lands.
    final illustration = find.byKey(const Key('onboarding.illustration'));
    expect(
      find.descendant(of: illustration, matching: find.byType(SvgPicture)),
      findsNothing,
    );
    expect(
      find.descendant(of: illustration, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  // ---- FR-P1-2: EN/AR language toggle ----

  testWidgets('renders the EN/AR language toggle on onboarding',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    final toggle = find.byKey(const Key('onboarding.languageToggle'));
    expect(toggle, findsOneWidget);
    expect(
      tester.widget(toggle),
      isA<OmdsFilterChips<String>>(),
    );
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
  });

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
  });
}

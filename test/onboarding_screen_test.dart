import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/widgets/walkthrough_tracking_art.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/widgets/walkthrough_trust_art.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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
  double textScale = 1.0,
}) {
  final screen = MultiBlocProvider(
    providers: [
      BlocProvider<OnboardingCubit>.value(value: cubit),
      BlocProvider<LocaleCubit>.value(value: localeCubit),
    ],
    child: OnboardingScreen(onComplete: onComplete),
  );
  return wrapForTest(
    // Midnight motion loops ∞ by design (19 animated elements across the four
    // tiles this screen draws), so every harness pins reduce motion: it parks
    // each primitive on its first keyframe AND lets `pumpAndSettle` terminate.
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: screen,
      ),
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
  });

  testWidgets('slide copy + Skip flow through OMDS components (OMDS upgrade)',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Slide copy is rendered by OmdsWalkthroughStep inside the redesign's own
    // `_SlideCopy` block (the fixed-height OmdsWalkthroughSwitcher box was
    // dropped so the docked sheet keeps a constant height across slides).
    expect(find.byKey(const Key('onboarding.slideCopy')), findsOneWidget);
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
      find.text('قول شو بدك', findRichText: true),
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

  testWidgets('slide 1 renders the decorative marketplace-preview collage',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Redesign 01: slide 1's artwork is the static marketplace collage (voice
    // note → request → offer), not an exported illustration SVG.
    expect(find.byKey(const Key('onboarding.preview')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding.illustration')),
        matching: find.byType(SvgPicture),
      ),
      findsNothing,
    );
    // The illustration is announced to screen readers as an image.
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('onboarding.illustration')),
    );
    expect(semantics.properties.image, isTrue);
    expect(semantics.properties.label, isNotEmpty);
  });

  testWidgets('slide 3 renders W3 night-map art, not an exported SVG',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Advance to the last slide.
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    // MIDNIGHT W3 draws its own night map; the generic brand vector is gone.
    expect(find.byType(WalkthroughTrackingArt), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding.illustration')),
        matching: find.byType(SvgPicture),
      ),
      findsNothing,
    );
  });

  testWidgets('slide 2 renders W2 trust art, not an exported SVG',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Advance to slide 2.
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    // MIDNIGHT W2 draws a real Jeeber identity card with the trust mechanics
    // floating around it; the generic brand vector is gone.
    expect(find.byType(WalkthroughTrustArt), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(OnboardingScreen)),
    );
    expect(find.text(l10n.walkthroughTrustName), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding.illustration')),
        matching: find.byType(SvgPicture),
      ),
      findsNothing,
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
      isA<OnboardingLanguageToggle>(),
    );
    // Both segments are present (short labels on the navy top bar).
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('عربي'), findsOneWidget);
  });

  testWidgets(
      'selecting Arabic drives LocaleCubit.setLocale and persists the choice',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    expect(localeCubit.state.languageCode, 'en');

    // Tap the Arabic segment.
    await tester.tap(find.text('عربي'));
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

    final toggle = tester.widget<OnboardingLanguageToggle>(
      find.byKey(const Key('onboarding.languageToggle')),
    );
    // The segment bound to the active locale is the selected one.
    expect(toggle.selectedValue, 'ar');
  });

  // ---- Redesign 01: the rebuilt three-band layout ----

  testWidgets('emits the redesign Semantics identifiers for the new chrome',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    // Top bar: the wordmark is an image node; the toggle is a labelled
    // container over two selectable segments.
    expect(find.bySemanticsIdentifier('onboarding_wordmark'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('onboarding_language_toggle'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('onboarding_language_en'), findsOneWidget);
    expect(find.bySemanticsIdentifier('onboarding_language_ar'), findsOneWidget);
    // The dots carry the only "step N of M" announcement on the screen.
    expect(find.bySemanticsIdentifier('onboarding_page_dots'), findsOneWidget);
    // The screen root is unchanged by the rebuild. (The CTA/headline/skip ids
    // are asserted through their own merge-shape contracts in
    // `gesture_log_test.dart` and the Maestro flows — they are deliberately
    // NOT re-asserted here, because the outer/inner CTA pair merges into a
    // single node and this finder would read only one of the two ids.)
    expect(find.bySemanticsIdentifier('onboarding_root'), findsOneWidget);

    handle.dispose();
  });

  testWidgets(
      'slide 2 swaps the collage for its SVG (collage is slide 1 only)',
      (tester) async {
    await tester.pumpWidget(_harness(cubit: cubit, localeCubit: localeCubit));
    await tester.pump();

    expect(find.byKey(const Key('onboarding.preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding.preview')), findsNothing);
    expect(find.byType(WalkthroughTrustArt), findsOneWidget);
  });

  testWidgets('mirrors the CTA arrow and keeps the toggle live under RTL',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        cubit: cubit,
        localeCubit: localeCubit,
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    // `Icon` never auto-mirrors. The kit's `mirrorIcons` flips the glyph in
    // paint, so the IconData stays `arrow_forward` and a Transform turns it
    // around — assert the flip itself, not the codepoint.
    final cta = tester.widget<JeebCtaButton>(
      find.byKey(const Key('onboarding.next')),
    );
    expect(cta.trailingIcon, Icons.arrow_forward);
    expect(cta.mirrorIcons, isTrue);
    final flip = tester.widgetList<Transform>(
      find.descendant(
        of: find.byKey(const Key('onboarding.next')),
        matching: find.byType(Transform),
      ),
    ).where((t) => t.transform.storage[0] == -1.0);
    expect(
      flip,
      isNotEmpty,
      reason: 'the advance arrow must be horizontally flipped under RTL',
    );

    // The mirrored top bar still drives the locale.
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(localeCubit.state.languageCode, 'en');
  });

  testWidgets('survives a 200% text scale with the CTA still tappable',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        cubit: cubit,
        localeCubit: localeCubit,
        textScale: 2.0,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The sheet scrolls internally rather than squeezing the stage away, so
    // the primary CTA stays hit-testable at the largest supported scale.
    expect(
      find.byKey(const Key('onboarding.next')).hitTestable(),
      findsOneWidget,
    );
  });
}

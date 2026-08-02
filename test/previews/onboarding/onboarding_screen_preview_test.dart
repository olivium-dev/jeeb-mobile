// Render tests for the OnboardingScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

const Key _dots = Key('onboarding.dots');
const Key _pager = Key('onboarding.pager');
const Key _next = Key('onboarding.next');
const Key _getStarted = Key('onboarding.getStarted');
const Key _languageToggle = Key('onboarding.languageToggle');

/// Surfaces big enough that a pinned device box plus its dev caption is never
/// clipped by the tester's default 800x600 desktop surface.
const Size _kPhoneSurface = Size(430, 900);
const Size _kCompactSurface = Size(360, 640);

/// Slide 3's headline binds "end to end" with NON-BREAKING spaces (U+00A0), the
/// fix for the orphaned trailing "end" that
const String _kNbsp = ' ';
const String _kSlide1Title = 'Voice-first deliveries';
const String _kSlide2Title = 'Trusted Jeebers, every time';
const String _kSlide3Title = 'Live tracking, end${_kNbsp}to${_kNbsp}end';
const String _kSlide2Body = 'Every Jeeber is vetted, rated, and accountable so '
    'your deliveries stay in safe hands.';

/// The five previews that render clean everywhere the shared suite pumps them.
const Map<String, Widget Function()> _kCleanPreviews =
    <String, Widget Function()>{
  'Slide 1 · voice-first': onboardingScreenSlide1,
  'Slide 2 · longest copy': onboardingScreenSlide2,
  'Slide 3 · Get Started': onboardingScreenLastSlide,
  'Arabic resolved · chip pinned': onboardingScreenArabicResolved,
  'Compact 320x568 · Get Started': onboardingScreenCompactLastSlide,
};

/// Wraps [preview] in the golden fallback family.
Widget Function() _fonted(Widget Function() preview) => () => Builder(
      builder: (BuildContext context) => Theme(
        data: withGoldenTestFonts(Theme.of(context)),
        child: preview(),
      ),
    );

/// [previewCanvas] with the real font faces on the theme and an optional text
/// scaler — the only place a measurement on this screen is worth anything, and
Widget _onboardingScreenCanvas(
  Widget Function() preview,
  Locale locale, {
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: jeebPreviewHost(preview()),
  );
}

/// Pumps [preview] with framework errors intercepted rather than recorded.
Future<List<FlutterErrorDetails>> _pumpCatchingErrors(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await tester.pumpWidget(
      _onboardingScreenCanvas(preview, locale, textScale: textScale),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  /// Pumps [preview] on a surface large enough to hold its pinned device box.
  Future<void> pumpOnDevice(
    WidgetTester tester,
    Widget Function() preview, {
    Size surface = _kPhoneSurface,
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPreview(tester, _fonted(preview), locale: locale);
  }

  int slideOf(WidgetTester tester) =>
      tester.widget<OmdsDotIndicator>(find.byKey(_dots)).currentIndex;

  testPreviewsRender(
    'OnboardingScreen',
    <String, Widget Function()>{
      for (final MapEntry<String, Widget Function()> entry
          in _kCleanPreviews.entries)
        entry.key: _fonted(entry.value),
    },
    // The dev caption is the only string that separates a phone card from the
    expectedText: const <String, String>{
      'Slide 1 · voice-first': OnboardingScreenCaptions.slide1,
      'Slide 2 · longest copy': OnboardingScreenCaptions.slide2,
      'Slide 3 · Get Started': OnboardingScreenCaptions.lastSlide,
      'Arabic resolved · chip pinned': OnboardingScreenCaptions.arabicResolved,
      'Compact 320x568 · Get Started':
          OnboardingScreenCaptions.compactLastSlide,
    },
  );

  group('OnboardingScreen previews · the slide each card is parked on', () {
    // NB: one preview per test — see the file header. Pumping a second preview

    testWidgets('slide 1 · the entry state, Next, first dot', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(tester, onboardingScreenSlide1);

      expect(slideOf(tester), 0);
      expect(find.text(_kSlide1Title, findRichText: true), findsOneWidget);
      expect(find.byKey(_next), findsOneWidget);
      expect(find.byKey(_getStarted), findsNothing);
      expect(
        find.bySemanticsIdentifier('walkthrough_next_cta'),
        findsOneWidget,
      );
      // Skip is present from slide 1 (60_W0_TEST_PLAN §2.2).
      expect(find.bySemanticsIdentifier('walkthrough_skip_cta'), findsOneWidget);
    });

    testWidgets('slide 2 · the longest copy, still Next', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(tester, onboardingScreenSlide2);

      expect(slideOf(tester), 1);
      expect(find.text(_kSlide2Title, findRichText: true), findsOneWidget);
      expect(find.text(_kSlide1Title, findRichText: true), findsNothing);
      expect(find.byKey(_next), findsOneWidget);
      expect(find.byKey(_getStarted), findsNothing);
    });

    testWidgets('slide 3 · Get Started, and the headline keeps its NBSPs', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(tester, onboardingScreenLastSlide);

      expect(slideOf(tester), 2);
      expect(find.byKey(_getStarted), findsOneWidget);
      expect(find.byKey(_next), findsNothing);
      expect(
        find.bySemanticsIdentifier('walkthrough_get_started_cta'),
        findsOneWidget,
      );
      // The past bug this slide carries: the headline used to wrap as
      expect(find.text(_kSlide3Title, findRichText: true), findsOneWidget);
      expect(
        find.text('Live tracking, end to end', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('the compact card parks on slide 3 too', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingScreenCompactLastSlide,
        surface: _kCompactSurface,
      );

      expect(slideOf(tester), 2);
      expect(find.byKey(_getStarted), findsOneWidget);
    });
  });

  group('OnboardingScreen previews · the language chip', () {
    String? chipOf(WidgetTester tester) => tester
        .widget<OmdsFilterChips<String>>(find.byKey(_languageToggle))
        .selectedValue;

    testWidgets('the reference cards follow the AMBIENT locale', (
      WidgetTester tester,
    ) async {
      // Nothing is persisted, so the cubit resolves to the device locale, which
      await pumpOnDevice(tester, onboardingScreenSlide1);
      expect(chipOf(tester), 'en');
      expect(find.text(_kSlide1Title, findRichText: true), findsOneWidget);

      await pumpOnDevice(
        tester,
        onboardingScreenSlide1,
        locale: const Locale('ar'),
      );
      expect(chipOf(tester), 'ar');
      expect(
        find.text('توصيل بالصوت أولًا', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('the pinned card keeps ar whatever the app locale is', (
      WidgetTester tester,
    ) async {
      // The persisted key is read before the device locale, so this state does
      await pumpOnDevice(tester, onboardingScreenArabicResolved);

      expect(chipOf(tester), 'ar');
      expect(find.text(_kSlide1Title, findRichText: true), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byKey(_dots))),
        TextDirection.ltr,
      );
    });

    testWidgets('both endonyms are offered, and neither is localized', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(tester, onboardingScreenSlide1);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });
  });

  group('OnboardingScreen previews · the 170 pt copy box', () {
    /// The `SizedBox` `OmdsWalkthroughSwitcher` hard-codes around the copy.
    Rect boxOf(WidgetTester tester) =>
        tester.getRect(find.byType(OmdsWalkthroughSwitcher));

    testWidgets('the compact ceiling card OVERFLOWS in English at 100% text', (
      WidgetTester tester,
    ) async {
      // FINDING, measured with the real faces on the 320x568 frame the app
      await tester.binding.setSurfaceSize(_kCompactSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        onboardingScreenCompactCeiling,
      );

      expect(
        caught,
        isNotEmpty,
        reason: 'the slide-2 body in a 170 pt box at 320 pt wide must still '
            'overflow — if this is now clean the switcher has been given a '
            'height that fits and the preview note should go',
      );
      for (final FlutterErrorDetails details in caught) {
        expect(
          details.exception.toString(),
          contains('overflowed'),
          reason: 'only the documented copy-box overflow is tolerated here',
        );
      }
      expect(tester.takeException(), isNull);

      // …and the copy really is outside the box, not merely close to its edge.
      expect(boxOf(tester).height, 170);
      expect(
        tester.getRect(find.text(_kSlide2Body)).bottom,
        greaterThan(boxOf(tester).bottom),
      );
    });

    testWidgets('the same card renders its own state while overflowing', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(_kCompactSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpCatchingErrors(tester, onboardingScreenCompactCeiling);

      expect(find.text(OnboardingScreenCaptions.compactCeiling), findsOneWidget);
      expect(slideOf(tester), 1);
      expect(find.text(_kSlide2Title, findRichText: true), findsOneWidget);
    });

    testWidgets('in ARABIC the same frame is clean — the copy is shorter', (
      WidgetTester tester,
    ) async {
      // Worth pinning next to the English failure: the ceiling on this screen
      await tester.binding.setSurfaceSize(_kCompactSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        onboardingScreenCompactCeiling,
        locale: const Locale('ar'),
      );

      expect(caught, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 200% text EVERY slide overflows, on the 390 pt phone too', (
      WidgetTester tester,
    ) async {
      // FINDING, and the reason both matrixed cards are matrixed: the 200%
      await tester.binding.setSurfaceSize(_kPhoneSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        for (final MapEntry<String, Widget Function()> card
            in <String, Widget Function()>{
          'slide 1': onboardingScreenSlide1,
          'slide 2': onboardingScreenSlide2,
          'slide 3': onboardingScreenLastSlide,
        }.entries) {
          final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
            tester,
            card.value,
            locale: locale,
            textScale: 2.0,
          );

          expect(
            caught,
            isNotEmpty,
            reason: '${card.key} · ${locale.languageCode} · 200% must overflow '
                'the 170 pt copy box',
          );
          for (final FlutterErrorDetails details in caught) {
            expect(details.exception.toString(), contains('overflowed'));
          }
          expect(boxOf(tester).height, 170);
          // Reset between cards: the host element must be REPLACED, or the
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    });

    testWidgets('and the box does not grow — 170 pt at 100% and at 200%', (
      WidgetTester tester,
    ) async {
      // The number is a constant in `OmdsWalkthroughSwitcher`, not a layout
      await tester.binding.setSurfaceSize(_kPhoneSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpCatchingErrors(tester, onboardingScreenSlide1);
      expect(boxOf(tester).height, 170);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpCatchingErrors(tester, onboardingScreenSlide1, textScale: 2.0);
      expect(boxOf(tester).height, 170);
    });
  });

  group('OnboardingScreen previews · the pinned device frames', () {
    testWidgets('the phone cards pin 390 pt, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await pumpOnDevice(tester, onboardingScreenSlide1);
      expect(tester.getSize(find.byKey(_pager)).width, 390);
    });

    testWidgets('the compact cards pin the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        onboardingScreenCompactLastSlide,
        surface: _kCompactSurface,
      );
      expect(tester.getSize(find.byKey(_pager)), const Size(320, 568));
    });
  });
}

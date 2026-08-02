// Render tests for the OnboardingScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Three things shape this file.
//
// **Every card paints slide copy, and three of the six paint the SAME slide.**
// The walkthrough's headline goes through `OmdsWalkthroughStep`, which draws it
// with `RichText` — so `find.text` needs `findRichText: true` to see it at all,
// and the compact cards are the phone cards again at another frame size. So
// `expectedText` pins the dev caption each preview carries
// ([OnboardingScreenCaptions]), which proves each card rendered its own
// FIXTURE. Proof that each rendered its own STATE is the slide: which page the
// carousel is parked on, which headline is up and which label the CTA carries,
// asserted per state in the groups below.
//
// **One preview per test.** `previewCanvas` produces the same widget types for
// every preview, so pumping a second one into the same tester UPDATES the host
// element instead of replacing it — the slide driver's `initState` never runs
// again and the second card silently stays on the first card's slide. The one
// place two pumps share a test is the ambient-locale pair, where the point IS
// that the element survives and only the locale changes.
//
// **Fonts.** `preview_test_harness.dart` does not load real faces, so text lays
// out in Flutter's 1-em square test font — Latin ~2x too wide, Arabic ~2.4x.
// This screen is nothing but text in fixed-height boxes, so every number below
// would be fiction under that face. `loadInterTestFont()` registers the
// production Inter faces and the deterministic Noto Arabic subset, and
// `_fonted` puts the Arabic family on the theme's `fontFamilyFallback` (the
// canvas builds `AppTheme.light()` unmodified, and it has none). Every overflow
// pinned here is a DEVICE number.

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
/// `test/onboarding_screen_test.dart` guards at the ARB level. Spelled out here
/// so the previews assert the rendered string, not the ARB entry.
const String _kNbsp = ' ';
const String _kSlide1Title = 'Voice-first deliveries';
const String _kSlide2Title = 'Trusted Jeebers, every time';
const String _kSlide3Title = 'Live tracking, end${_kNbsp}to${_kNbsp}end';
const String _kSlide2Body = 'Every Jeeber is vetted, rated, and accountable so '
    'your deliveries stay in safe hands.';

/// The five previews that render clean everywhere the shared suite pumps them.
///
/// `Compact 320x568 · layout ceiling` is deliberately absent: it overflows, on
/// purpose, and gets the same three assertions in its own group below.
const Map<String, Widget Function()> _kCleanPreviews =
    <String, Widget Function()>{
  'Slide 1 · voice-first': onboardingScreenSlide1,
  'Slide 2 · longest copy': onboardingScreenSlide2,
  'Slide 3 · Get Started': onboardingScreenLastSlide,
  'Arabic resolved · chip pinned': onboardingScreenArabicResolved,
  'Compact 320x568 · Get Started': onboardingScreenCompactLastSlide,
};

/// Wraps [preview] in the golden fallback family.
///
/// The preview canvas builds `AppTheme.light()` / `AppTheme.dark()` directly and
/// neither carries a `fontFamilyFallback`, so a registered Arabic face is never
/// reached and every Arabic glyph falls back to the square test font. Wrapping
/// the previewed subtree in a `Theme` is the only seam a test has for that from
/// outside the harness.
Widget Function() _fonted(Widget Function() preview) => () => Builder(
      builder: (BuildContext context) => Theme(
        data: withGoldenTestFonts(Theme.of(context)),
        child: preview(),
      ),
    );

/// [previewCanvas] with the real font faces on the theme and an optional text
/// scaler — the only place a measurement on this screen is worth anything, and
/// the only way to reach the 200% rendering of the matrix from a test.
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
///
/// `tester.takeException()` cannot be used to inspect them: once a second error
/// lands the binding collapses both into "Multiple exceptions (2) were
/// detected…", which says nothing about what they were — and the cards that
/// park on a later slide raise TWO, one for the slide the first frame draws and
/// one for the slide the driver jumps to.
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
    // compact card of the same slide — see the file header. What each state
    // actually IS gets asserted below.
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
    // into the same tester does NOT re-run the slide driver's `initState`, so
    // the second card would silently stay on the first card's slide.

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
      // "Live tracking, end to / end", orphaning a trailing "end". The fix is
      // U+00A0 between the three words, so the plain-space spelling must NOT
      // be what is on screen.
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
      // the host seeds from `Localizations.localeOf`. This is what makes the AR
      // card of the matrix a coherent Arabic screen instead of an Arabic screen
      // with the English chip selected — the shipped app cannot diverge, since
      // `app.dart` drives `MaterialApp.locale` from this same cubit.
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
      // not move with the card — which is the whole reason the Screen Catalog
      // can show "Slides — AR" without flipping the running app. It is also the
      // divergent reading only a dev surface can produce: an English, LTR
      // walkthrough with العربية selected.
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
      // still supports, at the DEFAULT text size: the slide-2 copy does not fit
      // `OmdsWalkthroughSwitcher`'s hard-coded `height: 170`, so the last line
      // of the body is painted outside the box and clipped. Not truncated, not
      // scrollable, not ellipsized — just gone. This is why the card is pulled
      // out of the shared suite: the overflow is the point of it.
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
      // is a COPY ceiling, not a layout one. Arabic says the same thing in
      // fewer glyphs and fits the box the English body bursts.
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
      // rendering is not a narrow-phone edge case. On the reference 390x844
      // frame, in BOTH locales, all three slides burst the same fixed 170 pt
      // box — so a user at the accessibility ceiling loses the bottom of the
      // walkthrough copy on every slide of the app's first screen.
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
          // next card's slide driver never runs.
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    });

    testWidgets('and the box does not grow — 170 pt at 100% and at 200%', (
      WidgetTester tester,
    ) async {
      // The number is a constant in `OmdsWalkthroughSwitcher`, not a layout
      // outcome, so it does not respond to the text scaler at all. That is the
      // mechanism behind both findings above, pinned on its own so a fix that
      // makes the box flexible fails HERE rather than in six places.
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
      // the host would measure 800 here, and none of this layout applies there.
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

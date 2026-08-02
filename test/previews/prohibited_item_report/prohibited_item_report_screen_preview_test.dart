// Render tests for the ProhibitedItemReportScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// ## Why every state is pinned by a CAPTION
//
// This screen renders five hardcoded English strings and one free-text field,
// and nothing else. Four of the eight states below therefore share every pixel
// of chrome — `Empty` and `Whitespace only` are pixel-for-pixel identical apart
// from the colour of one button — so there is no shipped string that says WHICH
// designed state a card is showing. The fixture paints a caption above each
// frame for exactly that reason (the same device the
// `ProfileUnavailableScreen` fixtures use), and that caption is what
// `expectedText` pins. The substance is in the `preview specifics` group below,
// which asserts the CTA gate, the frame geometry and the untranslated chrome.
//
// ## Fonts
//
// `loadInterTestFont()` runs before every test here, because the shared harness
// does not load fonts and Flutter's test face makes every glyph a 1-em square —
// Latin measures ~2x too wide, Arabic ~2.4x. Every geometry claim in this file,
// and in particular the ONE overflow it asserts, is measured through
// `withGoldenTestFonts`, which is the only way to get real Arabic metrics: the
// preview host builds `AppTheme.light()` unmodified and the theme carries no
// `fontFamilyFallback`, so under the shared harness every Arabic glyph falls
// back to the test face.
//
// ## Why `Typing · keyboard up` is not in the shared suite
//
// It overflows, by design of the preview and by defect of the screen: the body
// is a non-scrolling `Column` with a `Spacer()` and `Scaffold` hands it 216 pt
// less height once the keyboard is up. The shared suite asserts
// `takeException() == null` for every state, so this one gets a dedicated group
// that asserts the overflow instead — measured with real fonts, at a real
// device size, in both locales.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/prohibited_item_report/presentation/prohibited_item_report_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

// The captions, spelled out rather than imported from the fixtures. A preview
// quietly rewired to a different case then fails here instead of silently
// renaming what it claims to be.
const String _kEmptyCaption =
    'Empty · nothing typed · Report disabled · Phone 390 × 844';
const String _kFilledCaption =
    'Filled · one line typed · Report armed · Phone 390 × 844';
const String _kLongestCaption =
    'Longest · a paragraph in a four-line box · Phone 390 × 844';
const String _kLongestCompactCaption =
    'Longest · narrowest phone · Compact 320 × 568';
const String _kArabicCaption =
    'Arabic report · English chrome · Phone 390 × 844';
const String _kWhitespaceCaption =
    'Whitespace only · Report armed anyway · Phone 390 × 844';
const String _kNotchedCaption = 'Home indicator · CTA drawn into it · '
    'Notched 393 × 852 · inset 59/34';
const String _kKeyboardCaption = 'Typing · compact phone, keyboard up · '
    'Compact 320 × 568 · keyboard 216';

/// A fragment only the longest-content fixture carries, so a preview rewired to
/// a short description loses the one state that contests the 320 pt frame.
const String _kLongestFragment =
    'five-kilo camping gas cylinder from the shop under their building in';

/// A fragment only the Arabic fixture carries.
const String _kArabicFragment = 'طلب مني الزبون نقل قنينتين من الكحول';

/// The five hardcoded English strings this screen ships. Not one of them is an
/// ARB key, which is what the Arabic assertions below are about.
const List<String> _kUntranslatedChrome = <String>[
  'Report Prohibited Item',
  'Describe the prohibited item',
  'Attach Photo',
  'Report Item',
  'If the Client requested delivery of a prohibited item, report it here.',
];

/// `previewCanvas`, but with the deterministic Arabic face wired into the
/// theme. Used everywhere a geometry claim is made.
Widget _prohibitedItemReportCanvasWithFonts(
  Widget Function() preview,
  Locale locale,
) {
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
    home: jeebPreviewHost(preview()),
  );
}

Future<void> _pumpWithFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    _prohibitedItemReportCanvasWithFonts(preview, locale),
  );
  await tester.pumpAndSettle();
}

/// The screen's destructive CTA, as a widget, so `isEnabled` can be read.
OmdsPrimaryButton _reportButton(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(
      find.widgetWithText(OmdsPrimaryButton, 'Report Item'),
    );

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview except `Typing · keyboard up`, which overflows by design.
  testPreviewsRender(
    'ProhibitedItemReportScreen',
    const <String, Widget Function()>{
      'Empty · Report disabled': prohibitedItemReportScreenEmpty,
      'Filled · Report armed': prohibitedItemReportScreenFilled,
      'Longest · paragraph in a 4-line box': prohibitedItemReportScreenLongest,
      'Longest · compact 320': prohibitedItemReportScreenLongestCompact,
      'Arabic report · English chrome':
          prohibitedItemReportScreenArabicContent,
      'Whitespace only · armed anyway':
          prohibitedItemReportScreenWhitespaceOnly,
      'Notched · CTA under the home indicator':
          prohibitedItemReportScreenNotched,
    },
    expectedText: const <String, String>{
      'Empty · Report disabled': _kEmptyCaption,
      'Filled · Report armed': _kFilledCaption,
      'Longest · paragraph in a 4-line box': _kLongestCaption,
      'Longest · compact 320': _kLongestCompactCaption,
      'Arabic report · English chrome': _kArabicCaption,
      'Whitespace only · armed anyway': _kWhitespaceCaption,
      'Notched · CTA under the home indicator': _kNotchedCaption,
    },
  );

  group('ProhibitedItemReportScreen previews · Typing · keyboard up', () {
    // The one state the shared suite cannot host. Measured with real fonts on a
    // real 320 x 568 frame: the shortfall is the screen's, not the test face's.
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the body overflows once the keyboard is up · '
          '${locale.languageCode}', (WidgetTester tester) async {
        await _pumpWithFonts(
          tester,
          prohibitedItemReportScreenKeyboardOpen,
          locale: locale,
        );

        expect(find.text(_kKeyboardCaption), findsOneWidget);
        expect(
          tester.getSize(find.byType(ProhibitedItemReportScreen)),
          const Size(320, 568),
        );

        final Object? exception = tester.takeException();
        expect(
          exception,
          isA<FlutterError>(),
          reason: 'the body is a non-scrolling Column with a Spacer(), and '
              'Scaffold takes the 216 pt keyboard straight off its height',
        );
        expect(
          exception.toString(),
          contains('A RenderFlex overflowed by'),
        );
      });
    }
  });

  group('ProhibitedItemReportScreen preview specifics', () {
    testWidgets('the phone previews pin a 390 x 844 frame, not the canvas', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 x 600 surface: a preview that left its window
      // to the host would measure 800 x 600 here and none of this layout
      // applies there.
      await pumpPreview(tester, prohibitedItemReportScreenEmpty);

      expect(
        tester.getSize(find.byType(ProhibitedItemReportScreen)),
        const Size(390, 844),
      );
    });

    testWidgets('the compact preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(tester, prohibitedItemReportScreenLongestCompact);

      expect(
        tester.getSize(find.byType(ProhibitedItemReportScreen)),
        const Size(320, 568),
      );
    });

    testWidgets('the empty state disarms the destructive CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, prohibitedItemReportScreenEmpty);

      expect(_reportButton(tester).isEnabled, isFalse);
      // …and the Attach Photo affordance is offered regardless, since it is
      // never gated on anything.
      expect(find.widgetWithText(OmdsPrimaryButton, 'Attach Photo'),
          findsOneWidget);
    });

    testWidgets('one typed line arms it, and the text is on screen', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, prohibitedItemReportScreenFilled);

      expect(_reportButton(tester).isEnabled, isTrue);
      expect(
        find.text('Client asked me to carry an unsealed bottle of liquor.'),
        findsOneWidget,
      );
    });

    // The gate is `text.isNotEmpty`, never `text.trim().isNotEmpty`. Three
    // spaces are not a report, and this state is otherwise pixel-identical to
    // the empty one.
    testWidgets('whitespace alone arms the destructive CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, prohibitedItemReportScreenWhitespaceOnly);

      expect(
        _reportButton(tester).isEnabled,
        isTrue,
        reason: 'documents the missing trim() on the Report Item gate — the '
            'button is live on a description with no characters in it',
      );
    });

    testWidgets('a 343-character report is shown four lines at a time', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(tester, prohibitedItemReportScreenLongest);

      // `maxLines: 4` stops the box growing and scrolls inside it, with no
      // scrollbar and nothing saying there is more text below the fold.
      expect(tester.getSize(find.byType(TextField)).height, 120);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).maxLines,
        4,
      );
      expect(find.textContaining(_kLongestFragment), findsOneWidget);
    });

    // The screen imports no `AppLocalizations` at all: every string is a Dart
    // literal. Pumping it in Arabic mirrors the layout and translates nothing.
    testWidgets('the chrome stays English in the Arabic rendering', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(
        tester,
        prohibitedItemReportScreenArabicContent,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(
          tester.element(find.byType(ProhibitedItemReportScreen)),
        ),
        TextDirection.rtl,
        reason: 'the AR locale does mirror the layout…',
      );
      for (final String english in _kUntranslatedChrome) {
        expect(
          find.text(english),
          findsOneWidget,
          reason: '…and "$english" is a Dart literal, so it never translates',
        );
      }
      // The jeeber's own Arabic text is the only Arabic on the card.
      expect(find.textContaining(_kArabicFragment), findsOneWidget);
    });

    // `Scaffold` drops the TOP padding for a body under an `appBar` but not the
    // bottom one, and this body has no `SafeArea`. On a 393 x 852 notch the
    // home indicator claims y >= 818; the CTA is painted at 788..836.
    testWidgets('the Report CTA is painted into the home-indicator strip', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(tester, prohibitedItemReportScreenNotched);

      final double screenTop =
          tester.getTopLeft(find.byType(ProhibitedItemReportScreen)).dy;
      final Rect cta = tester
          .getRect(find.widgetWithText(OmdsPrimaryButton, 'Report Item'))
          .translate(0, -screenTop);

      const double indicatorTop = 852 - 34;
      expect(
        cta.bottom,
        greaterThan(indicatorTop),
        reason: 'the body has no SafeArea, so the Spacer() pushes the '
            'destructive CTA into the 34 pt the home indicator owns',
      );
      expect(cta.bottom, lessThanOrEqualTo(852));
    });
  });
}

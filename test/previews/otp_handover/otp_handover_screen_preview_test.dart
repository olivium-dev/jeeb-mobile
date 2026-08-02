// Render tests for the OtpHandoverScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`, with the deviations described
// below.
//
// This screen is two surfaces behind one flag. `isClient` picks the customer's
// SHOW-a-code body or the jeeber's ENTER-a-code body, and both then share the
// same loading and error branches — so a render-only check passes on the exact
// mis-wiring this feature has already shipped once (G4: the customer flipped
// into the jeeber's entry grid). Every state below is therefore pinned on a
// string only IT can produce, and the specifics group pins the structural claims
// a string cannot: which side is mounted, which body is up, and what is still
// live underneath a spinner.
//
// ## Why this suite builds its own canvas
//
// `previewCanvas` in the shared harness builds `AppTheme.light()` unmodified and
// loads no fonts, so every glyph lays out in Flutter's 1-em test face — Latin
// ~2x too wide, Arabic ~2.4x. The last three assertions below are about whether
// content FITS on the 320 pt floor; measured through the fake face they would
// report breakages that exist on no device. This suite loads the real Inter
// faces AND applies `withGoldenTestFonts`, which is what puts the Arabic
// fallback family on the theme's text roles — without it `loadInterTestFont`
// registers the Noto subset but nothing selects it.
//
// Measured that way, the SMS fallback, the Done body and the jeeber's grid all
// clear a 390 x 844 phone at 200% text, so nothing here claims they do not. The
// customer's code body on a 320 pt phone does not, and that is asserted with the
// exact pixel counts.
//
// ## Why two previews are not in the shared map
//
// `Client · code still loading` and `Jeeber · verifying` render a spinner and no
// copy of their own — the first has no text at all beyond the app bar, and the
// second is one dead button apart from `Jeeber · code entry`. There is no string
// that distinguishes either from a broken build of its neighbour, so they get
// their own group at the bottom, pinned the only way available: which indicator
// is mounted, and what is absent.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/widgets/handover_code_display.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The previews under test, by their `@JeebPreview(name:)`.
///
/// The two ticker-muted spinners are deliberately absent — see the header note
/// and their own group at the bottom.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Client · code ready': otpHandoverScreenClientCodeReady,
  'Client · SMS fallback': otpHandoverScreenClientSmsFallback,
  'Client · load failed': otpHandoverScreenClientLoadError,
  'Jeeber · code entry': otpHandoverScreenJeeberCodeEntry,
  'Jeeber · wrong code': otpHandoverScreenJeeberWrongCode,
  'Jeeber · attempts spent': otpHandoverScreenJeeberEscalated,
  'Jeeber · past the cap': otpHandoverScreenPastTheCap,
  'Jeeber · handover done': otpHandoverScreenJeeberSuccess,
  'Client · code ready · compact 320': otpHandoverScreenClientCodeReadyCompact,
  'Longest content · widened code · compact 320':
      otpHandoverScreenWidenedCodeCompact,
};

/// One string per state that no OTHER state below can produce.
///
/// The two code states carry different codes precisely so this map can exist:
/// the chrome around them is identical, so the digits are the only thing that
/// says which fixture was loaded. The jeeber states are separated by the
/// attempts hint, which is the one control on that side that counts.
const Map<String, String> _expectedText = <String, String>{
  'Client · code ready': '4821',
  'Client · SMS fallback': "We've sent your code by SMS",
  'Client · load failed': 'Unable to connect. Check your internet.',
  'Jeeber · code entry': 'Enter the OTP from the Client',
  'Jeeber · wrong code': '2 attempt(s) remaining',
  // The dialog title — the escalate modal is the state, not a side effect of it.
  'Jeeber · attempts spent': 'Too many incorrect attempts',
  // The defect this preview exists for: `maxAttempts - wrongAttempts` has no
  // floor, so a fourth wrong code prints a negative budget.
  'Jeeber · past the cap': '-1 attempt(s) remaining',
  'Jeeber · handover done': 'Delivery Complete!',
  // Three different codes across three code states, so a state rewired to a
  // neighbouring fixture shows the wrong digits rather than looking plausible.
  'Client · code ready · compact 320': '9061',
  'Longest content · widened code · compact 320': '481902',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
/// so Latin and Arabic measure the way they do on a device.
Widget _otpHandoverScreenCanvas(
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
    // The 200% rendering the `matrix: true` previews put in the canvas. The
    // canvas applies it through `Preview(textScaleFactor:)`, which lands on the
    // same `MediaQuery.textScaler` this sets.
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: jeebPreviewHost(preview()),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    _otpHandoverScreenCanvas(preview, locale, textScale: textScale),
  );
  await tester.pumpAndSettle();
}

/// The jeeber's 4-cell grid, and the customer's resend CTA — the two controls
/// that must never appear on the other side's surface (G4).
Finder get _otpGrid => find.byKey(const Key('otpHandover.input'));
Finder get _submitButton => find.byKey(const Key('otpHandover.submit'));
Finder get _resendButton => find.byKey(const Key('otpHandover.resendSms'));

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  group('OtpHandoverScreen previews', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (
          WidgetTester tester,
        ) async {
          await _pump(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    _expectedText.forEach((String state, String text) {
      testWidgets('$state renders its own state', (WidgetTester tester) async {
        await _pump(tester, _previews[state]!);

        expect(find.text(text), findsOneWidget);
      });
    });
  });

  group('OtpHandoverScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `_otpHandoverScreenCanvas` produces the same
    // widget types, so the `BlocProvider` element is UPDATED rather than
    // replaced and keeps the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt width, not the canvas surface',
        (WidgetTester tester) async {
      // The harness pumps an 800 x 600 surface: a preview that left its width to
      // the host would measure 800 here, and none of the layout under review
      // applies there.
      //
      // Only the WIDTH is assertable. The annotation asks for 390 x 844 and the
      // canvas gives it, but 844 does not fit a 600 pt test surface, so the
      // SizedBox is height-clamped here. Everything below that depends on a real
      // phone HEIGHT is therefore measured on the compact box, which does fit.
      await _pump(tester, otpHandoverScreenClientCodeReady);

      expect(tester.getSize(find.byType(OtpHandoverScreen)).width, 390);
    });

    testWidgets('the ceiling preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenWidenedCodeCompact);

      expect(
        tester.getSize(find.byType(OtpHandoverScreen)),
        const Size(320, 568),
      );
    });

    // G4, at screen level: the customer's surface shows a code and offers NO
    // code entry. The pre-fix build flipped them into the jeeber's grid — a dead
    // end for a code they were never shown.
    testWidgets('the client previews never mount the jeeber entry grid', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenClientCodeReady);

      expect(find.byType(HandoverCodeDisplay), findsOneWidget);
      expect(_otpGrid, findsNothing);
      expect(_submitButton, findsNothing);
      // …and the app bar names the customer's screen, not the jeeber's.
      expect(find.text('Your OTP Code'), findsOneWidget);
    });

    testWidgets('the SMS fallback offers a resend and still no grid', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenClientSmsFallback);

      expect(_resendButton, findsOneWidget);
      expect(_otpGrid, findsNothing);
      expect(find.byType(HandoverCodeDisplay), findsNothing);
      // The body that explains the wait — the longest copy on this screen.
      expect(
        find.textContaining('Check the recipient phone'),
        findsOneWidget,
      );
    });

    testWidgets('the jeeber previews mount the grid and never a code display', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberCodeEntry);

      expect(_otpGrid, findsOneWidget);
      expect(_submitButton, findsOneWidget);
      expect(find.byType(HandoverCodeDisplay), findsNothing);
      expect(find.text('Enter OTP'), findsOneWidget);
      // Nothing has gone wrong yet, so there is no hint at all.
      expect(find.textContaining('attempt(s) remaining'), findsNothing);
    });

    // The failure body is the same widget on both sides, and it is a bare
    // `Center` — no pull-to-refresh, nothing scrollable behind it.
    testWidgets('the load failure is an error with a retry and nothing that '
        'scrolls', (WidgetTester tester) async {
      await _pump(tester, otpHandoverScreenClientLoadError);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(HandoverCodeDisplay), findsNothing);
      expect(_otpGrid, findsNothing);
      expect(find.byType(Scrollable), findsNothing);
    });

    // AC3: one wrong code swaps the instruction for the error copy. The
    // instruction and the hint are two different nodes and only the hint counts.
    testWidgets('a wrong code replaces the instruction and starts the count', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberWrongCode);

      expect(find.text('Incorrect code — please try again'), findsOneWidget);
      expect(find.text('Enter the OTP from the Client'), findsNothing);
      expect(find.text('2 attempt(s) remaining'), findsOneWidget);
    });

    // AC4: the cap. The dialog is modal and `submitOtp` returns early while
    // `escalate` is set, so the grid behind it is genuinely blocked.
    testWidgets('the cap opens the escalate dialog over a spent counter', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberEscalated);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Too many incorrect attempts'), findsOneWidget);
      expect(find.text('Escalate'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Behind the modal: the counter has reached zero, and the dialog's own
      // Cancel is what lets a jeeber spend a fourth attempt anyway.
      expect(find.text('0 attempt(s) remaining'), findsOneWidget);
      expect(_otpGrid, findsOneWidget);
    });

    // The defect `Jeeber · past the cap` exists for. `_AttemptHint` renders
    // `maxAttempts - wrongAttempts` with no floor and nothing caps the attempts,
    // so the fourth wrong code prints a negative budget — in both locales, since
    // the ARB is a plain `{count}` substitution.
    testWidgets('a fourth wrong code prints a NEGATIVE attempts hint', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenPastTheCap);

      expect(find.text('-1 attempt(s) remaining'), findsOneWidget);
      // …and `dismissEscalate` cleared the error, so the line above it has gone
      // back to the neutral instruction: the screen reads as fine while the
      // hint under it reports a negative budget.
      expect(find.text('Enter the OTP from the Client'), findsOneWidget);
      expect(find.text('Incorrect code — please try again'), findsNothing);
    });

    testWidgets('the negative hint survives the AR rendering too', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        otpHandoverScreenPastTheCap,
        locale: const Locale('ar'),
      );

      expect(find.textContaining('-1'), findsOneWidget);
    });

    // The terminal body. It is jeeber-side, and the copy is not: `isClient`
    // reaches the rate-now ROUTE but never the sentence above it.
    testWidgets('the done body is the jeeber surface with the client copy', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberSuccess);

      expect(find.text('Delivery Complete!'), findsOneWidget);
      expect(find.text('Rate your Jeeber'), findsOneWidget);
      // Only the BODY swaps: the entry grid is gone but the jeeber's app bar
      // title is still up, so the terminal state is still labelled "Enter OTP".
      expect(_otpGrid, findsNothing);
      expect(find.text('Enter OTP'), findsOneWidget);
    });

    // The ceiling. Six digits at `displayLarge` cannot fit 320 - 48 pt and the
    // panel has no `FittedBox` and no `maxLines`, so the code RE-FLOWS
    // mid-number: `481902` is laid out as two stacked fragments that read as two
    // numbers. Measured through the REAL faces — this is not a test-font
    // artefact.
    testWidgets('the widened code wraps mid-number on the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenWidenedCodeCompact);

      final RenderParagraph code = tester.renderObject<RenderParagraph>(
        find.text('481902'),
      );

      expect(
        code.getMaxIntrinsicWidth(double.infinity),
        greaterThan(code.size.width),
        reason: 'the code wants more width than the panel can give it',
      );
      expect(
        code.size.height,
        greaterThan(code.getMinIntrinsicHeight(double.infinity)),
        reason: 'so it is laid out on more than one line',
      );
    });

    // The finding the `matrix: true` on the two compact states exists for, and
    // the one that costs a SHIPPING customer something: at 200% text on the
    // 320 pt floor the customer's body runs past the bottom of the frame, and
    // nothing on this screen scrolls, so the rate-now CTA is simply unreachable.
    //
    // Measured through the REAL faces on the pinned 320 x 568 frame: 96 pt over
    // in EN with the shipping four digits, 224 pt with a widened six. The four
    // digit reading is the one that matters — it needs no gateway change, only a
    // small phone and large text.
    testWidgets('at 200% the compact code body overflows the floor and takes '
        'the CTA with it', (WidgetTester tester) async {
      await _pump(
        tester,
        otpHandoverScreenClientCodeReadyCompact,
        textScale: 2.0,
      );

      final Object? overflow = tester.takeException();
      expect(overflow, isFlutterError);
      expect(
        overflow.toString(),
        contains('A RenderFlex overflowed by 96 pixels on the bottom'),
      );

      final Rect frame = tester.getRect(find.byType(OtpHandoverScreen));
      final Rect cta = tester.getRect(find.text('Rate your Jeeber'));
      expect(cta.bottom, greaterThan(frame.bottom));
      // …and there is nothing that could bring it back.
      expect(find.byType(Scrollable), findsNothing);
    });

    testWidgets('a widened code overflows the floor twice as far', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenWidenedCodeCompact, textScale: 2.0);

      final Object? overflow = tester.takeException();
      expect(overflow, isFlutterError);
      expect(
        overflow.toString(),
        contains('A RenderFlex overflowed by 224 pixels on the bottom'),
      );
    });
  });

  // The two spinner states. Both are ticker-muted so `pumpAndSettle` returns
  // (a `CircularProgressIndicator` never stops scheduling frames), and neither
  // has copy of its own — so each is pinned by which indicator is mounted and by
  // what is absent.
  group('OtpHandoverScreen previews · the spinners', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Client · code still loading · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pump(tester, otpHandoverScreenClientLoading, locale: locale);

        expect(tester.takeException(), isNull);
      });

      testWidgets('Jeeber · verifying · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pump(tester, otpHandoverScreenJeeberSubmitting, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the client cold read is a bare spinner with no copy at all', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenClientLoading);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // None of the other three bodies.
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(HandoverCodeDisplay), findsNothing);
      expect(_resendButton, findsNothing);
      // The whole surface says nothing about the SMS being triggered on the
      // customer's behalf: the only text on it is the app bar title.
      expect(find.byType(Text), findsOneWidget);
      expect(find.text('Your OTP Code'), findsOneWidget);
    });

    testWidgets('the verify POST leaves the grid live under a dead button', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberSubmitting);

      // The button has swapped its label for the spinner — the ONLY thing on
      // screen that says a request is in flight.
      expect(find.text('Verify OTP'), findsNothing);
      expect(
        find.descendant(
          of: _submitButton,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // Everything else is exactly the entry state, including a grid that still
      // accepts input.
      expect(_otpGrid, findsOneWidget);
      expect(find.text('Enter the OTP from the Client'), findsOneWidget);
      final TextField cell = tester.widgetList<TextField>(
        find.descendant(of: _otpGrid, matching: find.byType(TextField)),
      ).first;
      expect(cell.enabled, isNot(false));
    });
  });

  // The previews and the Screen Catalog now read one fixture file. This group is
  // what stops that claim from quietly becoming false: the catalog is a
  // designer-facing tool, nothing else in `test/devtool/` renders THIS entry
  // (`catalog_size_test.dart` only counts states), and a fixture change that
  // broke a designed state would otherwise be invisible until a designer opened
  // the app.
  group('the extracted fixtures still drive the Screen Catalog', () {
    /// The seven states the catalog carried before the extraction, in order.
    /// Renaming one is a designer-facing change, not a refactor.
    const List<String> labels = <String>[
      'Client — Code Ready',
      'Client — SMS Fallback',
      'Client — Load Error',
      'Jeeber — Code Entry',
      'Jeeber — Wrong Code',
      'Jeeber — Escalated (Locked)',
      'Jeeber — Success',
    ];

    /// One string per catalog state that no other state in the entry produces —
    /// the same discipline the preview map above uses.
    const Map<String, String> catalogText = <String, String>{
      'Client — Code Ready': '4821',
      'Client — SMS Fallback': "We've sent your code by SMS",
      'Client — Load Error': 'Unable to connect. Check your internet.',
      'Jeeber — Code Entry': 'Enter the OTP from the Client',
      'Jeeber — Wrong Code': '2 attempt(s) remaining',
      'Jeeber — Escalated (Locked)': 'Too many incorrect attempts',
      'Jeeber — Success': 'Delivery Complete!',
    };

    CatalogEntry entry() => kScreenCatalog.singleWhere(
          (CatalogEntry e) => e.screen == 'OtpHandoverScreen',
        );

    test('the entry still carries its seven states, in order', () {
      expect(
        entry().states.map((CatalogState s) => s.label).toList(),
        labels,
      );
    });

    for (final String label in labels) {
      testWidgets('$label still renders its own state', (
        WidgetTester tester,
      ) async {
        final CatalogState state = entry().states.singleWhere(
              (CatalogState s) => s.label == label,
            );

        // The catalog path through the shared host, bare: no framing SizedBox
        // and no `TickerMode`, because on a device the device IS the frame.
        await tester.pumpWidget(
          previewCanvas(() => Builder(builder: state.builder), const Locale('en')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OtpHandoverScreen), findsOneWidget);
        expect(find.text(catalogText[label]!), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

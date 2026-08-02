// Render tests for the OtpHandoverScreen previews.

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
/// The two ticker-muted spinners are deliberately absent — see the header note
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
/// The two code states carry different codes precisely so this map can exist:
const Map<String, String> _expectedText = <String, String>{
  'Client · code ready': '4821',
  'Client · SMS fallback': "We've sent your code by SMS",
  'Client · load failed': 'Unable to connect. Check your internet.',
  'Jeeber · code entry': 'Enter the OTP from the Client',
  'Jeeber · wrong code': '2 attempt(s) remaining',
  // The dialog title — the escalate modal is the state, not a side effect of it.
  'Jeeber · attempts spent': 'Too many incorrect attempts',
  // The defect this preview exists for: `maxAttempts - wrongAttempts` has no
  'Jeeber · past the cap': '-1 attempt(s) remaining',
  'Jeeber · handover done': 'Delivery Complete!',
  // Three different codes across three code states, so a state rewired to a
  'Client · code ready · compact 320': '9061',
  'Longest content · widened code · compact 320': '481902',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
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
    testWidgets('the phone previews pin a 390 pt width, not the canvas surface',
        (WidgetTester tester) async {
      // The harness pumps an 800 x 600 surface: a preview that left its width to
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
    testWidgets('a wrong code replaces the instruction and starts the count', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberWrongCode);

      expect(find.text('Incorrect code — please try again'), findsOneWidget);
      expect(find.text('Enter the OTP from the Client'), findsNothing);
      expect(find.text('2 attempt(s) remaining'), findsOneWidget);
    });

    // AC4: the cap. The dialog is modal and `submitOtp` returns early while
    testWidgets('the cap opens the escalate dialog over a spent counter', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberEscalated);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Too many incorrect attempts'), findsOneWidget);
      expect(find.text('Escalate'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Behind the modal: the counter has reached zero, and the dialog's own
      expect(find.text('0 attempt(s) remaining'), findsOneWidget);
      expect(_otpGrid, findsOneWidget);
    });

    // The defect `Jeeber · past the cap` exists for. `_AttemptHint` renders
    testWidgets('a fourth wrong code prints a NEGATIVE attempts hint', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenPastTheCap);

      expect(find.text('-1 attempt(s) remaining'), findsOneWidget);
      // …and `dismissEscalate` cleared the error, so the line above it has gone
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
    testWidgets('the done body is the jeeber surface with the client copy', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberSuccess);

      expect(find.text('Delivery Complete!'), findsOneWidget);
      expect(find.text('Rate your Jeeber'), findsOneWidget);
      // Only the BODY swaps: the entry grid is gone but the jeeber's app bar
      expect(_otpGrid, findsNothing);
      expect(find.text('Enter OTP'), findsOneWidget);
    });

    // The ceiling. Six digits at `displayLarge` cannot fit 320 - 48 pt and the
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
      expect(find.byType(Text), findsOneWidget);
      expect(find.text('Your OTP Code'), findsOneWidget);
    });

    testWidgets('the verify POST leaves the grid live under a dead button', (
      WidgetTester tester,
    ) async {
      await _pump(tester, otpHandoverScreenJeeberSubmitting);

      // The button has swapped its label for the spinner — the ONLY thing on
      expect(find.text('Verify OTP'), findsNothing);
      expect(
        find.descendant(
          of: _submitButton,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // Everything else is exactly the entry state, including a grid that still
      expect(_otpGrid, findsOneWidget);
      expect(find.text('Enter the OTP from the Client'), findsOneWidget);
      final TextField cell = tester.widgetList<TextField>(
        find.descendant(of: _otpGrid, matching: find.byType(TextField)),
      ).first;
      expect(cell.enabled, isNot(false));
    });
  });

  // The previews and the Screen Catalog now read one fixture file. This group is
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

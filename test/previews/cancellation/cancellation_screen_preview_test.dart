// Render tests for the CancellationScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/cancellation/presentation/cancellation_screen.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _title = 'Cancel Delivery';
const String _prompt = 'Why are you cancelling?';
const String _confirm = 'Confirm Cancellation';
const String _cancelling = 'Cancelling…';
const String _otherHint = 'Please specify';
const String _genericError = 'An unexpected error occurred.';
const String _tooLate = 'Too late to cancel — your Jeeber is already on the way.';
const String _success = 'Delivery cancelled';

/// The client's four reasons, in `_reasons(isJeeber: false)` order.
const List<String> _clientReasons = <String>[
  'Changed my mind',
  'Taking too long',
  'Wrong address',
  'Other',
];

/// The Jeeber's five, in `_reasons(isJeeber: true)` order. Only `Other` is
/// shared with the client list.
const List<String> _jeeberReasons = <String>[
  'Cannot complete delivery',
  'Vehicle issue',
  'Emergency',
  'Prohibited item detected',
  'Other',
];

/// The Confirm button as the screen actually built it.
OmdsPrimaryButton _submitButton(WidgetTester tester) => tester.widget(
      find.descendant(
        of: find.byType(CancellationScreen),
        matching: find.byType(OmdsPrimaryButton),
      ),
    );

/// Pumps a preview into a real device box at a chosen text scale.
/// The size is load-bearing for every measurement below: `pumpPreview` renders
Future<void> _pumpAt(
  WidgetTester tester,
  Widget Function() preview, {
  required Size size,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps [reason] and then Confirm — the only way to reach any terminal state,
/// since `_selectedReason` is a private `State` field with no seam.
Future<void> _submit(WidgetTester tester, String reason) async {
  await tester.tap(find.text(reason));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_confirm));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CancellationScreen',
    const <String, Widget Function()>{
      'Client · nothing selected': cancellationScreenClientPicker,
      'Jeeber · nothing selected': cancellationScreenJeeberPicker,
      'Jeeber · compact 320x568': cancellationScreenCompact,
      'Submitting · confirm in flight': cancellationScreenSubmitting,
      'Rejected · 5xx (seeded)': cancellationScreenRejected,
      'Too late · 409 (seeded)': cancellationScreenTooLate,
    },
    expectedText: const <String, String>{
      'Client · nothing selected': CancellationScreenCaptions.clientPicker,
      'Jeeber · nothing selected': CancellationScreenCaptions.jeeberPicker,
      'Jeeber · compact 320x568': CancellationScreenCaptions.compact,
      'Submitting · confirm in flight': CancellationScreenCaptions.submitting,
      'Rejected · 5xx (seeded)': CancellationScreenCaptions.rejected,
      'Too late · 409 (seeded)': CancellationScreenCaptions.tooLate,
    },
  );

  group('CancellationScreen preview state', () {
    testWidgets('client picker: four reasons, Confirm DISABLED', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationScreenClientPicker);

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_prompt), findsOneWidget);
      for (final String reason in _clientReasons) {
        expect(find.text(reason), findsOneWidget, reason: reason);
      }
      // None of the Jeeber-only codes leak into the client list.
      expect(find.text('Cannot complete delivery'), findsNothing);
      expect(find.text('Vehicle issue'), findsNothing);

      // The disabled button is the entire gate between a mis-tap and a
      expect(_submitButton(tester).text, _confirm);
      expect(_submitButton(tester).isEnabled, isFalse);

      // The free-text box only exists once `other` is selected.
      expect(find.text(_otherHint), findsNothing);
    });

    testWidgets('jeeber picker: the five reasons the app cannot reach', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationScreenJeeberPicker);

      for (final String reason in _jeeberReasons) {
        expect(find.text(reason), findsOneWidget, reason: reason);
      }
      expect(find.text('Changed my mind'), findsNothing);
      expect(_submitButton(tester).isEnabled, isFalse);
    });

    testWidgets('submitting: the button is the ONLY in-flight signal', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationScreenSubmitting);

      expect(_submitButton(tester).text, _cancelling);
      expect(_submitButton(tester).isEnabled, isFalse);
      expect(find.text(_confirm), findsNothing);

      // Nothing else changes: no overlay, no progress indicator, no dimming.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (final String reason in _clientReasons) {
        expect(find.text(reason), findsOneWidget, reason: reason);
      }

      // And the rows stay LIVE while the POST is in the air: tapping one moves
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      await tester.tap(find.text('Wrong address'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(_submitButton(tester).isEnabled, isFalse);
    });
  });

  group('CancellationScreen · what the previews exposed', () {
    // A seeded terminal state is a state nobody can see. `BlocListener` fires
    for (final (String label, Widget Function() preview)
        in <(String, Widget Function())>[
      ('CancellationError', cancellationScreenRejected),
      ('CancellationTooLate', cancellationScreenTooLate),
    ]) {
      testWidgets('a seeded $label renders a pristine picker', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, preview);

        expect(find.byType(SnackBar), findsNothing);
        expect(find.text(_genericError), findsNothing);
        expect(find.text(_tooLate), findsNothing);
        // Byte for byte the `Client · nothing selected` card.
        for (final String reason in _clientReasons) {
          expect(find.text(reason), findsOneWidget, reason: reason);
        }
        expect(_submitButton(tester).text, _confirm);
        expect(_submitButton(tester).isEnabled, isFalse);
      });
    }

    testWidgets('a rejected cancel is one neutral 4s snackbar and no more', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationScreenRejected);
      await _submit(tester, 'Wrong address');

      // The gateway's own message ("gateway 502 (fixture)") is dropped by the
      expect(find.text(_genericError), findsOneWidget);
      expect(find.textContaining('502'), findsNothing);

      // `showOmdsSnackbar`, not `showOmdsErrorSnackbar`: the failure is not
      final SnackBar bar = tester.widget(find.byType(SnackBar));
      expect(bar.backgroundColor, isNull);
      expect(bar.duration, const Duration(seconds: 4));

      // And the form underneath is untouched: same reason still selected, same
      expect(_submitButton(tester).text, _confirm);
      expect(_submitButton(tester).isEnabled, isTrue);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(_genericError), findsNothing);
      expect(find.text(_prompt), findsOneWidget);
    });

    testWidgets('a 409 leaves the delivery re-submittable, forever', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationScreenTooLate);
      await _submit(tester, 'Changed my mind');

      expect(find.text(_tooLate), findsOneWidget);

      // Nothing marks the delivery as no-longer-cancellable. Let the snackbar
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(_tooLate), findsNothing);

      await tester.tap(find.text(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_tooLate), findsOneWidget);
      expect(_submitButton(tester).isEnabled, isTrue);
    });

    testWidgets('"Other" reveals a free-text box that nothing validates', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationScreenClientPicker);

      // No preview can OPEN here: `_selectedReason` is a private `State` field
      expect(find.text(_otherHint), findsNothing);
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      expect(find.text(_otherHint), findsOneWidget);

      // Confirm is enabled with the box still EMPTY — `otherDetails` goes to
      expect(_submitButton(tester).isEnabled, isTrue);
      await tester.tap(find.text(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_success), findsOneWidget);
    });

    testWidgets('the success sheet is reachable from the picker', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationScreenClientPicker);
      await _submit(tester, 'Wrong address');

      expect(find.text(_success), findsOneWidget);
      // Its Done button is NOT tapped here: `onDone` pops the ROOT navigator,
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('compact 320x568: the reason list scrolls, the CTA does not', (
      WidgetTester tester,
    ) async {
      await _pumpAt(
        tester,
        cancellationScreenCompact,
        size: const Size(320, 568),
      );

      expect(tester.takeException(), isNull);
      // The prompt and the CTA live OUTSIDE the scroll view, so they hold their
      expect(find.text(_prompt), findsOneWidget);
      expect(find.text(_confirm), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    // The accessibility ceiling on the smallest supported device. Measured, not
    testWidgets('compact at 200%: ONE reason of five, and a clipped CTA', (
      WidgetTester tester,
    ) async {
      await _pumpAt(
        tester,
        cancellationScreenCompact,
        size: const Size(320, 568),
        textScale: 2.0,
      );

      // No RenderFlex overflow anywhere — everything below is silent.
      expect(tester.takeException(), isNull);

      // The prompt (3 lines, 144pt) and the 48pt CTA are OUTSIDE the scroll
      expect(tester.getRect(find.text(_prompt)).height, 144.0);
      final Rect scroll = tester.getRect(find.byType(SingleChildScrollView));
      expect(scroll.height, 208.0);

      // Five rows need ~784pt in that 208pt window. The first one fits; the
      expect(tester.getRect(find.text('Cannot complete delivery')).bottom, 480.0);
      expect(tester.getRect(find.text('Vehicle issue')).top, 496.0);
      expect(tester.getRect(find.text('Other')).bottom, 1072.0);
      expect(scroll.bottom, 488.0);

      // The pinned CTA does not scale: `OmdsPrimaryButton` holds 48pt while the
      final RenderParagraph cta =
          tester.renderObject<RenderParagraph>(find.text(_confirm));
      expect(cta.size.height, 48.0);
      expect(cta.getMaxIntrinsicHeight(cta.size.width), 120.0);
    });

    testWidgets('AR at 200% on a phone: no overflow, last reason below fold', (
      WidgetTester tester,
    ) async {
      await _pumpAt(
        tester,
        cancellationScreenJeeberPicker,
        size: const Size(390, 844),
        textScale: 2.0,
        locale: const Locale('ar'),
      );

      // The Arabic reason labels wrap and grow their rows rather than
      expect(tester.takeException(), isNull);
      final Rect scroll = tester.getRect(find.byType(SingleChildScrollView));
      expect(scroll.height, 532.0);
      // ...and even on the roomier device the fifth reason is cut by the fold:
      expect(tester.getRect(find.text('أخرى')).top, 736.0);
      expect(tester.getRect(find.text('أخرى')).bottom, 784.0);
      expect(scroll.bottom, 764.0);
    });
  });
}

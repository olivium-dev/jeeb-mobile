// Render tests for the CancelRequestSheet previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/cancel_request/presentation/cancel_request_sheet.dart';

import '../preview_test_harness.dart';

/// The four ids 63_W1_TEST_PLAN §2.10 names, plus the error line cycle-4 added.
const String _sheetId = 'cancel_request_sheet';
const String _freeNoteId = 'cancel_request_free_note';
const String _errorId = 'cancel_request_error';
const String _confirmId = 'cancel_request_confirm_cta';
const String _keepId = 'cancel_request_keep_cta';

/// The D69 promise, verbatim from `lib/l10n/app_en.arb` — the one sentence this
/// sheet exists to say, and the string every state must keep showing.
const String _freeNote =
    'Cancelling is free before you accept an offer — nothing is charged.';

/// [pumpPreview] twice in ONE test is a trap on this widget: every preview
/// builds the same element shape (`Align > SizedBox > CancelRequestSheet >
Future<void> pumpPreviewFresh(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPreview(tester, preview);
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Confirming · in flight` — see the dedicated group.
  testPreviewsRender(
    'CancelRequestSheet',
    const <String, Widget Function()>{
      'Idle · free before accept': cancelRequestSheetIdle,
      'Failed · no longer cancellable (409)': cancelRequestSheetFailedConflict,
      'Failed · network (retryable)': cancelRequestSheetFailedNetwork,
      'Failed · generic (5xx)': cancelRequestSheetFailedGeneric,
      'Narrow phone · 320 pt': cancelRequestSheetNarrowPhone,
    },
    expectedText: const <String, String>{
      // Idle is the only state whose error slot is empty, so it is pinned on
      'Idle · free before accept': _freeNote,
      // The one dedicated failure string in the set.
      'Failed · no longer cancellable (409)':
          'This request can no longer be cancelled.',
      // Shared `loginNetworkError`: retryable, and the longest copy the sheet
      'Failed · network (retryable)':
          "Couldn't reach the server. Check your connection and try again.",
      // The catch-all 404 / 403 / 5xx / malformed-body copy.
      'Failed · generic (5xx)': "Couldn't cancel your request. Please try again.",
      // `Narrow phone` deliberately has no entry: it renders the same strings
    },
  );

  // `inFlight` swaps the confirm label for `OmdsButtonLoading`, i.e. an
  group('CancelRequestSheet previews · Confirming', () {
    Future<void> pumpConfirming(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(cancelRequestSheetConfirming, locale),
      );
      await tester.pump(); // localizations resolve → the sheet is built
      await tester.pump(const Duration(milliseconds: 300)); // switcher settles
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Confirming · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpConfirming(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Confirming renders its own state', (WidgetTester tester) async {
      await pumpConfirming(tester);

      // Still the cancel sheet, still promising the cancel is free…
      expect(find.text(_freeNote), findsOneWidget);
      // …but the confirm label has been replaced by a spinner, and the Keep
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Keep delivery'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Nothing has failed yet, so no error line.
      expect(find.bySemanticsIdentifier(_errorId), findsNothing);
    });

    testWidgets('both CTAs are inert while the cancel is in flight', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConfirming(tester);

      // A live tap target here is how a user double-fires the cancel, or tears
      for (final String id in <String>[_confirmId, _keepId]) {
        expect(
          tester.getSemantics(find.bySemanticsIdentifier(id)),
          containsSemantics(identifier: id, isButton: true, hasTapAction: false),
          reason: '$id must be inert while the cancel is in flight',
        );
      }
      handle.dispose();
    });
  });

  group('CancelRequestSheet preview specifics', () {
    testWidgets('Idle surfaces the JM-030 ids and NO error line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancelRequestSheetIdle);

      for (final String id in <String>[
        _sheetId,
        _freeNoteId,
        _confirmId,
        _keepId,
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      // NEGATIVE control: the idle sheet is the one state with an empty error
      expect(find.bySemanticsIdentifier(_errorId), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('every failed preview keeps the sheet open and retryable', (
      WidgetTester tester,
    ) async {
      for (final MapEntry<Widget Function(), String> entry
          in <Widget Function(), String>{
        cancelRequestSheetFailedConflict:
            'This request can no longer be cancelled.',
        cancelRequestSheetFailedNetwork:
            "Couldn't reach the server. Check your connection and try again.",
        cancelRequestSheetFailedGeneric:
            "Couldn't cancel your request. Please try again.",
      }.entries) {
        await pumpPreviewFresh(tester, entry.key);

        // sprint-009 cycle-4: a cancel the server did not confirm must SURFACE,
        expect(
          find.bySemanticsIdentifier(_errorId),
          findsOneWidget,
          reason: '${entry.value} must surface an error line',
        );
        expect(find.text(entry.value), findsOneWidget);
        // …and the sheet stays open with both CTAs live, so the user can retry
        expect(find.bySemanticsIdentifier(_sheetId), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Keep delivery'), findsOneWidget);
      }
    });

    testWidgets('the D69 free note survives every failure', (
      WidgetTester tester,
    ) async {
      // The error line is inserted BETWEEN the note and the CTAs, so a
      for (final Widget Function() preview in <Widget Function()>[
        cancelRequestSheetFailedConflict,
        cancelRequestSheetFailedNetwork,
        cancelRequestSheetFailedGeneric,
      ]) {
        await pumpPreviewFresh(tester, preview);
        expect(find.text(_freeNote), findsOneWidget);
      }
    });

    // The guard against every preview in this file rendering at one width: the
    testWidgets('Narrow phone pins 320 pt, the other states pin 390', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancelRequestSheetNarrowPhone);

      expect(tester.getSize(find.byType(CancelRequestSheet)).width, 320);
      // Same state as `Failed · network`, so it must still show that copy.
      expect(
        find.text("Couldn't reach the server. Check your connection and try again."),
        findsOneWidget,
      );

      for (final Widget Function() preview in <Widget Function()>[
        cancelRequestSheetIdle,
        cancelRequestSheetFailedConflict,
        cancelRequestSheetFailedNetwork,
        cancelRequestSheetFailedGeneric,
      ]) {
        await pumpPreviewFresh(tester, preview);
        expect(tester.getSize(find.byType(CancelRequestSheet)).width, 390);
      }
    });
  });
}

// Render tests for the CancelRequestSheet previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state here pins a DISTINCT string, which matters more on this widget
// than on most: six previews of one sheet differ ONLY in the single error line
// between the D69 free note and the CTAs, so a suite that merely asserted
// "something rendered" would stay green with all six showing the idle sheet.
// The two states whose difference is not copy get their own assertions instead:
// `Confirming · in flight` cannot be pumped with `pumpAndSettle` (the
// indeterminate `CircularProgressIndicator` inside `OmdsLoadingButton` never
// settles) and `Narrow phone · 320 pt` renders the same strings as
// `Failed · network` at a different width.

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
/// BlocProvider`), so Flutter updates in place, `BlocProvider.create` never
/// runs again, and the second pump renders the FIRST preview's cubit state
/// while quietly picking up the second one's width. Tearing the tree down in
/// between is what makes a loop over several previews actually pump several
/// states.
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
      // the D69 copy — and the group below proves the slot is empty.
      'Idle · free before accept': _freeNote,
      // The one dedicated failure string in the set.
      'Failed · no longer cancellable (409)':
          'This request can no longer be cancelled.',
      // Shared `loginNetworkError`: retryable, and the longest copy the sheet
      // lays out.
      'Failed · network (retryable)':
          "Couldn't reach the server. Check your connection and try again.",
      // The catch-all 404 / 403 / 5xx / malformed-body copy.
      'Failed · generic (5xx)': "Couldn't cancel your request. Please try again.",
      // `Narrow phone` deliberately has no entry: it renders the same strings
      // as `Failed · network` and is distinguished by geometry, asserted below.
    },
  );

  // `inFlight` swaps the confirm label for `OmdsButtonLoading`, i.e. an
  // indeterminate `CircularProgressIndicator`. `pumpAndSettle` (which
  // `pumpPreview` calls) never returns while one is on screen, so this preview
  // gets the same three assertions the shared suite makes — builds in EN,
  // builds in AR, renders its OWN state — driven by fixed pumps instead.
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
      // label has not. That pair is true of no other preview in this file.
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
      // the sheet down mid-call — the re-entrancy guard the cubit and the sheet
      // both implement.
      for (final String id in <String>[_confirmId, _keepId]) {
        expect(
          tester.getSemantics(find.bySemanticsIdentifier(id)),
          isSemantics(identifier: id, isButton: true, hasTapAction: false),
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
      // slot, and it is what every `failed` preview must be different from.
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
        // with the copy its OWN failure type maps to. If the error line ever
        // stops rendering, the P0 "cancellations never reach the server, but
        // the sheet says they did" bug is back.
        expect(
          find.bySemanticsIdentifier(_errorId),
          findsOneWidget,
          reason: '${entry.value} must surface an error line',
        );
        expect(find.text(entry.value), findsOneWidget);
        // …and the sheet stays open with both CTAs live, so the user can retry
        // or keep the request.
        expect(find.bySemanticsIdentifier(_sheetId), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Keep delivery'), findsOneWidget);
      }
    });

    testWidgets('the D69 free note survives every failure', (
      WidgetTester tester,
    ) async {
      // The error line is inserted BETWEEN the note and the CTAs, so a
      // regression that replaced the note with the error would still satisfy
      // the per-state pins above.
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
    // 320 pt state is distinguishable from `Failed · network` ONLY by geometry,
    // and the render tests pump an 800 px viewport that would hide a dropped
    // width pin.
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

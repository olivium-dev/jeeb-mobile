// Render tests for the DisputeStatusScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// ## Why `expectedText` pins captions
//
// `expectedText` pins the dev-chrome CAPTION each card carries, not screen
// copy. Four of these states have nothing of their own to pin: the cold read
// paints no text at all (`OmdsLoadingState` is constructed with no `message:`),
// `Open · no evidence attached` is copy-identical to the reference open
// dispute, the two blank-id cards render the same error page — which IS the
// finding — and the compact card is the longest-content card at a different
// width. A suite that pinned screen copy would either have nothing to pin or
// would pass with two previews wired to the same fixture. The
// `preview specifics` group below asserts the real state behind every caption,
// so the caption is never the whole proof.
//
// ## Fonts
//
// `loadInterTestFont()` is loaded before every test here, because the shared
// harness does not load fonts and Flutter's test face makes every glyph a 1-em
// square — Latin measures ~2x too wide, Arabic ~2.4x. Nothing in this file
// asserts an overflow, and the one geometry claim that could be distorted by
// the fake face (the 320 pt frame in Arabic) is measured through
// `withGoldenTestFonts`, which is the only way to get real Arabic metrics: the
// preview host builds `AppTheme.light()` unmodified and the theme carries no
// `fontFamilyFallback`, so under the shared harness every Arabic glyph still
// falls back to the test face.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/dispute_status_screen_fixtures.dart';
import 'package:jeeb_mobile/features/dispute_status/presentation/dispute_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The one string the longest-content fixture prints twice.
const String _kLongNoteFragment = 'issued a partial refund covering the';

/// `previewCanvas`, but with the deterministic Arabic face wired into the
/// theme.
///
/// The shared harness cannot do this — it builds `AppTheme.light()` directly —
/// and without it every Arabic glyph is laid out in the 1-em test face, which
/// is ~2.4x too wide. Used only where a geometry claim is being made.
Widget _disputeStatusCanvasWithFonts(
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
  await tester.pumpWidget(_disputeStatusCanvasWithFonts(preview, locale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'DisputeStatusScreen',
    const <String, Widget Function()>{
      'Open · under review': disputeStatusScreenOpenUnderReview,
      'Resolved · refund issued': disputeStatusScreenResolvedRefund,
      'Resolved · penalty, no amount': disputeStatusScreenResolvedPenalty,
      'Open · no evidence attached': disputeStatusScreenOpenNoEvidence,
      'Loading · cold read': disputeStatusScreenColdRead,
      'Error · network': disputeStatusScreenNetworkFailure,
      'Error · not found': disputeStatusScreenNotFound,
      'Error · session expired': disputeStatusScreenSessionExpired,
      'Blank id · Retry cannot fire': disputeStatusScreenBlankIdRetryInert,
      'Unknown wire state': disputeStatusScreenUnknownWireState,
      'Longest content': disputeStatusScreenLongestContent,
      'Compact viewport': disputeStatusScreenCompact,
    },
    expectedText: const <String, String>{
      'Open · under review': DisputeStatusScreenCaptions.openUnderReview,
      'Resolved · refund issued': DisputeStatusScreenCaptions.resolvedRefund,
      'Resolved · penalty, no amount':
          DisputeStatusScreenCaptions.resolvedPenalty,
      'Open · no evidence attached': DisputeStatusScreenCaptions.openNoEvidence,
      'Loading · cold read': DisputeStatusScreenCaptions.coldRead,
      'Error · network': DisputeStatusScreenCaptions.networkFailure,
      'Error · not found': DisputeStatusScreenCaptions.notFoundFallback,
      'Error · session expired': DisputeStatusScreenCaptions.sessionExpired,
      'Blank id · Retry cannot fire':
          DisputeStatusScreenCaptions.blankIdRetryInert,
      'Unknown wire state': DisputeStatusScreenCaptions.unknownWireState,
      'Longest content': DisputeStatusScreenCaptions.longestContent,
      'Compact viewport': DisputeStatusScreenCaptions.compact,
    },
  );

  group('DisputeStatusScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — the canvas produces the same widget types, so
    // the `BlocProvider` element is UPDATED rather than replaced and keeps the
    // cubit the first preview created.

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await pumpPreview(tester, disputeStatusScreenOpenUnderReview);

      expect(tester.getSize(find.byType(DisputeStatusScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenCompact);

      expect(tester.getSize(find.byType(DisputeStatusScreen)).width, 320);
    });

    testWidgets('the open dispute renders every part of the loaded body', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenOpenUnderReview);

      // The state row, in its OPEN reading.
      expect(find.text('Open — under review'), findsOneWidget);
      expect(find.text('Resolved'), findsNothing);
      // JM-065 AC1: the outcome card renders for an open dispute too, carrying
      // the pending-review body rather than a fabricated outcome.
      expect(
        find.bySemanticsIdentifier('dispute_status_outcome_note'),
        findsOneWidget,
      );
      expect(
        find.text(
          "We're reviewing your dispute and the attached evidence. "
          "You'll be notified of the outcome.",
        ),
        findsOneWidget,
      );
      // The full D53 evidence set, one line per attachment class.
      expect(find.text('Damaged item'), findsOneWidget);
      expect(find.text('Your note: Box arrived crushed.'), findsOneWidget);
      expect(find.text('2 photos attached'), findsOneWidget);
      expect(find.text('Chat thread attached (6 messages)'), findsOneWidget);
      expect(find.text('Delivery timeline attached (4 steps)'), findsOneWidget);
      // Both edges are offered.
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Back to chat'), findsOneWidget);
    });

    testWidgets('nothing on the loaded body says WHICH dispute this is', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `DisputeStatus` carries an id, an `orderRef` and a
      // `createdAt`; the body renders none of them, so two disputes on the same
      // order are the same picture. `orderRef` is read only to seed the support
      // form. If someone surfaces a reference here, this test fails and should
      // be updated — deliberately, not by accident.
      await pumpPreview(tester, disputeStatusScreenOpenUnderReview);

      expect(find.textContaining('ORD-4821'), findsNothing);
      expect(find.textContaining('dsp-1'), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('a resolved refund states the amount AND the currency', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenResolvedRefund);

      expect(find.text('Resolved'), findsOneWidget);
      expect(
        find.text('A refund of 35.00 USD was issued to you.'),
        findsOneWidget,
      );
      expect(find.text('No-show'), findsOneWidget);
      expect(find.text('1 photo attached'), findsOneWidget);
      expect(find.text('Voice note attached'), findsOneWidget);
      // …and still never says when it was resolved, although `resolvedAt` is on
      // the model.
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('a penalty outcome drops the figure rather than inventing one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenResolvedPenalty);

      expect(
        find.text('A penalty was applied to the other party.'),
        findsOneWidget,
      );
      // No amount on the wire → no amount on screen (AP-9 honesty).
      expect(find.textContaining('0.00'), findsNothing);
      // The back-office note renders as a second paragraph under the outcome.
      expect(
        find.text('Reviewed against the courier GPS trail.'),
        findsOneWidget,
      );
      expect(find.text('Chat thread attached (11 messages)'), findsOneWidget);
    });

    testWidgets('an empty evidence set renders a heading over nothing', (
      WidgetTester tester,
    ) async {
      // The finding, pinned: `_EvidenceCard` emits its title unconditionally
      // and its lines conditionally, so this card is "Evidence summary" above
      // blank space — no "nothing attached" line, no affordance, and no signal
      // that the section is finished rather than still loading.
      // `DisputeEvidenceSummary.hasAny` exists for this decision and is unread.
      await pumpPreview(tester, disputeStatusScreenOpenNoEvidence);

      expect(find.text('Evidence summary'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('dispute_status_evidence_summary'),
        findsOneWidget,
      );
      // Not one detail row is fabricated …
      expect(find.textContaining('photo'), findsNothing);
      expect(find.text('Voice note attached'), findsNothing);
      expect(find.textContaining('Chat thread'), findsNothing);
      expect(find.textContaining('Delivery timeline'), findsNothing);
      expect(find.textContaining('Your note'), findsNothing);
      // … and nothing replaces them either.
      expect(find.textContaining('No evidence'), findsNothing);
      expect(find.textContaining('Nothing attached'), findsNothing);
    });

    testWidgets('the cold read is a bare spinner with no copy and no exits', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenColdRead);

      expect(
        find.bySemanticsIdentifier('dispute_status_loading'),
        findsOneWidget,
      );
      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // `_LoadingBody` passes no `message:`, so there is no loading copy at all
      // — the caption above the frame is the only text on the card besides the
      // app-bar title.
      expect(find.text('Dispute status'), findsOneWidget);
      // None of the other three bodies …
      expect(find.bySemanticsIdentifier('dispute_status_state'), findsNothing);
      expect(find.bySemanticsIdentifier('dispute_status_error'), findsNothing);
      // … and no route to support while the read is in flight: the CTA lives
      // inside the loaded body.
      expect(find.text('Contact support'), findsNothing);
      expect(find.text('Back to chat'), findsNothing);
    });

    testWidgets('a network failure is the one error that names itself', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenNetworkFailure);

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('dispute_status_retry_cta'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      // The cold failure replaces the whole body — there is no dispute left.
      expect(find.bySemanticsIdentifier('dispute_status_state'), findsNothing);
    });

    testWidgets('a blank id fails as not-found before any repository is asked', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenNotFound);

      expect(find.text('This dispute could not be found.'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('dispute_status_error'),
        findsOneWidget,
      );
    });

    testWidgets('an expired session is told only that something went wrong', (
      WidgetTester tester,
    ) async {
      // The finding, pinned: `_ErrorBody._message` folds `unauthorized` in with
      // `unknown` and `null`, so a 401 reads exactly like an unclassified
      // failure and the only affordance is a Retry that will 401 again.
      await pumpPreview(tester, disputeStatusScreenSessionExpired);

      // The generic string, not a 401-specific one. (Scoped to the error
      // container: the dev caption above the frame says "session expired", and
      // the screen is what is under test.)
      expect(find.text('Could not load this dispute.'), findsOneWidget);
      final Finder errorBody = find.bySemanticsIdentifier(
        'dispute_status_error',
      );
      for (final String word in const <String>['session', 'sign in', 'Sign in']) {
        expect(
          find.descendant(of: errorBody, matching: find.textContaining(word)),
          findsNothing,
        );
      }
      // The only affordance is a Retry that will 401 again — there is no route
      // to a re-authentication anywhere on the page.
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Contact support'), findsNothing);
    });

    testWidgets('Retry on a blank id never issues a read', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `DisputeStatusCubit.refresh()` opens with the same
      // `disputeId.trim().isEmpty` guard `load()` uses, so the one affordance
      // the error page offers cannot fire. The repository behind this fixture
      // holds a RESOLVED dispute and is shared with the preview, so an empty
      // call list is proof that nothing asked it — not merely that the answer
      // did not change.
      expect(DisputeStatusScreenFixtures.blankIdRepository.fetchedIds, isEmpty);

      await pumpPreview(tester, disputeStatusScreenBlankIdRetryInert);
      expect(find.text('This dispute could not be found.'), findsOneWidget);

      final Finder retry = find.bySemanticsIdentifier(
        'dispute_status_retry_cta',
      );
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(
        DisputeStatusScreenFixtures.blankIdRepository.fetchedIds,
        isEmpty,
        reason: 'refresh() short-circuits on the blank id, so Retry is inert',
      );
      // …and the dispute that was one call away never appears.
      expect(find.text('This dispute could not be found.'), findsOneWidget);
      expect(find.text('Resolved'), findsNothing);
      expect(find.textContaining('dismissed'), findsNothing);
    });

    testWidgets('an unrecognized wire status is asserted as "under review"', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `_StateCard` asks only `dispute.isResolved`, so
      // `DisputeState.unknown` — which the Dio parser returns for ANY status it
      // does not enumerate — takes the else branch and gets the open label and
      // the reassuring body.
      await pumpPreview(tester, disputeStatusScreenUnknownWireState);

      expect(find.text('Open — under review'), findsOneWidget);
      expect(
        find.textContaining("We're reviewing your dispute"),
        findsOneWidget,
      );
      // The raw wire value is nowhere on screen, so nothing hints that the app
      // did not understand the status it was given.
      expect(find.textContaining('escalated'), findsNothing);
      // It is not shown as resolved either — this is a confident wrong answer,
      // not a visibly broken one.
      expect(find.text('Resolved'), findsNothing);
      expect(find.text('Fraud'), findsOneWidget);
    });

    testWidgets('the longest content prints the same note twice', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `DioDisputeStatusRepository` maps the wire `note`
      // onto BOTH `DisputeStatus.note` and `evidence.comment` (the latter via
      // `comment ?? note`), so a payload with a note and no comment renders the
      // paragraph under the outcome and again as "Your note: …".
      await pumpPreview(tester, disputeStatusScreenLongestContent);

      expect(find.textContaining(_kLongNoteFragment), findsNWidgets(2));
      expect(find.text(kDisputeStatusScreenLongNote), findsOneWidget);
      expect(
        find.text('Your note: $kDisputeStatusScreenLongNote'),
        findsOneWidget,
      );
    });

    testWidgets('a refund with no currency renders a bare figure', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `_formattedAmount` returns the number alone when
      // `currency` is null, and the Dio parser reads `refundAmount` and
      // `currency` independently — so a payload that omits the unit produces an
      // outcome line with no unit anywhere on it.
      await pumpPreview(tester, disputeStatusScreenLongestContent);

      expect(
        find.text('A refund of 1234.50 was issued to you.'),
        findsOneWidget,
      );
      // No unit reaches any pixel of the card — not beside the figure, not in
      // the heading, not in the note.
      for (final String unit in const <String>['USD', 'LBP', 'EUR', r'$']) {
        expect(find.textContaining(unit), findsNothing);
      }
    });

    testWidgets('the longest content wraps rather than clipping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenLongestContent);

      expect(find.text('Wrong item delivered'), findsOneWidget);
      expect(find.text('5 photos attached'), findsOneWidget);
      expect(find.text('Chat thread attached (142 messages)'), findsOneWidget);
      expect(find.text('Delivery timeline attached (18 steps)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the compact frame survives the ceiling in EN and AR, measured '
        'through the real faces', (WidgetTester tester) async {
      // Measured through `withGoldenTestFonts`, so the Arabic here is Noto Sans
      // Arabic rather than the 1-em test face. Nothing on this screen is pinned
      // outside the `ListView`, so the ceiling costs reach rather than layout in
      // both directions.
      await _pumpWithFonts(tester, disputeStatusScreenCompact);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(DisputeStatusScreen)).width, 320);

      await _pumpWithFonts(
        tester,
        disputeStatusScreenCompact,
        locale: const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('تم إرفاق المحادثة (142 رسالة)'), findsOneWidget);
    });
  });
}

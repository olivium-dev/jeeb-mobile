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
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
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

      expect(find.text('Open — under review'), findsOneWidget);
      expect(find.text('Resolved'), findsNothing);
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
      expect(find.text('Damaged item'), findsOneWidget);
      expect(find.text('Your note: Box arrived crushed.'), findsOneWidget);
      expect(find.text('2 photos attached'), findsOneWidget);
      expect(find.text('Chat thread attached (6 messages)'), findsOneWidget);
      expect(find.text('Delivery timeline attached (4 steps)'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Back to chat'), findsOneWidget);
    });

    testWidgets('nothing on the loaded body says WHICH dispute this is', (
      WidgetTester tester,
    ) async {
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
      expect(find.textContaining('0.00'), findsNothing);
      expect(
        find.text('Reviewed against the courier GPS trail.'),
        findsOneWidget,
      );
      expect(find.text('Chat thread attached (11 messages)'), findsOneWidget);
    });

    testWidgets('an empty evidence set renders a heading over nothing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenOpenNoEvidence);

      expect(find.text('Evidence summary'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('dispute_status_evidence_summary'),
        findsOneWidget,
      );
      expect(find.textContaining('photo'), findsNothing);
      expect(find.text('Voice note attached'), findsNothing);
      expect(find.textContaining('Chat thread'), findsNothing);
      expect(find.textContaining('Delivery timeline'), findsNothing);
      expect(find.textContaining('Your note'), findsNothing);
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
      expect(find.text('Dispute status'), findsOneWidget);
      expect(find.bySemanticsIdentifier('dispute_status_state'), findsNothing);
      expect(find.bySemanticsIdentifier('dispute_status_error'), findsNothing);
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
      await pumpPreview(tester, disputeStatusScreenSessionExpired);

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
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Contact support'), findsNothing);
    });

    testWidgets('Retry on a blank id never issues a read', (
      WidgetTester tester,
    ) async {
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
      expect(find.text('This dispute could not be found.'), findsOneWidget);
      expect(find.text('Resolved'), findsNothing);
      expect(find.textContaining('dismissed'), findsNothing);
    });

    testWidgets('an unrecognized wire status is asserted as "under review"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, disputeStatusScreenUnknownWireState);

      expect(find.text('Open — under review'), findsOneWidget);
      expect(
        find.textContaining("We're reviewing your dispute"),
        findsOneWidget,
      );
      expect(find.textContaining('escalated'), findsNothing);
      expect(find.text('Resolved'), findsNothing);
      expect(find.text('Fraud'), findsOneWidget);
    });

    testWidgets('the longest content prints the same note twice', (
      WidgetTester tester,
    ) async {
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
      await pumpPreview(tester, disputeStatusScreenLongestContent);

      expect(
        find.text('A refund of 1234.50 was issued to you.'),
        findsOneWidget,
      );
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

// The warm-failure strip. Seven main-flow screens record a failed refresh in
// state and render nothing; this is the surface that ends that, and the rule
// it enforces is that stale rows stay on screen.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/app_failure_copy.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'jeeb_failure_test_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget note, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(wrapMidnight(note, locale: locale));
  await tester.pumpAndSettle();
}

void main() {
  group('JeebRefreshFailedNote · copy', () {
    for (final Locale locale in kFailureLocales) {
      testWidgets('resolves the copy family · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          JeebRefreshFailedNote(
            failure: const NetworkFailure(offline: true),
            identifier: 'wallet_ledger_refresh_failed',
            onDismiss: () {},
          ),
          locale: locale,
        );

        final AppLocalizations l10n = l10nOf(tester, JeebRefreshFailedNote);
        expect(
          find.text(failureCopy(l10n, const NetworkFailure()).body),
          findsOneWidget,
        );
      });
    }

    testWidgets('messageOverride wins for a per-screen line', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebRefreshFailedNote(
          failure: const ServerFailure(status: 500),
          identifier: 'notifications_refresh_failed',
          messageOverride: 'Showing saved notifications.',
          onDismiss: () {},
        ),
      );

      expect(find.text('Showing saved notifications.'), findsOneWidget);
    });

    testWidgets('renders on the error tone, not a neutral strip', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebRefreshFailedNote(
          failure: const NetworkFailure(),
          identifier: 'reviews_refresh_failed',
          onDismiss: () {},
        ),
      );

      expect(
        tester.widget<JeebInfoNote>(find.byType(JeebInfoNote)).tone,
        JeebInfoNoteTone.error,
      );
    });
  });

  group('JeebRefreshFailedNote · acts', () {
    testWidgets('dismiss clears the note, retry refetches', (
      WidgetTester tester,
    ) async {
      int dismissed = 0;
      int retried = 0;

      await _pump(
        tester,
        JeebRefreshFailedNote(
          failure: const NetworkFailure(),
          identifier: 'wallet_ledger_refresh_failed',
          onDismiss: () => dismissed++,
          onRetry: () => retried++,
        ),
      );

      await tester.tap(
        find.bySemanticsIdentifier('wallet_ledger_refresh_failed_retry_cta'),
      );
      await tester.pump();
      expect(retried, 1);

      await tester.tap(
        find.bySemanticsIdentifier('wallet_ledger_refresh_failed_dismiss_cta'),
      );
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('no onRetry renders no retry glyph', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebRefreshFailedNote(
          failure: const NetworkFailure(),
          identifier: 'wallet_ledger_refresh_failed',
          onDismiss: () {},
        ),
      );

      expect(
        find.bySemanticsIdentifier('wallet_ledger_refresh_failed_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('wallet_ledger_refresh_failed_dismiss_cta'),
        findsOneWidget,
      );
    });

    testWidgets('the strip is announced when it appears', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebRefreshFailedNote(
          failure: const NetworkFailure(),
          identifier: 'wallet_ledger_refresh_failed',
          onDismiss: () {},
        ),
      );

      final SemanticsData data = tester
          .getSemantics(
            find.bySemanticsIdentifier('wallet_ledger_refresh_failed'),
          )
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      final AppLocalizations l10n = l10nOf(tester, JeebRefreshFailedNote);
      expect(
        data.label,
        failureCopy(l10n, const NetworkFailure()).body,
        reason: 'an announced node with no label of its own reads as silence',
      );
    });
  });

  test('an empty identifier is rejected at construction', () {
    expect(
      () => JeebRefreshFailedNote(
        failure: const NetworkFailure(),
        identifier: '',
        onDismiss: () {},
      ),
      throwsAssertionError,
    );
  });

  group('F6 · the note retires itself when the connection returns', () {
    late NetworkReachabilitySignals bus;

    setUp(() {
      bus = NetworkReachabilitySignals(minInterval: Duration.zero);
      NetworkReachabilitySignals.instance = bus;
    });

    tearDown(NetworkReachabilitySignals.debugReset);

    /// The offline -> online edge: the first observation is only a baseline.
    void reconnect() {
      bus
        ..debugObserve(online: false)
        ..debugObserve(online: true);
    }

    for (final Locale locale in kFailureLocales) {
      testWidgets(
        'a connectivity note dismisses itself on the edge · '
        '${locale.languageCode}',
        (WidgetTester tester) async {
          int dismissals = 0;
          await _pump(
            tester,
            JeebRefreshFailedNote(
              failure: const NetworkFailure(offline: true),
              identifier: 'order_history_refresh_failed',
              onDismiss: () => dismissals++,
            ),
            locale: locale,
          );
          expect(
            find.bySemanticsIdentifier('order_history_refresh_failed'),
            findsOneWidget,
          );

          reconnect();
          await tester.pump();
          expect(dismissals, 1);
        },
      );
    }

    testWidgets('a server failure is left alone — nothing about it changed', (
      WidgetTester tester,
    ) async {
      int dismissals = 0;
      await _pump(
        tester,
        JeebRefreshFailedNote(
          failure: const ServerFailure(status: 500),
          identifier: 'order_history_refresh_failed',
          onDismiss: () => dismissals++,
        ),
      );

      reconnect();
      await tester.pump();
      expect(dismissals, 0);
    });

    testWidgets('dismissOnReconnect:false opts a screen out', (
      WidgetTester tester,
    ) async {
      int dismissals = 0;
      await _pump(
        tester,
        JeebRefreshFailedNote(
          failure: const NetworkFailure(offline: true),
          identifier: 'order_history_refresh_failed',
          onDismiss: () => dismissals++,
          dismissOnReconnect: false,
        ),
      );

      reconnect();
      await tester.pump();
      expect(dismissals, 0);
    });
  });
}

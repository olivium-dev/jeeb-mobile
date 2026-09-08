// F14 / WP7-N1 / ES-20: a terminal failure gets the way out, a warm refresh
// failure keeps the dispute on screen, and an empty history still draws a card.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';
import 'package:jeeb_mobile/features/dispute_status/presentation/dispute_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const DisputeStatus _dispute = DisputeStatus(
  id: 'dsp-1',
  state: DisputeState.pending,
  orderRef: 'ORD-1',
);

class _CannedRepository implements DisputeStatusRepository {
  const _CannedRepository([this.dispute = _dispute]);

  final DisputeStatus dispute;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => dispute;
}

class _FailingRepository implements DisputeStatusRepository {
  const _FailingRepository(this.kind, this.failure);

  final DisputeStatusFailure kind;
  final AppFailure failure;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async =>
      throw DisputeStatusRepositoryException.classified(
        kind,
        appFailure: failure,
      );
}

/// First read lands; every read after it fails — the warm-failure lane.
class _RefreshFailingRepository implements DisputeStatusRepository {
  int calls = 0;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    calls += 1;
    if (calls == 1) return _dispute;
    throw const DisputeStatusRepositoryException.classified(
      DisputeStatusFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }
}

void main() {
  Widget harness(
    DisputeStatusRepository repo, {
    String id = 'dsp-1',
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: '/disputes/$id',
      routes: <RouteBase>[
        GoRoute(
          path: '/disputes/:id',
          builder: (_, s) => DisputeStatusScreen(
            disputeId: s.pathParameters['id'] ?? '',
            repository: repo,
          ),
        ),
        GoRoute(
          path: '/',
          name: 'shell',
          builder: (_, _) => const Scaffold(body: Text('shell')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  /// The history card sits below the fold; a ListView only builds what shows.
  Future<void> scrollToBottom(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('[${locale.languageCode}] a blank dispute id gets the way out, '
        'never an inert Retry', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(const _CannedRepository(), id: '%20', locale: locale),
      );
      await tester.pumpAndSettle();

      expect(byId('dispute_status_error'), findsOneWidget);
      expect(byId('dispute_status_exit_cta'), findsOneWidget);
      expect(byId('dispute_status_retry_cta'), findsNothing);
    });
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;
    for (final entry in <String, (DisputeStatusFailure, AppFailure)>{
      'notFound': (DisputeStatusFailure.notFound, const NotFoundFailure()),
      'unauthorized': (
        DisputeStatusFailure.unauthorized,
        const UnauthorizedFailure(),
      ),
    }.entries) {
      testWidgets('[$tag] ${entry.key} gets the way out, never a Retry', (
        tester,
      ) async {
        useReduceMotion(tester);
        await tester.pumpWidget(
          harness(
            _FailingRepository(entry.value.$1, entry.value.$2),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(byId('dispute_status_error'), findsOneWidget);
        expect(byId('dispute_status_exit_cta'), findsOneWidget);
        expect(byId('dispute_status_retry_cta'), findsNothing);
      });
    }
  }

  testWidgets('a network failure keeps a real Retry', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        const _FailingRepository(
          DisputeStatusFailure.network,
          NetworkFailure(offline: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(byId('dispute_status_retry_cta'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the loaded dispute mounted (WP7-N1)', (
    tester,
  ) async {
    useReduceMotion(tester);
    final repo = _RefreshFailingRepository();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    expect(byId('dispute_status_state'), findsOneWidget);

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(repo.calls, greaterThan(1));
    // The rows stay; only the strip reports the miss.
    expect(byId('dispute_status_state'), findsOneWidget);
    expect(byId('dispute_status_error'), findsNothing);
    expect(byId('dispute_status_refresh_error'), findsOneWidget);

    await tester.tap(byId('dispute_status_refresh_error_dismiss_cta'));
    await tester.pumpAndSettle();
    expect(byId('dispute_status_refresh_error'), findsNothing);
  });

  testWidgets('an empty status history still draws its card (ES-20)', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(harness(const _CannedRepository()));
    await tester.pumpAndSettle();
    await scrollToBottom(tester);

    expect(byId('dispute_status_history'), findsOneWidget);
    expect(byId('dispute_status_history_empty'), findsOneWidget);
  });

  testWidgets('a populated history draws rows, not the empty rung', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        const _CannedRepository(
          DisputeStatus(
            id: 'dsp-2',
            state: DisputeState.pending,
            statusHistory: <DisputeStatusHistoryEntry>[
              DisputeStatusHistoryEntry(status: DisputeState.pending),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await scrollToBottom(tester);

    expect(byId('dispute_status_history'), findsOneWidget);
    expect(byId('dispute_status_history_empty'), findsNothing);
  });
}

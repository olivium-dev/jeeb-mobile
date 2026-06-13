// Tests for T-MOB-007: PendingRequestsTab with TTL countdown.
//
// Verifies AC1 (row with TTL countdown renders), AC2 (expires to "Expired"
// label), AC5 (per-card timer, not full-list rebuild), and the reconnect
// banner visibility (AC6).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';

import '../../support/sync_app_localizations.dart';

Widget _harness({
  required ClientHomeRepository repo,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        )..load(),
        child: const PendingRequestsTab(),
      ),
    ),
  );
}

ClientHomeRequest _pendingRequest({
  String id = 'pen-1',
  String displayId = 'ORD-23470',
  int ttlSeconds = 600,
}) =>
    ClientHomeRequest(
      id: id,
      displayId: displayId,
      title: displayId,
      status: ClientRequestStatus.searching,
      destinationLabel: 'Achrafieh',
      tier: ClientRequestTier.express,
      ttlSeconds: ttlSeconds,
    );

void main() {
  group('PendingRequestsTab — T-MOB-007', () {
    testWidgets('AC1: pending row renders with order id and tier',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pendingRequest()]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-requests-tab-list')), findsOneWidget);
      expect(find.byKey(const Key('pending-countdown-card-pen-1')), findsOneWidget);
      expect(find.text('ORD-23470'), findsOneWidget);
    });

    testWidgets('AC1: TTL countdown label visible with correct format',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [_pendingRequest(ttlSeconds: 600)],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      // 600s = 10:00 minutes
      expect(find.textContaining('~10:00'), findsOneWidget);
    });

    testWidgets('AC2: expired card shows "Expired" label when TTL is 0',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [_pendingRequest(ttlSeconds: 0)],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('AC2: countdown decrements from 2 to 1 after 1s tick',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [_pendingRequest(ttlSeconds: 2)],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      // Initial state: ~00:02
      expect(find.textContaining('~00:02'), findsOneWidget);

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('~00:01'), findsOneWidget);
    });

    testWidgets('empty state when no pending requests', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-empty')), findsOneWidget);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);
    });

    testWidgets('AC5: two pending cards each have their own countdown widget',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [
            _pendingRequest(id: 'p1', displayId: 'ORD-001', ttlSeconds: 300),
            _pendingRequest(id: 'p2', displayId: 'ORD-002', ttlSeconds: 120),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      // Both cards are rendered as separate PendingCountdownCard widgets.
      expect(
        find.byType(PendingCountdownCard),
        findsNWidgets(2),
      );
      // Different TTLs produce different labels.
      expect(find.textContaining('~05:00'), findsOneWidget);
      expect(find.textContaining('~02:00'), findsOneWidget);
    });

    testWidgets('reconnect banner hidden when visible=false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: PendingReconnectBanner(visible: false),
          ),
        ),
      );
      expect(find.byKey(const Key('pending-reconnect-banner')), findsNothing);
    });

    testWidgets('reconnect banner visible when visible=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: PendingReconnectBanner(visible: true),
          ),
        ),
      );
      expect(find.byKey(const Key('pending-reconnect-banner')), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);
    });
  });
}

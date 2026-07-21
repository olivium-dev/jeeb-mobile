// Tests for the server-truth PendingRequestsTab status contract.
//
// The gateway list does not include an expiry instant. A request returned in
// the pending bucket must remain "Searching" until a refreshed server snapshot
// moves or removes it; no local duration may manufacture an "Expired" label.

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
  int? ttlSeconds,
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

class _MutableClientHomeRepository implements ClientHomeRepository {
  _MutableClientHomeRepository(this.snapshot);

  ClientHomeSnapshot snapshot;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async => snapshot;
}

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

    testWidgets('server-pending row without expiry shows searching, not expired',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [_pendingRequest()],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Searching for Jeebers…'), findsOneWidget);
      expect(find.text('Expired'), findsNothing);
      expect(find.byKey(const Key('pending-server-status')), findsOneWidget);
    });

    testWidgets('legacy zero TTL cannot override authoritative pending status',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [_pendingRequest(ttlSeconds: 0)],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Searching for Jeebers…'), findsOneWidget);
      expect(find.text('Expired'), findsNothing);
    });

    testWidgets(
        'server-pending card stays tappable even when a legacy zero TTL exists',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: PendingCountdownCard(
              request: _pendingRequest(ttlSeconds: 0),
              onTap: () => tapped++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expired'), findsNothing);
      expect(find.text('Searching for Jeebers…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pending-countdown-card-pen-1')));
      expect(tapped, 1);
    });

    testWidgets('empty state when no pending requests', (tester) async {
      final repo = InMemoryClientHomeRepository(latency: Duration.zero);
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-empty')), findsOneWidget);
      expect(find.byKey(const Key('pending-requests-tab-list')), findsNothing);
    });

    testWidgets('each pending row renders its own server-derived status',
        (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [
            _pendingRequest(id: 'p1', displayId: 'ORD-001'),
            _pendingRequest(id: 'p2', displayId: 'ORD-002'),
          ],
        ),
        latency: Duration.zero,
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byType(PendingCountdownCard),
        findsNWidgets(2),
      );
      expect(find.text('Searching for Jeebers…'), findsNWidgets(2));
      expect(find.text('Expired'), findsNothing);
    });

    testWidgets('refresh removes a row only when the server snapshot removes it',
        (tester) async {
      final repo = _MutableClientHomeRepository(
        ClientHomeSnapshot(pending: [_pendingRequest()]),
      );
      await tester.pumpWidget(_harness(repo: repo));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pending-countdown-card-pen-1')),
        findsOneWidget,
      );

      repo.snapshot = const ClientHomeSnapshot();
      final cubit = BlocProvider.of<ClientHomeCubit>(
        tester.element(find.byType(PendingRequestsTab)),
      );
      await cubit.refresh();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pending-countdown-card-pen-1')),
        findsNothing,
      );
      expect(find.byKey(const Key('pending-empty')), findsOneWidget);
    });

    testWidgets('reconnect banner hidden when visible=false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en')],
          localizationsDelegates: [
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
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en')],
          localizationsDelegates: [
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

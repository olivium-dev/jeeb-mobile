// LR-10 / NOTIF-01: a failed refresh keeps the inbox and says so; a cold 401
// gets the sign-in way out, never a Retry that will 401 forever.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_cubit.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_state.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const NotificationItem _row = NotificationItem(
  id: 'n-1',
  kind: NotificationKind.status,
  title: 'Order updated',
  body: 'Your order moved on.',
  timestamp: '2026-07-03T10:00:00Z',
  read: false,
  ref: 'conv-1',
);

/// Serves a partial inbox on the warm read — NOTIF-02's degraded lane.
class _DegradingRepository
    implements NotificationsRepository, DegradableNotificationsRepository {
  int calls = 0;

  @override
  Future<NotificationsSnapshot> fetchSnapshot() async {
    calls += 1;
    if (calls == 1) {
      return (
        items: const <NotificationItem>[_row],
        degraded: false,
        failure: null,
      );
    }
    return (
      items: const <NotificationItem>[_row],
      degraded: true,
      failure: const NetworkFailure(offline: true),
    );
  }

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      const <NotificationItem>[_row];

  @override
  Future<void> markRead(String id) async {}
}

class _RefreshFailingRepository implements NotificationsRepository {
  int calls = 0;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    calls += 1;
    if (calls == 1) return const <NotificationItem>[_row];
    throw const NotificationsRepositoryException.classified(
      NotificationsFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }

  @override
  Future<void> markRead(String id) async {}
}

class _FailingRepository implements NotificationsRepository {
  const _FailingRepository(this.kind, this.failure);

  final NotificationsFailure kind;
  final AppFailure failure;

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      throw NotificationsRepositoryException.classified(
        kind,
        appFailure: failure,
      );

  @override
  Future<void> markRead(String id) async {}
}

class _FailThenSucceedRepository implements NotificationsRepository {
  int calls = 0;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    calls += 1;
    if (calls == 1) {
      throw const NotificationsRepositoryException.classified(
        NotificationsFailure.network,
        appFailure: NetworkFailure(offline: true),
      );
    }
    return const <NotificationItem>[_row];
  }

  @override
  Future<void> markRead(String id) async {}
}

class _RecoveringRepository extends _FailingRepository {
  _RecoveringRepository()
      : super(NotificationsFailure.unauthorized,
            const UnauthorizedFailure(recovering: true));

  int calls = 0;

  @override
  Future<List<NotificationItem>> fetchNotifications() {
    calls++;
    return super.fetchNotifications();
  }
}

void main() {
  Widget harness(
    NotificationsRepository repo, {
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: <RouteBase>[
        GoRoute(
          path: '/notifications',
          builder: (_, _) => NotificationsListScreen(repository: repo),
        ),
        GoRoute(
          path: '/',
          name: 'shell',
          builder: (_, _) => const Scaffold(body: Text('shell')),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const Scaffold(body: Text('login')),
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] recovering auth offers working Retry', (tester) async {
      useReduceMotion(tester);
      final repo = _RecoveringRepository();
      await tester.pumpWidget(harness(repo, locale: locale));
      await tester.pumpAndSettle();
      expect(byId('notifications_error'), findsOneWidget);
      expect(byId('notifications_retry_cta'), findsOneWidget);
      expect(byId('notifications_error_signin_cta'), findsNothing);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NotificationsListScreen)),
      );
      expect(find.text(l10n.errorReconnectingBody), findsOneWidget);
      expect(find.text(l10n.actionSignIn), findsNothing);
      await tester.tap(byId('notifications_retry_cta'));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(byId('notifications_retry_cta'), findsOneWidget);
    });

    testWidgets('[$tag] a failed refresh keeps the rows and shows the strip', (
      tester,
    ) async {
      useReduceMotion(tester);
      final repo = _RefreshFailingRepository();
      await tester.pumpWidget(harness(repo, locale: locale));
      await tester.pumpAndSettle();

      expect(byId('notif_row_n-1'), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
      await tester.pumpAndSettle();

      expect(repo.calls, greaterThan(1));
      expect(byId('notif_row_n-1'), findsOneWidget);
      expect(byId('notifications_error'), findsNothing);
      expect(byId('notifications_refresh_error'), findsOneWidget);

      await tester.tap(byId('notifications_refresh_error_dismiss_cta'));
      await tester.pumpAndSettle();
      expect(byId('notifications_refresh_error'), findsNothing);
    });
  }

  testWidgets('a cold unauthorized gets the sign-in way out', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        const _FailingRepository(
          NotificationsFailure.unauthorized,
          UnauthorizedFailure(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(byId('notifications_error'), findsOneWidget);
    expect(byId('notifications_error_signin_cta'), findsOneWidget);
    expect(byId('notifications_retry_cta'), findsNothing);
  });

  testWidgets('a cold network failure keeps a real Retry', (tester) async {
    useReduceMotion(tester);
    final repo = _FailThenSucceedRepository();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    expect(byId('notifications_retry_cta'), findsOneWidget);
    await tester.tap(byId('notifications_retry_cta'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(byId('notif_row_n-1'), findsOneWidget);
  });

  test(
    'a degraded warm read surfaces the failure, not just the cached note',
    () async {
      final cubit = NotificationsListCubit(repository: _DegradingRepository());
      await cubit.load();
      expect(cubit.state.degraded, isFalse);
      expect(cubit.state.refreshError, isNull);

      await cubit.refresh();

      // The rows stay, the cached note fires AND the strip offers a Retry.
      expect(cubit.state.status, NotificationsListStatus.loaded);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.degraded, isTrue);
      expect(cubit.state.refreshError, isA<NetworkFailure>());
      await cubit.close();
    },
  );

  test('retry() flips to loading first, unlike refresh()', () async {
    final cubit = NotificationsListCubit(
      repository: _FailThenSucceedRepository(),
    );
    await cubit.load();
    expect(cubit.state.status, NotificationsListStatus.failed);

    final seen = <NotificationsListStatus>[];
    final sub = cubit.stream.listen((s) => seen.add(s.status));
    await cubit.retry();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, <NotificationsListStatus>[
      NotificationsListStatus.loading,
      NotificationsListStatus.loaded,
    ]);
    await cubit.close();
  });
}

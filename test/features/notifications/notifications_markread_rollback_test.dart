// NOTIF-03: an optimistic read flip is a lie once the write fails, so it is
// rolled back and reported.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_cubit.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _MarkReadRepository implements NotificationsRepository {
  _MarkReadRepository({this.throws = false});

  final bool throws;
  final List<String> marked = <String>[];

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      const <NotificationItem>[_row];

  @override
  Future<void> markRead(String id) async {
    if (throws) {
      throw const NotificationsRepositoryException.classified(
        NotificationsFailure.network,
        appFailure: NetworkFailure(offline: true),
      );
    }
    marked.add(id);
  }
}

void main() {
  test('a failed markRead reverts the flip and reports it', () async {
    final cubit = NotificationsListCubit(
      repository: _MarkReadRepository(throws: true),
    );
    await cubit.load();
    expect(cubit.state.items.single.read, isFalse);

    await cubit.markRead('n-1');

    expect(cubit.state.items.single.read, isFalse);
    expect(cubit.state.markReadFailure, isNotNull);
    cubit.acknowledgeMarkReadFailure();
    expect(cubit.state.markReadFailure, isNull);
    await cubit.close();
  });

  test('a successful markRead keeps the flip', () async {
    final repo = _MarkReadRepository();
    final cubit = NotificationsListCubit(repository: repo);
    await cubit.load();
    await cubit.markRead('n-1');

    expect(cubit.state.items.single.read, isTrue);
    expect(cubit.state.markReadFailure, isNull);
    expect(repo.marked, <String>['n-1']);
    await cubit.close();
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('[${locale.languageCode}] the screen snacks the rollback', (
      tester,
    ) async {
      useReduceMotion(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: <RouteBase>[
          GoRoute(
            path: '/notifications',
            builder: (_, _) => NotificationsListScreen(
              repository: _MarkReadRepository(throws: true),
            ),
          ),
          GoRoute(
            path: '/chat/:id',
            name: 'chat-detail',
            builder: (_, _) => const Scaffold(body: Text('chat')),
          ),
        ],
      );

      await tester.pumpWidget(
        BlocProvider<RoleCubit>(
          create: (_) => RoleCubit(prefs: prefs),
          child: MaterialApp.router(
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('notif_row_n-1'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('notifications_markread_error'),
        findsOneWidget,
      );
    });
  }
}

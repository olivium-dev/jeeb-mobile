// NOTIF-04: a row that cannot address a destination says so instead of
// swallowing the tap.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

NotificationItem _item(String id, NotificationKind kind, {String? ref}) =>
    NotificationItem(
      id: id,
      kind: kind,
      title: 'title-$id',
      body: 'body-$id',
      timestamp: '2026-07-03T10:00:00Z',
      read: false,
      ref: ref,
    );

class _SeededRepository implements NotificationsRepository {
  _SeededRepository(this._items);

  final List<NotificationItem> _items;
  final List<String> marked = <String>[];

  @override
  Future<List<NotificationItem>> fetchNotifications() async => _items;

  @override
  Future<void> markRead(String id) async => marked.add(id);
}

Widget _stub(String id) => Semantics(
  identifier: id,
  container: true,
  child: const Scaffold(body: SizedBox.expand()),
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    NotificationsRepository repo, {
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
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
          builder: (_, _) => _stub('shell_root'),
        ),
        GoRoute(
          path: '/chat/:id',
          name: 'chat-detail',
          builder: (_, s) => _stub('chat_root_${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/requests/:id/waiting',
          name: 'waiting-no-coverage',
          builder: (_, s) => _stub('waiting_root_${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/orders/:id/receipt',
          name: 'delivered-receipt',
          builder: (_, s) => _stub('receipt_root_${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/disputes/:id',
          name: 'dispute-status',
          builder: (_, s) => _stub('dispute_root_${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<RoleCubit>(
        create: (_) => RoleCubit(prefs: prefs, initialRole: UserRole.jeeber),
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
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;
    for (final kind in const <NotificationKind>[
      NotificationKind.status,
      NotificationKind.requestExpired,
      NotificationKind.confirmReceipt,
      NotificationKind.dispute,
      NotificationKind.newRequest,
      NotificationKind.unknown,
    ]) {
      testWidgets('[$tag] a ref-less ${kind.name} row says it cannot open', (
        tester,
      ) async {
        useReduceMotion(tester);
        final repo = _SeededRepository(<NotificationItem>[_item('n-1', kind)]);
        await pump(tester, repo, locale: locale);

        await tester.tap(byId('notif_row_n-1'));
        await tester.pumpAndSettle();

        expect(byId('notifications_cannot_open'), findsOneWidget);
        // The row is still marked read, and nothing navigated away.
        expect(repo.marked, <String>['n-1']);
        expect(byId('notif_row_n-1'), findsOneWidget);
      });
    }
  }

  testWidgets('an addressed status row still routes', (tester) async {
    useReduceMotion(tester);
    await pump(
      tester,
      _SeededRepository(<NotificationItem>[
        _item('n-1', NotificationKind.status, ref: 'conv-9'),
      ]),
    );

    await tester.tap(byId('notif_row_n-1'));
    await tester.pumpAndSettle();

    expect(byId('chat_root_conv-9'), findsOneWidget);
    expect(byId('notifications_cannot_open'), findsNothing);
  });

  testWidgets('an addressed dispute row still routes', (tester) async {
    useReduceMotion(tester);
    await pump(
      tester,
      _SeededRepository(<NotificationItem>[
        _item('n-1', NotificationKind.dispute, ref: 'dsp-3'),
      ]),
    );

    await tester.tap(byId('notif_row_n-1'));
    await tester.pumpAndSettle();

    expect(byId('dispute_root_dsp-3'), findsOneWidget);
  });
}

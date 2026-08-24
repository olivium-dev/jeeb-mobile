// W6-T4: the wallet-guard withdraw push (CONTRACT §3) must land in the inbox as
// its own kind and render §5 P-1/P-2 locally — that is what delivers Arabic.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/notifications/domain/notification_kind_mapping.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedRepository implements NotificationsRepository {
  _ScriptedRepository(this._items);

  final List<NotificationItem> _items;
  final List<String> markedRead = <String>[];

  @override
  Future<List<NotificationItem>> fetchNotifications() async => _items;

  @override
  Future<void> markRead(String id) async => markedRead.add(id);
}

Widget _stub(String id) => Semantics(
  identifier: id,
  container: true,
  child: const Scaffold(body: SizedBox.expand()),
);

Widget _harness(
  NotificationsRepository repo,
  RoleCubit role, {
  required Locale locale,
}) {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, _) => NotificationsListScreen(repository: repo),
      ),
      GoRoute(path: '/', name: 'shell', builder: (_, _) => _stub('shell_root')),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (_, _) => _stub('wallet_hub_root'),
      ),
    ],
  );
  return BlocProvider<RoleCubit>.value(
    value: role,
    child: MaterialApp.router(
      routerConfig: router,
      // The empty-state illustration loops by design, so pumpAndSettle needs
      // reduced motion to reach a settled frame.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child ?? const SizedBox.shrink(),
      ),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  const String titleKey = 'walletGuardPushOfferWithdrawnTitle';
  const String bodyKey = 'walletGuardPushOfferWithdrawnBody';
  const String eyebrowKey = 'notificationsKindWalletWithdrawnLabel';

  String copyFor(String tag, String key) {
    final AppLocalizations loc = debugLoadAppLocalizationsSync(
      Locale(tag),
      File('lib/l10n/app_$tag.arb').readAsStringSync(),
    );
    final String? value = loc.byKey(key);
    expect(value, isNotNull, reason: 'missing ARB key "$key" in app_$tag.arb');
    return value!;
  }

  group('wire type → NotificationKind (CONTRACT §3)', () {
    test('offer_withdrawn_insufficient_balance maps to the wallet-guard kind',
        () {
      expect(
        notificationKindFromWireType('offer_withdrawn_insufficient_balance'),
        NotificationKind.offerWithdrawnInsufficientBalance,
      );
    });

    test('wallet_insufficient_balance (notification-service slug) maps too',
        () {
      expect(
        notificationKindFromWireType('wallet_insufficient_balance'),
        NotificationKind.offerWithdrawnInsufficientBalance,
      );
    });

    test('the jeeb.-prefixed upstream event_type maps too', () {
      expect(
        notificationKindFromWireType(
          'jeeb.offer_withdrawn_insufficient_balance',
        ),
        NotificationKind.offerWithdrawnInsufficientBalance,
      );
    });
  });

  group('inbox row renders localized §5 P-1/P-2 copy', () {
    Future<void> pumpRow(
      WidgetTester tester, {
      required Locale locale,
      required String wireTitle,
      required String wireBody,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final roleCubit = RoleCubit(prefs: prefs, initialRole: UserRole.jeeber);
      addTearDown(roleCubit.close);
      await tester.pumpWidget(
        _harness(
          _ScriptedRepository(<NotificationItem>[
            NotificationItem(
              id: 'wg-1',
              kind: NotificationKind.offerWithdrawnInsufficientBalance,
              title: wireTitle,
              body: wireBody,
              // Future stamp → deterministic "just now", never wall-clock bound.
              timestamp: '2999-01-01T00:00:00Z',
              read: false,
            ),
          ]),
          roleCubit,
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('EN: row shows the P-1 title, P-2 body and wallet eyebrow', (
      tester,
    ) async {
      await pumpRow(
        tester,
        locale: const Locale('en'),
        wireTitle: copyFor('en', titleKey),
        wireBody: copyFor('en', bodyKey),
      );

      expect(find.bySemanticsIdentifier('notif_row_wg-1'), findsOneWidget);
      expect(find.text(copyFor('en', titleKey)), findsOneWidget);
      expect(find.text(copyFor('en', bodyKey)), findsOneWidget);
      expect(find.text(copyFor('en', eyebrowKey)), findsOneWidget);
      expect(
        find.byIcon(Icons.account_balance_wallet_outlined),
        findsOneWidget,
      );
    });

    testWidgets('AR: the EN wire payload is replaced by the Arabic copy', (
      tester,
    ) async {
      await pumpRow(
        tester,
        locale: const Locale('ar'),
        // The gateway has no recipient locale, so the wire stays EN.
        wireTitle: copyFor('en', titleKey),
        wireBody: copyFor('en', bodyKey),
      );

      expect(find.text(copyFor('ar', titleKey)), findsOneWidget);
      expect(find.text(copyFor('ar', bodyKey)), findsOneWidget);
      expect(find.text(copyFor('ar', eyebrowKey)), findsOneWidget);
      expect(find.text(copyFor('en', titleKey)), findsNothing);
      expect(find.text(copyFor('en', bodyKey)), findsNothing);
    });

    testWidgets('a drifted wire title/body never reaches the row', (
      tester,
    ) async {
      await pumpRow(
        tester,
        locale: const Locale('en'),
        wireTitle: 'legacy wire title',
        wireBody: 'legacy wire body',
      );

      expect(find.text('legacy wire title'), findsNothing);
      expect(find.text('legacy wire body'), findsNothing);
      expect(find.text(copyFor('en', titleKey)), findsOneWidget);
      expect(find.text(copyFor('en', bodyKey)), findsOneWidget);
    });
  });
}

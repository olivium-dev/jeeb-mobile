// JEBV4-309: the customer delivery-details hub is STATE-AWARE. Before this fix
// `_actions()` returned all five rows and `_buildChildren()` always appended the
// Cancel button (class doc admitted "no delivery-status cubit yet, so all CTAs
// render unconditionally"). The hub now reads the wire `statusId`
// (`GET /v1/deliveries/{id}` via [DioOrderChatSummaryRepository]) and gates the
// rows per lifecycle bucket.
//
// This locks the three buckets:
//   * DELIVERED (Done)      → Delivered banner + Contact + Rate + Receipt +
//                             Report; HIDES Cancel / Verify-OTP / Live-tracking.
//   * ACTIVE pre-pickup     → Live-tracking + Contact + Verify-OTP + Report +
//                             Cancel; NO Rate row, NO banner.
//   * ACTIVE post-pickup    → same as pre-pickup but Cancel is HIDDEN (parcel in
//                             hand — free-cancel window closed, JEBV4-289).
//   * CANCELLED             → Cancelled banner + Report only.
//   * status unavailable    → FAILS OPEN to the full legacy list (Cancel shown),
//                             but the delivered bucket omits Cancel structurally
//                             so it can never appear on a known-Delivered order.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Fake status source: returns an [OrderChatSummary] carrying a caller-supplied
/// wire `statusId` (or throws) from `fetchSummary`.
class _FakeSummaryRepository implements OrderChatSummaryRepository {
  _FakeSummaryRepository({this.statusId, this.throwFailure});

  final String? statusId;
  final OrderChatSummaryFailure? throwFailure;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async {
    final failure = throwFailure;
    if (failure != null) {
      throw OrderChatSummaryException(failure);
    }
    return OrderChatSummary(deliveryId: deliveryId, statusId: statusId ?? '');
  }
}

const _deliveryId = 'del-1';

Future<Widget> _host(_FakeSummaryRepository repo) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final role = RoleCubit(prefs: prefs, initialRole: UserRole.client);
  final router = GoRouter(
    initialLocation: '/orders/$_deliveryId',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => DeliveryDetailScreen(
          deliveryId: state.pathParameters['id']!,
          summaryRepository: repo,
          // No seam needed to keep the test timer-free any more: the periodic
          // re-read is GONE. The screen reads once on mount and then only when a
          // `delivery` push arrives, and with no DI the refresh stream resolves
          // null, so nothing is pending.
        ),
      ),
    ],
  );
  return BlocProvider<RoleCubit>.value(
    value: role,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData.light(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Finder _row(String id) => find.byKey(Key(id));

void main() {
  testWidgets(
    'DELIVERED (Done) → banner + Rate + Report + Receipt; NO Cancel/OTP/Track',
    (tester) async {
      final repo = _FakeSummaryRepository(statusId: 'Done');
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();

      // Terminal Delivered banner is shown.
      expect(_row('order-detail-status-delivered'), findsOneWidget);
      // Kept affordances.
      expect(_row('order-detail-rate'), findsOneWidget);
      expect(_row('order-detail-escalate'), findsOneWidget);
      expect(_row('order-detail-receipt'), findsOneWidget);
      // Hidden affordances — the whole point of the ticket.
      expect(_row('order-detail-cancel'), findsNothing);
      expect(_row('order-detail-otp'), findsNothing);
      expect(_row('order-detail-track'), findsNothing);
    },
  );

  testWidgets(
    'ACTIVE pre-pickup (Ordered) → Track/OTP/Report/Cancel; NO Rate, NO banner',
    (tester) async {
      final repo = _FakeSummaryRepository(statusId: 'Ordered');
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();

      expect(_row('order-detail-track'), findsOneWidget);
      expect(_row('order-detail-otp'), findsOneWidget);
      expect(_row('order-detail-escalate'), findsOneWidget);
      // Free-cancel window is open pre-pickup.
      expect(_row('order-detail-cancel'), findsOneWidget);
      // Rate is a delivered-class-only affordance.
      expect(_row('order-detail-rate'), findsNothing);
      // No terminal banners on an active delivery.
      expect(_row('order-detail-status-delivered'), findsNothing);
      expect(_row('order-detail-status-cancelled'), findsNothing);
    },
  );

  testWidgets(
    'ACTIVE post-pickup (InTransit) → Cancel HIDDEN, Track/OTP/Report kept',
    (tester) async {
      final repo = _FakeSummaryRepository(statusId: 'InTransit');
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();

      expect(_row('order-detail-track'), findsOneWidget);
      expect(_row('order-detail-otp'), findsOneWidget);
      expect(_row('order-detail-escalate'), findsOneWidget);
      // Parcel in hand — cancel is no longer offered.
      expect(_row('order-detail-cancel'), findsNothing);
    },
  );

  testWidgets(
    'CANCELLED → Cancelled banner + Report only',
    (tester) async {
      final repo = _FakeSummaryRepository(statusId: 'Cancelled');
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();

      expect(_row('order-detail-status-cancelled'), findsOneWidget);
      expect(_row('order-detail-escalate'), findsOneWidget);
      // Everything else is gone on a cancelled delivery.
      expect(_row('order-detail-cancel'), findsNothing);
      expect(_row('order-detail-otp'), findsNothing);
      expect(_row('order-detail-track'), findsNothing);
      expect(_row('order-detail-rate'), findsNothing);
      expect(_row('order-detail-receipt'), findsNothing);
    },
  );

  testWidgets(
    'status UNAVAILABLE (fetch throws) → fails open to the full legacy list',
    (tester) async {
      final repo = _FakeSummaryRepository(
        throwFailure: OrderChatSummaryFailure.network,
      );
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();

      // Fail-open = every legacy row + Cancel, exactly as before JEBV4-309.
      expect(_row('order-detail-track'), findsOneWidget);
      expect(_row('order-detail-otp'), findsOneWidget);
      expect(_row('order-detail-rate'), findsOneWidget);
      expect(_row('order-detail-escalate'), findsOneWidget);
      expect(_row('order-detail-cancel'), findsOneWidget);
      // No terminal banners while the status is unknown.
      expect(_row('order-detail-status-delivered'), findsNothing);
      expect(_row('order-detail-status-cancelled'), findsNothing);
    },
  );
}

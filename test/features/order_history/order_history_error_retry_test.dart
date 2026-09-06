// ORDH-01 / ES-06 / ES-07 / TEST-09: the error rung never degrades into
// "No orders yet", the copy follows the failure KIND, a filtered empty offers
// a way out, and the jeeber role gets its own line.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_state.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

final OrderSummary _row = OrderSummary(
  id: 'REQ-1',
  createdAt: DateTime.utc(2026, 6, 18, 9),
  pickupAddress: 'Hamra',
  dropoffAddress: 'Achrafieh',
  status: OrderRequestStatus.pickedUp,
  tier: OrderTier.express,
  amountMinor: 1500,
  currency: 'USD',
);

/// Throws [failure] on every read.
class _Failing implements OrderRepository {
  const _Failing(this.failure);

  final AppFailure failure;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async =>
      throw failure;
}

/// Rows only when NO date range is applied.
class _FilteredEmpty implements OrderRepository {
  const _FilteredEmpty();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async => OrderPage(
    items: range.from != null || range.to != null
        ? const <OrderSummary>[]
        : <OrderSummary>[if (tab == OrderHistoryTab.active) _row],
    page: page,
    hasMore: false,
  );
}

class _Empty implements OrderRepository {
  const _Empty();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async =>
      OrderPage(items: const <OrderSummary>[], page: page, hasMore: false);
}

late SharedPreferences _prefs;

Widget _harness(
  OrderHistoryCubit cubit, {
  Locale locale = const Locale('en'),
  UserRole? role,
}) {
  final Widget screen = BlocProvider<OrderHistoryCubit>.value(
    value: cubit,
    child: const OrderHistoryScreen(),
  );
  return wrapMidnight(
    SizedBox(
      height: 900,
      child: role == null
          ? screen
          : BlocProvider<RoleCubit>(
              create: (_) => RoleCubit(prefs: _prefs, initialRole: role),
              child: screen,
            ),
    ),
    locale: locale,
    scrollable: false,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
  });

  group('ORDH-01 · a failed refresh over an EMPTY list stays an error', () {
    test('cold failure → error; a second failure is still error', () async {
      final OrderHistoryCubit cubit = OrderHistoryCubit(
        repository: const _Failing(NetworkFailure(offline: true)),
      );
      addTearDown(cubit.close);

      await cubit.initialLoad();
      expect(cubit.state.currentTab.status, OrderTabStatus.error);

      await cubit.refresh();
      expect(
        cubit.state.currentTab.status,
        OrderTabStatus.error,
        reason: 'the second failure must not become "No orders yet"',
      );
      expect(cubit.state.currentTab.failure, isA<NetworkFailure>());
    });

    test('an unclassified throw is still classified', () async {
      final OrderHistoryCubit cubit = OrderHistoryCubit(
        repository: const _Failing(UnknownFailure(parse: true)),
      );
      addTearDown(cubit.close);
      await cubit.initialLoad();
      expect(cubit.state.currentTab.failure, isA<UnknownFailure>());
    });
  });

  for (final Locale locale in kFailureLocales) {
    testWidgets('${locale.languageCode}: a cold failure renders the error rung',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      final OrderHistoryCubit cubit = OrderHistoryCubit(
        repository: const _Failing(NetworkFailure(offline: true)),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale: locale));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('order_history_error'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('order_history_retry_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('order_history_empty_active'),
        findsNothing,
      );

      await tester.tap(find.bySemanticsIdentifier('order_history_retry_cta'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('order_history_error'), findsOneWidget);
    });
  }

  testWidgets('an unrecoverable kind gets an exit CTA, not a Retry', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    final OrderHistoryCubit cubit = OrderHistoryCubit(
      repository: const _Failing(NotFoundFailure()),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('order_history_error'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('order_history_retry_cta'),
      findsNothing,
      reason: 'a 404 cannot be retried away',
    );
  });

  testWidgets('ES-06 · a filtered empty says so and offers a clear', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    final OrderHistoryCubit cubit = OrderHistoryCubit(
      repository: const _FilteredEmpty(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('order_history_clear_range_cta'),
      findsNothing,
    );

    await cubit.applyDateRange(
      OrderDateRange.forInclusiveDays(
        from: DateTime(2026, 6, 18),
        to: DateTime(2026, 6, 18),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('order_history_empty_active'),
      findsOneWidget,
    );
    await tester.tap(
      find.bySemanticsIdentifier('order_history_clear_range_cta'),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.dateRange.from, isNull);
    expect(cubit.state.currentTab.orders, hasLength(1));
  });

  testWidgets('ES-07 · the jeeber role gets its own empty headline', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    final OrderHistoryCubit client = OrderHistoryCubit(repository: const _Empty());
    final OrderHistoryCubit jeeber = OrderHistoryCubit(repository: const _Empty());
    addTearDown(client.close);
    addTearDown(jeeber.close);

    await tester.pumpWidget(_harness(client));
    await tester.pumpAndSettle();
    final String clientHeadline = tester
        .widget<Text>(
          find.descendant(
            of: find.bySemanticsIdentifier('order_history_empty_active'),
            matching: find.byType(Text),
          ).first,
        )
        .data!;

    await tester.pumpWidget(_harness(jeeber, role: UserRole.jeeber));
    await tester.pumpAndSettle();
    final String jeeberHeadline = tester
        .widget<Text>(
          find.descendant(
            of: find.bySemanticsIdentifier('order_history_empty_active'),
            matching: find.byType(Text),
          ).first,
        )
        .data!;

    expect(jeeberHeadline, isNot(clientHeadline));
  });
}

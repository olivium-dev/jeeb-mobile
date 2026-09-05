// F1: a retry / tab-entry re-pull with nothing warm behind it painted "No
// deliveries yet" for the whole in-flight window instead of the loading rung.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_state.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

final OrderSummary _row = OrderSummary(
  id: 'REQ-9',
  createdAt: DateTime.utc(2026, 6, 18, 9),
  pickupAddress: 'Hamra',
  dropoffAddress: 'Achrafieh',
  status: OrderRequestStatus.pickedUp,
  tier: OrderTier.express,
  amountMinor: 1500,
  currency: 'USD',
);

/// Fails while [failing]; otherwise parks the call on a completer the test
/// resolves by hand, so the in-flight window is observable.
class _GatedRepo implements OrderRepository {
  bool failing = true;
  final List<Completer<OrderPage>> pending = <Completer<OrderPage>>[];

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) {
    if (failing) {
      return Future<OrderPage>.error(const NetworkFailure(offline: true));
    }
    final Completer<OrderPage> completer = Completer<OrderPage>();
    pending.add(completer);
    return completer.future;
  }
}

/// Cubit emissions are delivered on a microtask, so a synchronous assert
/// right after `act` sees an empty list.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

Widget _harness(OrderHistoryCubit cubit, {Locale locale = const Locale('en')}) {
  return wrapMidnight(
    SizedBox(
      height: 900,
      child: BlocProvider<OrderHistoryCubit>.value(
        value: cubit,
        child: const OrderHistoryScreen(),
      ),
    ),
    locale: locale,
    scrollable: false,
  );
}

void main() {
  group('cubit', () {
    test('a Retry after a failed cold load emits loadingFirstPage, not '
        'refreshing', () async {
      final _GatedRepo repo = _GatedRepo();
      final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.initialLoad();
      expect(cubit.state.currentTab.status, OrderTabStatus.error);
      expect(cubit.state.currentTab.settled, isFalse);

      final List<OrderTabStatus> seen = <OrderTabStatus>[];
      final sub = cubit.stream.listen((s) => seen.add(s.currentTab.status));
      addTearDown(sub.cancel);

      await cubit.refresh();
      await _flush();
      expect(seen, <OrderTabStatus>[
        OrderTabStatus.loadingFirstPage,
        OrderTabStatus.error,
      ]);
    });

    test('refreshSilently over an errored EMPTY tab emits loadingFirstPage',
        () async {
      final _GatedRepo repo = _GatedRepo();
      final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.initialLoad();
      expect(cubit.state.currentTab.status, OrderTabStatus.error);

      final List<OrderTabStatus> seen = <OrderTabStatus>[];
      final sub = cubit.stream.listen((s) => seen.add(s.currentTab.status));
      addTearDown(sub.cancel);

      await cubit.refreshSilently();
      await _flush();
      expect(seen.first, OrderTabStatus.loadingFirstPage);
      expect(seen, isNot(contains(OrderTabStatus.refreshing)));
    });

    test('a Retry after a failed refresh over a settled-EMPTY tab emits '
        'loadingFirstPage', () async {
      final _GatedRepo repo = _GatedRepo()..failing = false;
      final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
      addTearDown(cubit.close);

      final Future<void> first = cubit.initialLoad();
      repo.pending.removeAt(0).complete(
            const OrderPage(items: <OrderSummary>[], page: 1, hasMore: false),
          );
      await first;
      expect(cubit.state.currentTab.settled, isTrue);
      expect(cubit.state.currentTab.orders, isEmpty);

      repo.failing = true;
      await cubit.refreshSilently();
      expect(cubit.state.currentTab.status, OrderTabStatus.error);
      expect(cubit.state.currentTab.settled, isTrue);

      final List<OrderTabStatus> seen = <OrderTabStatus>[];
      final sub = cubit.stream.listen((s) => seen.add(s.currentTab.status));
      addTearDown(sub.cancel);

      await cubit.refresh();
      await _flush();
      expect(seen.first, OrderTabStatus.loadingFirstPage);
      expect(seen, isNot(contains(OrderTabStatus.refreshing)));
    });

    test('a refresh over SETTLED rows still emits refreshing and keeps them',
        () async {
      final _GatedRepo repo = _GatedRepo()..failing = false;
      final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
      addTearDown(cubit.close);

      final Future<void> first = cubit.initialLoad();
      repo.pending.removeAt(0).complete(
            OrderPage(items: <OrderSummary>[_row], page: 1, hasMore: false),
          );
      await first;
      expect(cubit.state.currentTab.settled, isTrue);

      final List<OrderTabStatus> seen = <OrderTabStatus>[];
      final sub = cubit.stream.listen((s) => seen.add(s.currentTab.status));
      addTearDown(sub.cancel);

      final Future<void> second = cubit.refresh();
      await _flush();
      expect(seen, <OrderTabStatus>[OrderTabStatus.refreshing]);
      expect(cubit.state.currentTab.orders, <OrderSummary>[_row]);
      repo.pending.removeAt(0).complete(
            OrderPage(items: <OrderSummary>[_row], page: 1, hasMore: false),
          );
      await second;
      expect(cubit.state.currentTab.status, OrderTabStatus.ready);
    });
  });

  for (final Locale locale in kFailureLocales) {
    testWidgets(
      '${locale.languageCode}: an in-flight Retry paints the loading rung, '
      'never the empty state',
      (WidgetTester tester) async {
        useReduceMotion(tester);
        final _GatedRepo repo = _GatedRepo();
        final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
        addTearDown(cubit.close);

        await tester.pumpWidget(_harness(cubit, locale: locale));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('order_history_error'),
          findsOneWidget,
        );

        repo.failing = false;
        await tester.tap(find.bySemanticsIdentifier('order_history_retry_cta'));
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('order_history_loading'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('order_history_empty_active'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('order_history_error'),
          findsNothing,
        );

        repo.pending.removeAt(0).complete(
              const OrderPage(items: <OrderSummary>[], page: 1, hasMore: false),
            );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('order_history_empty_active'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '${locale.languageCode}: a Retry over a tab that once settled EMPTY '
      'still paints the loading rung',
      (WidgetTester tester) async {
        useReduceMotion(tester);
        final _GatedRepo repo = _GatedRepo()..failing = false;
        final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
        addTearDown(cubit.close);

        await tester.pumpWidget(_harness(cubit, locale: locale));
        await tester.pump();
        repo.pending.removeAt(0).complete(
              const OrderPage(items: <OrderSummary>[], page: 1, hasMore: false),
            );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('order_history_empty_active'),
          findsOneWidget,
        );

        repo.failing = true;
        await cubit.refreshSilently();
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('order_history_error'),
          findsOneWidget,
        );

        repo.failing = false;
        await tester.tap(find.bySemanticsIdentifier('order_history_retry_cta'));
        await tester.pump();
        expect(
          find.bySemanticsIdentifier('order_history_loading'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('order_history_empty_active'),
          findsNothing,
        );
      },
    );
  }
}

// UX-19 / UX-20 / UX-50 / NET-23 — no fabricated `$0.00 USD`, no rendered Map
// literal, no guessed chat id, and a failed secondary read says so.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/order_summary/data/dio_order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/data/fake_order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/application/order_summary_cubit.dart';
import 'package:jeeb_mobile/features/order_summary/application/order_summary_state.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/order_summary_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';
import '../otp_handover/_scripted_dio.dart';

const _bareDelivery = <String, Object?>{
  'id': 'DEL-1',
  'requestId': 'REQ-1',
};

void main() {
  group('DioOrderSummaryRepository', () {
    test('a body with no amount leaves price and currency NULL', () async {
      final repo = DioOrderSummaryRepository(
        scriptedDio((options, r) {
          if (options.path.contains('/deliveries/')) {
            r.respondWith(200, body: _bareDelivery);
          } else {
            r.respondWith(200, body: const <String, Object?>{});
          }
        }),
        originGateway: true,
      );

      final summary = await repo.fetchSummary('DEL-1');
      expect(summary.price, isNull);
      expect(summary.currency, isNull);
      expect(summary.hasPrice, isFalse);
    });

    test('a non-String title renders nothing, never a Map literal', () async {
      final repo = DioOrderSummaryRepository(
        scriptedDio((options, r) {
          if (options.path.contains('/deliveries/')) {
            r.respondWith(200, body: <String, Object?>{
              ..._bareDelivery,
              'title': <String, Object?>{'en': 'Groceries'},
            });
          } else {
            r.respondWith(200, body: const <String, Object?>{});
          }
        }),
        originGateway: true,
      );

      final summary = await repo.fetchSummary('DEL-1');
      expect(summary.itemSummary, isNull);
    });

    test('a missing conversationId stays null, never an empty string',
        () async {
      final repo = DioOrderSummaryRepository(
        scriptedDio((options, r) {
          if (options.path.contains('/deliveries/')) {
            r.respondWith(200, body: _bareDelivery);
          } else {
            r.respondWith(200, body: const <String, Object?>{});
          }
        }),
        originGateway: true,
      );

      expect((await repo.fetchSummary('DEL-1')).conversationId, isNull);
    });

    test('a failed secondary read is recorded, not silently absent', () async {
      final repo = DioOrderSummaryRepository(
        scriptedDio((options, r) {
          if (options.path.contains('/deliveries/')) {
            r.respondWith(200, body: <String, Object?>{
              ..._bareDelivery,
              'jeeberId': 'user-1',
            });
          } else if (options.path.contains('/requests/')) {
            r.failWithStatus(503);
          } else {
            r.respondWith(200, body: const <String, Object?>{});
          }
        }),
        originGateway: true,
      );

      final summary = await repo.fetchSummary('DEL-1');
      expect(summary.partialSections, contains(OrderSummarySection.request));
    });
  });

  group('OrderSummaryScreen', () {
    Widget host(OrderSummary summary, Locale locale) => wrapForTest(
          OrderSummaryScreen(
            deliveryId: summary.deliveryId,
            repository: FakeOrderSummaryRepository(summary: summary),
          ),
          locale: locale,
        );

    const base = OrderSummary(
      deliveryId: 'DEL-1',
      requestId: 'REQ-1',
      conversationId: 'CONV-1',
      price: null,
      currency: null,
      jeeberName: 'Rami',
      tier: 'express',
    );

    testWidgets('an unknown price says so, never 0.00 USD — EN + AR',
        (tester) async {
      for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
        useReduceMotion(tester);
        await tester.pumpWidget(host(base, locale));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(OrderSummaryScreen)),
        );
        expect(find.text(l10n.orderSummaryPriceUnavailable), findsOneWidget);
        expect(find.textContaining('0.00'), findsNothing);
      }
    });

    testWidgets('a null conversationId hides the chat CTA', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        host(
          const OrderSummary(
            deliveryId: 'DEL-2',
            requestId: 'REQ-2',
            conversationId: null,
            price: 9,
            currency: 'USD',
            jeeberName: 'Rami',
            tier: 'express',
          ),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('order_summary_open_chat'),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('order_summary_track'), findsOneWidget);
    });

    testWidgets('a partial read renders the partial note', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        host(
          const OrderSummary(
            deliveryId: 'DEL-3',
            requestId: 'REQ-3',
            conversationId: 'CONV-3',
            price: 9,
            currency: 'USD',
            jeeberName: 'Rami',
            tier: 'express',
            partialSections: <OrderSummarySection>{OrderSummarySection.offers},
          ),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('order_summary_partial'),
        findsOneWidget,
      );
    });
  });

  group('OrderSummaryCubit', () {
    test('UX-31: retry() shows a loading rung and re-reads', () async {
      final repo = _CountingRepository();
      final cubit = OrderSummaryCubit(repository: repo, deliveryId: 'DEL-9');
      await cubit.load();
      expect(cubit.state.status, OrderSummaryStatus.loaded);

      final pending = cubit.retry();
      expect(
        cubit.state.status,
        OrderSummaryStatus.loading,
        reason: 'the CTA must show a rung, not re-read in silence',
      );
      await pending;
      expect(cubit.state.status, OrderSummaryStatus.loaded);
      expect(repo.calls, 2);
      await cubit.close();
    });

    test('UX-30: refresh() keeps the rows and sets refreshError', () async {
      final repo = _WarmFailingRepository();
      final cubit = OrderSummaryCubit(repository: repo, deliveryId: 'DEL-9');
      await cubit.load();
      expect(cubit.state.status, OrderSummaryStatus.loaded);

      await cubit.refresh();
      expect(cubit.state.status, OrderSummaryStatus.loaded);
      expect(cubit.state.summary, isNotNull);
      expect(cubit.state.refreshError, OrderSummaryFailure.network);

      cubit.acknowledgeRefreshError();
      expect(cubit.state.refreshError, isNull);
      await cubit.close();
    });
  });
}

/// Loads once, then fails: the warm lane.
class _WarmFailingRepository implements OrderSummaryRepository {
  int reads = 0;

  @override
  Future<OrderSummary> fetchSummary(String deliveryId) async {
    reads++;
    if (reads == 1) {
      return const OrderSummary(
        deliveryId: 'DEL-9',
        requestId: 'REQ-9',
        conversationId: 'CONV-9',
        price: 9,
        currency: 'USD',
        jeeberName: 'Rami',
        tier: 'express',
      );
    }
    throw const OrderSummaryRepositoryException(OrderSummaryFailure.network);
  }
}

/// Counts reads and always succeeds.
class _CountingRepository implements OrderSummaryRepository {
  int calls = 0;

  @override
  Future<OrderSummary> fetchSummary(String deliveryId) async {
    calls++;
    return const OrderSummary(
      deliveryId: 'DEL-9',
      requestId: 'REQ-9',
      conversationId: 'CONV-9',
      price: 9,
      currency: 'USD',
      jeeberName: 'Rami',
      tier: 'express',
    );
  }
}

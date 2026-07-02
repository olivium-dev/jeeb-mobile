// run-20 pushD gap — the request-detail route landed on the "Request
// unavailable" fallback for a request that EXISTS and is open, because the
// route resolved the payload ONLY from the warm feed cache. A push tap arrives
// after the request was created (so the cache never held it) → cache miss →
// fallback. The fix: on a cache miss, FETCH the request by id from the jeeber
// discovery feed before falling back.
//
// These tests pin the loader's three branches:
//   (a) cache miss + fetch success → detail renders for that id (was the bug).
//   (b) cache miss + fetch miss    → the graceful unavailable fallback is kept.
//   (c) cache hit                  → detail renders synchronously, no fetch.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  const requestId = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';
  const recovered = FeedRequest(id: requestId, shortLabel: 'Souq Waqif pickup');

  Widget loader({
    required FeedRequest? initial,
    required Future<FeedRequest?> Function() fetch,
  }) =>
      wrapForTest(
        JeeberRequestDetailLoader(
          requestId: requestId,
          initial: initial,
          fetch: fetch,
          reportService: const ProhibitedItemReportService(),
          onDeclined: (_) {},
          onBack: () {},
        ),
      );

  testWidgets(
    'cache miss + fetch success → loading, then the detail renders for that id',
    (tester) async {
      final gate = Completer<FeedRequest?>();
      var fetchCalls = 0;

      await tester.pumpWidget(
        loader(
          initial: null,
          fetch: () {
            fetchCalls++;
            return gate.future;
          },
        ),
      );
      // While the by-id fetch is in flight the loader shows its loading view —
      // NOT the unavailable fallback.
      await tester.pump();
      expect(find.byType(JeeberRequestDetailLoadingView), findsOneWidget);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
      expect(find.byType(JeeberRequestDetailScreen), findsNothing);

      gate.complete(recovered);
      await tester.pumpAndSettle();

      // The exact run-20 assertion: an existing/open request resolves to the
      // detail hub, keyed by the id the push carried.
      expect(fetchCalls, 1);
      expect(find.byType(JeeberRequestDetailScreen), findsOneWidget);
      expect(find.text(requestId), findsOneWidget);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
    },
  );

  testWidgets(
    'cache miss + fetch miss → the graceful unavailable fallback is preserved',
    (tester) async {
      await tester.pumpWidget(
        loader(initial: null, fetch: () async => null),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JeeberRequestUnavailableScreen), findsOneWidget);
      expect(find.byType(JeeberRequestDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'cache miss + fetch throws → the unavailable fallback is preserved',
    (tester) async {
      await tester.pumpWidget(
        loader(initial: null, fetch: () async => throw Exception('offline')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JeeberRequestUnavailableScreen), findsOneWidget);
      expect(find.byType(JeeberRequestDetailScreen), findsNothing);
    },
  );

  testWidgets(
    'cache hit → detail renders synchronously and the fetch is NEVER called',
    (tester) async {
      var fetchCalls = 0;

      await tester.pumpWidget(
        loader(
          initial: recovered,
          fetch: () async {
            fetchCalls++;
            return null;
          },
        ),
      );
      // First frame already shows the detail — no loading flash, no fetch.
      await tester.pump();
      expect(find.byType(JeeberRequestDetailScreen), findsOneWidget);
      expect(find.byType(JeeberRequestDetailLoadingView), findsNothing);

      await tester.pumpAndSettle();
      expect(fetchCalls, 0);
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/friendly_reference.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  const requestId = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';
  const recovered = FeedRequest(id: requestId, shortLabel: 'Souq Waqif pickup');

  // MIDNIGHT: the unavailable fallback draws `JeebEmptyState`, whose E3
  // illustration loops ∞ by design — reduce motion pins its rest frame so
  // `pumpAndSettle` can settle (02-STUDY-NOTES, wave-B regression ruling).
  Widget loader({
    required FeedRequest? initial,
    required Future<FeedRequest?> Function() fetch,
    Future<String?> Function()? fetchAcceptedDeliveryId,
    ValueChanged<String>? onAcceptedRedirect,
  }) => wrapForTest(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: JeeberRequestDetailLoader(
          requestId: requestId,
          initial: initial,
          fetch: fetch,
          fetchAcceptedDeliveryId: fetchAcceptedDeliveryId,
          onAcceptedRedirect: onAcceptedRedirect,
          reportService: const ProhibitedItemReportService(),
          onDeclined: (_) {},
          onBack: () {},
        ),
      ),
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
      await tester.pump();
      expect(find.byType(JeeberRequestDetailLoadingView), findsOneWidget);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
      expect(find.byType(JeeberRequestDetailScreen), findsNothing);

      gate.complete(recovered);
      await tester.pumpAndSettle();

      expect(fetchCalls, 1);
      expect(find.byType(JeeberRequestDetailScreen), findsOneWidget);
      expect(find.text(friendlyReference(requestId)), findsOneWidget);
      expect(find.text(requestId), findsNothing);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
    },
  );

  testWidgets(
    'cache miss + fetch miss → the graceful unavailable fallback is preserved',
    (tester) async {
      await tester.pumpWidget(loader(initial: null, fetch: () async => null));
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
    'feed miss + accepted probe resolves → redirects to the active delivery, '
    'never shows the unavailable dead end',
    (tester) async {
      final redirects = <String>[];

      await tester.pumpWidget(
        loader(
          initial: null,
          fetch: () async => null, // pending feed rightly empty post-accept
          fetchAcceptedDeliveryId: () async => requestId,
          onAcceptedRedirect: redirects.add,
        ),
      );
      await tester.pump(); // feed fetch resolves
      await tester.pump(); // probe resolves → redirecting
      await tester.pump(); // post-frame redirect callback fires

      expect(redirects, [requestId]);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
      expect(find.byType(JeeberRequestDetailScreen), findsNothing);
      expect(find.byType(JeeberRequestDetailLoadingView), findsOneWidget);
    },
  );

  testWidgets(
    'feed miss + accepted probe misses → unavailable fallback preserved',
    (tester) async {
      final redirects = <String>[];

      await tester.pumpWidget(
        loader(
          initial: null,
          fetch: () async => null,
          fetchAcceptedDeliveryId: () async => null,
          onAcceptedRedirect: redirects.add,
        ),
      );
      await tester.pumpAndSettle();

      expect(redirects, isEmpty);
      expect(find.byType(JeeberRequestUnavailableScreen), findsOneWidget);
    },
  );

  testWidgets(
    'feed FETCH THROWS + accepted probe resolves → still redirects '
    '(offline feed must not mask an active delivery)',
    (tester) async {
      final redirects = <String>[];

      await tester.pumpWidget(
        loader(
          initial: null,
          fetch: () async => throw Exception('feed offline'),
          fetchAcceptedDeliveryId: () async => 'delivery-1',
          onAcceptedRedirect: redirects.add,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(redirects, ['delivery-1']);
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
    },
  );

  testWidgets(
    'accepted probe THROWS → unavailable fallback, no crash',
    (tester) async {
      await tester.pumpWidget(
        loader(
          initial: null,
          fetch: () async => null,
          fetchAcceptedDeliveryId: () async => throw Exception('offline'),
          onAcceptedRedirect: (_) => fail('must not redirect'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JeeberRequestUnavailableScreen), findsOneWidget);
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
      await tester.pump();
      expect(find.byType(JeeberRequestDetailScreen), findsOneWidget);
      expect(find.byType(JeeberRequestDetailLoadingView), findsNothing);

      await tester.pumpAndSettle();
      expect(fetchCalls, 0);
    },
  );
}

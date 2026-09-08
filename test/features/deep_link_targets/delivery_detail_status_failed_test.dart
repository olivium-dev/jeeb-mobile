// F18 / LR-25 — a FAILED status read settled into the "unknown" bucket and
// rendered the full CTA list, Cancel included, on a status nobody could read.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _FailingSummaryRepository implements OrderChatSummaryRepository {
  int reads = 0;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async {
    reads++;
    throw const OrderChatSummaryException(OrderChatSummaryFailure.network);
  }
}

class _InertRatingRepository implements RatingRepository {
  const _InertRatingRepository();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      RatingStatus(
        deliveryId: deliveryId,
        revealState: RatingRevealState.pendingMine,
      );
}

/// The screen mounts a `RootAwareBackScope`, which needs a real Router
/// ancestor — a plain `MaterialApp` host faults on the first frame.
Widget _host(
  OrderChatSummaryRepository repo, {
  Locale locale = const Locale('en'),
}) {
  final router = GoRouter(
    initialLocation: '/orders/DLV-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => DeliveryDetailScreen(
          deliveryId: state.pathParameters['id']!,
          summaryRepository: repo,
          ratingRepository: const _InertRatingRepository(),
        ),
      ),
      GoRoute(
        path: '/orders/:id/cancel',
        builder: (_, _) => const Scaffold(body: Text('cancel-sheet')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData.light(),
    locale: locale,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets('a failed status read says so and OMITS Cancel, EN + AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      useReduceMotion(tester);
      final repo = _FailingSummaryRepository();
      await tester.pumpWidget(_host(repo, locale: locale));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('order_detail_status_failed'),
        findsOneWidget,
        reason: 'locale: $locale',
      );
      expect(
        find.bySemanticsIdentifier('order_detail_retry_cta'),
        findsOneWidget,
      );
      // The destructive act must not ride out of an unread status.
      expect(
        find.bySemanticsIdentifier('order-detail-cancel'),
        findsNothing,
        reason: 'locale: $locale',
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DeliveryDetailScreen)),
      );
      expect(find.text(l10n.deliveryDetailStatusUnavailable), findsOneWidget);
    }
  });

  testWidgets('the retry CTA re-reads the status', (tester) async {
    useReduceMotion(tester);
    final repo = _FailingSummaryRepository();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final before = repo.reads;

    await tester.tap(find.bySemanticsIdentifier('order_detail_retry_cta'));
    await tester.pumpAndSettle();

    expect(repo.reads, greaterThan(before));
  });

  testWidgets('the list is pull-to-refreshable (LR-25)', (tester) async {
    useReduceMotion(tester);
    final repo = _FailingSummaryRepository();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final before = repo.reads;

    await tester.fling(
      find.byKey(const Key('delivery-detail-list')),
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repo.reads, greaterThan(before));
  });
}

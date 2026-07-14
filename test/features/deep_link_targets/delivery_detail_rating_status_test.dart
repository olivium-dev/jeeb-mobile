// JEBV4-308: the delivery-detail rating row is STATUS-AWARE. Before this fix it
// pushed the blank legacy `/orders/:id/feedback` form unconditionally, letting
// an already-rated user re-open a re-editable form and never reflecting the
// server-owned reveal state (`GET /v1/ratings/jeeb/{id}/status`).
//
// This locks three behaviours of the row:
//   * not-yet-rated (pendingMine)      → routes to the canonical mandatory
//                                         terminal `/orders/:id/mutual-rate`
//                                         (client leg, no `?mode=jeeber`);
//   * already-rated (pendingTheirs)    → shows a read-only "submitted" summary
//                                         and does NOT navigate;
//   * revealed (bothRated)             → shows a read-only summary carrying the
//                                         counterpart's stars, and does NOT
//                                         navigate;
//   * status unavailable (throws)      → degrades to the rating terminal so the
//                                         user is never blocked from rating.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Fake repository: returns a caller-supplied [RatingStatus] (or throws) from
/// `fetchRatingStatus`, and records whether `submitRating` was ever reached
/// (it must not be — the row only READS status).
class _FakeRatingRepository implements RatingRepository {
  _FakeRatingRepository({this.status, this.throwFailure});

  final RatingStatus? status;
  final RatingFailure? throwFailure;
  int fetchCount = 0;
  bool submitted = false;

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    fetchCount++;
    final failure = throwFailure;
    if (failure != null) {
      throw RatingRepositoryException(failure);
    }
    return status!;
  }

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    submitted = true;
  }
}

const _ratingRouteMarker = 'MUTUAL_RATE_ROUTE';
const _deliveryId = 'del-1';

Future<Widget> _host(_FakeRatingRepository repo) async {
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
          ratingRepository: repo,
        ),
      ),
      // Stub stand-in for the real MutualRatingScreen so the test asserts the
      // ROUTE (and its `mode` leg) without pulling the rating feature DI graph.
      GoRoute(
        path: '/orders/:id/mutual-rate',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'client';
          return Scaffold(
            body: Center(
              child: Text('$_ratingRouteMarker ${state.pathParameters['id']} '
                  'mode=$mode'),
            ),
          );
        },
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

Future<void> _tapRate(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('order-detail-rate')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'not-yet-rated → routes to canonical mutual-rate (client leg, no mode)',
    (tester) async {
      final repo = _FakeRatingRepository(
        status: const RatingStatus(
          deliveryId: _deliveryId,
          revealState: RatingRevealState.pendingMine,
        ),
      );
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();

      await _tapRate(tester);

      expect(repo.fetchCount, 1, reason: 'status is read before navigating');
      expect(
        find.text('$_ratingRouteMarker $_deliveryId mode=client'),
        findsOneWidget,
        reason: 'pendingMine → canonical mandatory terminal, client leg',
      );
      expect(repo.submitted, isFalse);
    },
  );

  testWidgets(
    'already-rated (pendingTheirs) → read-only summary, no navigation',
    (tester) async {
      final repo = _FakeRatingRepository(
        status: const RatingStatus(
          deliveryId: _deliveryId,
          revealState: RatingRevealState.pendingTheirs,
        ),
      );
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();
      // Resolve the real ARB-backed strings via the mounted context instead of
      // hardcoding copy.
      final ctx = tester.element(find.byKey(const Key('order-detail-rate')));
      final strings = AppLocalizations.of(ctx);

      await _tapRate(tester);

      // The blind legacy feedback / mutual-rate route must NOT have been reached.
      expect(find.textContaining(_ratingRouteMarker), findsNothing);
      // The read-only "submitted, awaiting counterpart" summary is shown.
      expect(find.text(strings.mutualRatingAwaitingTitle), findsOneWidget);
      expect(find.text(strings.mutualRatingAwaitingBody), findsOneWidget);
      expect(repo.submitted, isFalse);
    },
  );

  testWidgets(
    'revealed (bothRated) → summary shows counterpart stars, no navigation',
    (tester) async {
      final repo = _FakeRatingRepository(
        status: const RatingStatus(
          deliveryId: _deliveryId,
          revealState: RatingRevealState.bothRated,
          counterpartRating: CounterpartRating(stars: 4),
        ),
      );
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byKey(const Key('order-detail-rate')));
      final strings = AppLocalizations.of(ctx);

      await _tapRate(tester);

      expect(find.textContaining(_ratingRouteMarker), findsNothing);
      expect(find.text(strings.mutualRatingRevealedTitle), findsOneWidget);
      expect(find.text(strings.mutualRatingTheirStars(4)), findsOneWidget);
    },
  );

  testWidgets(
    'status unavailable (fetch throws) → degrades to rating terminal',
    (tester) async {
      final repo = _FakeRatingRepository(throwFailure: RatingFailure.network);
      await tester.pumpWidget(await _host(repo));
      await tester.pumpAndSettle();

      await _tapRate(tester);

      expect(repo.fetchCount, 1);
      expect(
        find.text('$_ratingRouteMarker $_deliveryId mode=client'),
        findsOneWidget,
        reason: 'unavailable status must never block the user from rating',
      );
    },
  );
}

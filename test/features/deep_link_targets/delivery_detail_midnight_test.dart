// M3-01 — MIDNIGHT adoption guards. Per-element assertions, NOT goldens: the
// comparator tolerates 5%, so a token re-point on a small element passes green.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

const String _deliveryId = 'del-1';
const String _rateMarker = 'MUTUAL_RATE';

/// Answers one canned summary, or holds the read open forever.
class _FakeSummaryRepository implements OrderChatSummaryRepository {
  _FakeSummaryRepository({this.summary, this.pending = false});

  final OrderChatSummary? summary;
  final bool pending;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) {
    if (pending) return Completer<OrderChatSummary>().future;
    return Future<OrderChatSummary>.value(
      summary ?? OrderChatSummary(deliveryId: deliveryId),
    );
  }
}

class _FakeRatingRepository implements RatingRepository {
  const _FakeRatingRepository(this.revealState);

  final RatingRevealState revealState;

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      RatingStatus(deliveryId: deliveryId, revealState: revealState);

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}
}

Future<Widget> _host({
  OrderChatSummaryRepository? summaryRepository,
  RatingRepository? ratingRepository,
  UserRole role = UserRole.client,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final cubit = RoleCubit(prefs: prefs, initialRole: role);
  final router = GoRouter(
    initialLocation: '/orders/$_deliveryId',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => DeliveryDetailScreen(
          deliveryId: state.pathParameters['id']!,
          summaryRepository: summaryRepository,
          ratingRepository: ratingRepository,
          refreshSignals: const Stream<void>.empty(),
        ),
      ),
      GoRoute(
        path: '/orders/:id/mutual-rate',
        builder: (context, state) =>
            Scaffold(body: Center(child: Text('$_rateMarker ${state.uri}'))),
      ),
    ],
  );
  return BlocProvider<RoleCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.midnight(),
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

void main() {
  group('field', () {
    testWidgets('mounts R21\'s content field: orange glow top-END, periwinkle '
        'wash top-START, decor STILL', (tester) async {
      await tester.pumpWidget(await _host());
      await tester.pumpAndSettle();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField).first,
      );
      expect(field.variant, JeebFieldVariant.content);
      // The two decorative layers are NOT interchangeable: the glow is orange,
      // the wash is periwinkle, and mirroring them is the known wave-C defect.
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      expect(field.washPlacement, JeebFieldWashPlacement.topStart);
      expect(field.animateDecor, isFalse, reason: 'R21 is a zero-motion tile');
    });
  });

  group('loading state', () {
    testWidgets('a status source with a read in flight renders the parcel '
        'skeleton, not a guessed action list', (tester) async {
      await tester.pumpWidget(
        await _host(summaryRepository: _FakeSummaryRepository(pending: true)),
      );
      await tester.pump();

      final empty = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(empty.status, JeebEmptyStateStatus.loading);
      expect(empty.variant, JeebEmptyStateVariant.parcel);
      // The frozen list identifier survives every state.
      expect(find.byKey(const Key('delivery-detail-list')), findsOneWidget);
      expect(find.byKey(const Key('order-detail-track')), findsNothing);
    });

    testWidgets('NO status source ⇒ no skeleton — fail-open is untouched',
        (tester) async {
      await tester.pumpWidget(await _host());
      await tester.pumpAndSettle();

      expect(find.byType(JeebEmptyState), findsNothing);
      expect(find.byKey(const Key('order-detail-track')), findsOneWidget);
      expect(find.byKey(const Key('order-detail-cancel')), findsOneWidget);
    });
  });

  group('active status band (R21 in-motion row)', () {
    Future<void> pumpActive(WidgetTester tester) async {
      await tester.pumpWidget(
        await _host(
          summaryRepository: _FakeSummaryRepository(
            summary: const OrderChatSummary(
              deliveryId: _deliveryId,
              statusId: 'InTransit',
              jeeberName: 'Karim',
              priceLabel: r'$8.00',
              etaMinutes: 20,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is an accent frame over the orange-12% tint, not rest glass',
        (tester) async {
      await pumpActive(tester);

      final card = tester.widget<JeebAccentFrameCard>(
        find.byKey(const Key('order-detail-status-active')),
      );
      expect(card.fill, JeebAccentFrameFill.accentTint);
    });

    testWidgets('live dot is the accent hex with the board glow', (tester) async {
      await pumpActive(tester);

      const Key dotKey = Key('order-detail-live-dot');
      final dot = tester.widget<Container>(find.byKey(dotKey));
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, JeebMidnight.orange);
      // `glowDot` is `0 0 10 orange@.85`; a flat dot would carry no shadow.
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.single.blurRadius, 10);
      expect(
        tester.getSize(find.byKey(dotKey)),
        const Size(9, 9),
        reason: 'R21 measures the live dot at Ø9',
      );
    });

    testWidgets('renders the summary facts it already fetched', (tester) async {
      await pumpActive(tester);
      final ctx = tester.element(find.byType(DeliveryDetailScreen));
      final l10n = AppLocalizations.of(ctx);

      expect(find.text(l10n.deliveryStageInTransit), findsOneWidget);
      expect(find.text('Karim'), findsOneWidget);
      expect(find.text(r'$8.00'), findsOneWidget);
      expect(find.text(l10n.deliveryDetailEtaMinutes(20)), findsOneWidget);
    });

    testWidgets('a bare summary draws the band with no meta run — absent, '
        'never faked', (tester) async {
      await tester.pumpWidget(
        await _host(
          summaryRepository: _FakeSummaryRepository(
            summary: const OrderChatSummary(
              deliveryId: _deliveryId,
              statusId: 'Ordered',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(DeliveryDetailScreen));
      expect(
        find.byKey(const Key('order-detail-status-active')),
        findsOneWidget,
      );
      // `Ordered` is R3's stepper wording, NOT the `Matched` vocab floor.
      expect(
        find.text(AppLocalizations.of(ctx).trackingStepOrdered),
        findsOneWidget,
      );
      expect(find.text('Karim'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);
    });
  });

  group('rating summary sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        await _host(
          ratingRepository: const _FakeRatingRepository(
            RatingRevealState.pendingTheirs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-detail-rate')));
      await tester.pumpAndSettle();
    }

    testWidgets('star is AMBER (#FFC107), not the orange budget', (tester) async {
      await openSheet(tester);

      final star = tester.widget<Icon>(
        find.descendant(
          of: find.bySemanticsIdentifier('delivery-rating-summary'),
          matching: find.byIcon(Icons.star_rounded),
        ),
      );
      expect(star.color, JeebMidnight.amber);
      expect(
        star.color,
        isNot(JeebMidnight.orange),
        reason: '§2.2 rations orange; a read-only summary is not a CTA',
      );
    });

    testWidgets('sits on the sheet field rung, not a bare Material sheet',
        (tester) async {
      await openSheet(tester);

      final field = tester.widget<JeebMidnightField>(
        find.descendant(
          of: find.bySemanticsIdentifier('delivery-rating-summary'),
          matching: find.byType(JeebMidnightField),
        ),
      );
      expect(field.variant, JeebFieldVariant.sheet);
      expect(field.animateDecor, isFalse);
    });
  });

  group('M2-11 carry-in — mutual-rate route threads the counterpart', () {
    testWidgets('client leg carries the jeeber name as ?name=', (tester) async {
      await tester.pumpWidget(
        await _host(
          summaryRepository: _FakeSummaryRepository(
            summary: const OrderChatSummary(
              deliveryId: _deliveryId,
              statusId: 'Done',
              jeeberName: 'Karim',
            ),
          ),
          ratingRepository: const _FakeRatingRepository(
            RatingRevealState.pendingMine,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-detail-rate')));
      await tester.pumpAndSettle();

      expect(
        find.text('$_rateMarker /orders/$_deliveryId/mutual-rate?name=Karim'),
        findsOneWidget,
      );
    });

    testWidgets('jeeber leg passes NO name — jeeberName is the viewer',
        (tester) async {
      await tester.pumpWidget(
        await _host(
          role: UserRole.jeeber,
          summaryRepository: _FakeSummaryRepository(
            summary: const OrderChatSummary(
              deliveryId: _deliveryId,
              statusId: 'Done',
              jeeberName: 'Karim',
            ),
          ),
          ratingRepository: const _FakeRatingRepository(
            RatingRevealState.pendingMine,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-detail-rate')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '$_rateMarker /orders/$_deliveryId/mutual-rate?mode=jeeber',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unresolved summary still routes — name is optional',
        (tester) async {
      await tester.pumpWidget(
        await _host(
          ratingRepository: const _FakeRatingRepository(
            RatingRevealState.pendingMine,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-detail-rate')));
      await tester.pumpAndSettle();

      expect(
        find.text('$_rateMarker /orders/$_deliveryId/mutual-rate'),
        findsOneWidget,
      );
    });
  });
}

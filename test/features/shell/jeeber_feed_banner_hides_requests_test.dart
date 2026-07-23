// Regression proof for the "jeeber sees an empty feed while the gateway is
// returning pending requests" bug (found live on SM-S908B, 2026-07-21).
//
// The gateway feed returned 2 pending requests every 10s poll and the cubit
// held both (verified on-device), yet the Requests tab looked empty. Cause: the
// "Your active deliveries" banner rode as row 0 of the feed's ListView, which
// lives inside a `SliverFillRemaining` whose viewport is only ~209dp once the
// greeting + availability card + search bar + tab/tier strips are laid out. The
// banner filled that viewport, so the request rows below it were never built
// and — with the outer CustomScrollView having nothing to scroll — were
// unreachable. The banner is now its own sliver above the list.
//
// This test pins the user-visible contract: with an active-deliveries banner
// AND pending requests, a card is on screen at device geometry, and on an even
// shorter viewport the cards are at least reachable by scrolling.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _StaticRepo implements ActiveDeliveriesRepository {
  const _StaticRepo(this.result);

  final List<ActiveDeliverySummary> result;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => result;
}

final _activeDelivery = ActiveDeliverySummary.fromJson(const {
  'id': 'req-active',
  'status': 'Ordered',
  'conversationId': 'conv-active',
  'title': '1kg hashish',
  'dropoff': {'address': 'Achrafieh'},
});

DeliveryRequest _feedRequest(String id, String summary) => DeliveryRequest(
  id: id,
  pickup: const RequestLocation(
    label: 'Pickup',
    latitude: 33.8,
    longitude: 35.5,
  ),
  dropoff: const RequestLocation(
    label: 'Dropoff',
    latitude: 33.9,
    longitude: 35.6,
  ),
  tier: JeeberRequestTier.light,
  estimatedDistanceKm: 1.2,
  potentialEarnings: 5.0,
  currency: 'USD',
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
  itemsSummary: summary,
  feedStatus: JeeberFeedItemStatus.incoming,
);

Widget _host({
  required AvailabilityCubit availability,
  required ActiveDeliveriesCubit deliveries,
  required RequestFeedCubit feed,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AvailabilityCubit>.value(value: availability),
        BlocProvider<ActiveDeliveriesCubit>.value(value: deliveries),
      ],
      child: JeeberHomeScreen(
        requestFeedCubit: feed,
        activeDeliveriesBanner: ActiveDeliveriesBanner(
          onOpenChat: (_) {},
          onManageDelivery: (_) {},
        ),
      ),
    ),
  );
}

class _FeedHarness {
  const _FeedHarness({
    required this.availability,
    required this.deliveries,
    required this.feed,
  });

  final AvailabilityCubit availability;
  final ActiveDeliveriesCubit deliveries;
  final RequestFeedCubit feed;

  Future<void> dispose(WidgetTester tester) async {
    // BlocProvider.value does not own these cubits. Unmount their listeners
    // first, then cancel every cubit-owned timer/subscription before the widget
    // test binding checks for leaked fake-async timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await deliveries.close();
    await feed.close();
    await availability.close();
  }
}

void main() {
  Future<_FeedHarness> pumpFeed(WidgetTester tester, Size surface) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final availability = AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(
        initial: AvailabilityStatus.initial.copyWith(
          state: AvailabilityState.online,
        ),
      ),
      tickerFactory: () => ticker.stream,
    );
    await availability.load();

    final feed = RequestFeedCubit(
      repository: SeededRequestFeedRepository([
        _feedRequest('req-1', '1 kilo Batata'),
        _feedRequest('req-2', '2 kg batata'),
      ]),
    );

    final deliveries = ActiveDeliveriesCubit(
      repository: _StaticRepo([_activeDelivery]),
      pollInterval: const Duration(hours: 1),
    )..start();

    await tester.pumpWidget(
      _host(availability: availability, deliveries: deliveries, feed: feed),
    );
    await feed.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    return _FeedHarness(
      availability: availability,
      deliveries: deliveries,
      feed: feed,
    );
  }

  testWidgets(
    'pending requests are laid out (not dropped) when an active-deliveries '
    'banner shares the feed page',
    (tester) async {
      final harness = await pumpFeed(tester, const Size(360, 800));
      try {
        expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
        // The rows used to be built inside a nested viewport barely taller than
        // the banner, so they never made it into the tree at all.
        expect(
          find.byType(JeeberFeedCard, skipOffstage: false),
          findsNWidgets(2),
          reason:
              'both pending requests the gateway returned must be laid out '
              'on the feed page alongside the banner',
        );
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets('scrolling the feed page brings the pending requests on screen', (
    tester,
  ) async {
    final harness = await pumpFeed(tester, const Size(360, 800));
    try {
      // Before the fix this drag moved nothing: the rows lived in an inner
      // viewport that could not scroll and the outer view had no overflow.
      await tester.drag(
        find.byKey(JeeberFeedTabView.rootKey),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(JeeberFeedCard),
        findsWidgets,
        reason: 'the request rows must scroll into view with the page',
      );
      expect(find.text('1 kilo Batata'), findsOneWidget);
    } finally {
      await harness.dispose(tester);
    }
  });
}

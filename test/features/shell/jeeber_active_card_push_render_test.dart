// PUSH-UI-REACTION widget proof (fix/active-card-push-render).

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
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// A repo whose result can flip between calls — models the live gateway that
/// returns no active delivery until the customer accepts, then the won delivery.
class _MutableRepo implements ActiveDeliveriesRepository {
  List<ActiveDeliverySummary> result = const <ActiveDeliverySummary>[];
  int calls = 0;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    calls++;
    return result;
  }
}

final _wonDelivery = ActiveDeliverySummary.fromJson(const {
  'id': 'req-won',
  'status': 'Ordered',
  'conversationId': 'conv-won',
  'title': 'Flash delivery request',
  'dropoff': {'address': 'Achrafieh'},
});

DeliveryRequest _feedRequest(String id) => DeliveryRequest(
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
  tier: JeeberRequestTier.flash,
  estimatedDistanceKm: 1.2,
  potentialEarnings: 5.0,
  currency: 'USD',
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
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
        // A non-null feed cubit drives the ONLINE + non-empty-feed body (the
        requestFeedCubit: feed,
        activeDeliveriesBanner: ActiveDeliveriesBanner(
          onOpenChat: (_) {},
          onManageDelivery: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the compact active-deliveries disclosure re-renders on a push refresh '
    'signal while the '
    'jeeber is ONLINE with a non-empty feed (not gated to the no-requests scope '
    'or the slow poll)',
    (tester) async {
      // 360-wide: the card actions stack full-width (no RenderFlex overflow —
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final signals = StreamController<void>.broadcast();
      addTearDown(signals.close);

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
      addTearDown(availability.close);
      await availability.load();

      // Non-empty feed → the feed body renders (the offered request still
      final feed = RequestFeedCubit(
        repository: SeededRequestFeedRepository([_feedRequest('pending-1')]),
      );
      addTearDown(feed.close);

      final repo = _MutableRepo();
      // Long poll so the ONLY refetch that can surface the card comes from the
      final deliveries = ActiveDeliveriesCubit(
        repository: repo,
        refreshSignals: signals.stream,
      )..start();

      await tester.pumpWidget(
        _host(availability: availability, deliveries: deliveries, feed: feed),
      );
      await feed.refresh();
      // Drain the initial (empty) active-deliveries load + feed load.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // We are in the feed body (online, request pending) and active work is
      expect(find.byType(JeeberHomeScreen), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_card_pending-1'),
        findsOneWidget,
      );
      expect(
        find.text('Flash delivery request'),
        findsNothing,
        reason: 'no active delivery yet → the disclosure must be hidden',
      );

      // Customer accepts: the next refetch returns the won delivery and the
      repo.result = [_wonDelivery];
      signals.add(null);

      // A couple of frames — NOT the ~95s poll/feed-empties cadence.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The compact disclosure is now on screen (rebuilt off the push-triggered
      expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
      expect(find.text('Your active deliveries'), findsOneWidget);
      expect(find.text('View all (1)'), findsOneWidget);
      expect(find.text('Flash delivery request'), findsNothing);
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_card_pending-1'),
        findsOneWidget,
        reason: 'surfacing active work must not displace the live feed',
      );

      await tester.tap(
        find.bySemanticsIdentifier('jeeber_active_deliveries_view_all'),
      );
      await tester.pump();

      expect(
        find.text('Flash delivery request'),
        findsOneWidget,
        reason:
            'the just-won Ordered delivery card must be available from the '
            'push-rendered disclosure while the feed is non-empty',
      );
      expect(repo.calls, greaterThanOrEqualTo(2)); // initial + push refetch
      expect(tester.takeException(), isNull);

      await deliveries.close();
    },
  );
}

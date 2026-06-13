import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

DeliveryRequest _makeRequest({
  required String id,
  required JeeberRequestTier tier,
}) {
  return DeliveryRequest(
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
    tier: tier,
    estimatedDistanceKm: 1.2,
    potentialEarnings: 5.0,
    currency: 'USD',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    feedStatus: JeeberFeedItemStatus.incoming,
  );
}

Widget _host({
  required List<DeliveryRequest> requests,
  AvailabilityState avState = AvailabilityState.online,
  required AvailabilityCubit avCubit,
  required RequestFeedCubit feedCubit,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<AvailabilityCubit>.value(value: avCubit),
          BlocProvider<RequestFeedCubit>.value(value: feedCubit),
        ],
        child: const JeeberFeedTabView(),
      ),
    ),
  );
}

void main() {
  group('JeeberFeedTabView – tier filter chips', () {
    testWidgets(
      'AC1: tier filter strip renders when Jeeber is online',
      (tester) async {
        final ticker = StreamController<DateTime>.broadcast();
        addTearDown(ticker.close);
        final avCubit = AvailabilityCubit(
          gateway: InMemoryAvailabilityGateway(
            initial: AvailabilityStatus.initial.copyWith(
              state: AvailabilityState.online,
            ),
          ),
          tickerFactory: () => ticker.stream,
        );
        addTearDown(avCubit.close);
        final feedCubit = RequestFeedCubit(
          repository: SeededRequestFeedRepository(
            [_makeRequest(id: '1', tier: JeeberRequestTier.flash)],
          ),
        );
        addTearDown(feedCubit.close);

        await avCubit.load();
        await tester.pumpWidget(
          _host(
            requests: [],
            avCubit: avCubit,
            feedCubit: feedCubit,
          ),
        );
        await tester.pump();
        await feedCubit.refresh();
        await tester.pumpAndSettle();

        expect(find.byKey(JeeberFeedTabView.tierStripKey), findsOneWidget);
      },
    );

    testWidgets(
      'AC2: Flash chip activates and filters requests by tier',
      (tester) async {
        final ticker = StreamController<DateTime>.broadcast();
        addTearDown(ticker.close);
        final avCubit = AvailabilityCubit(
          gateway: InMemoryAvailabilityGateway(
            initial: AvailabilityStatus.initial.copyWith(
              state: AvailabilityState.online,
            ),
          ),
          tickerFactory: () => ticker.stream,
        );
        addTearDown(avCubit.close);
        final requests = [
          _makeRequest(id: 'flash-1', tier: JeeberRequestTier.flash),
          _makeRequest(id: 'std-1', tier: JeeberRequestTier.standard),
        ];
        final feedCubit = RequestFeedCubit(
          repository: SeededRequestFeedRepository(requests),
        );
        addTearDown(feedCubit.close);

        await avCubit.load();
        await tester.pumpWidget(
          _host(requests: requests, avCubit: avCubit, feedCubit: feedCubit),
        );
        await feedCubit.refresh();
        await tester.pumpAndSettle();

        // Initially All selected — list is visible.
        expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);

        // Tap the Flash chip — use descendant finder to avoid ambiguity with
        // feed card tier labels that also display "Flash".
        final l10n = AppLocalizations.of(
          tester.element(find.byKey(JeeberFeedTabView.tierStripKey)),
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(JeeberFeedTabView.tierStripKey),
            matching: find.text(l10n.jeeberFeedTierFlash),
          ),
        );
        await tester.pumpAndSettle();

        // List still rendered (flash-1 matches).
        expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);
      },
    );

    testWidgets(
      'AC3: offline banner is shown when Jeeber is offline',
      (tester) async {
        final avCubit = AvailabilityCubit(
          gateway: InMemoryAvailabilityGateway(
            initial: AvailabilityStatus.initial.copyWith(
              state: AvailabilityState.offline,
            ),
          ),
        );
        addTearDown(avCubit.close);
        final feedCubit = RequestFeedCubit(
          repository: SeededRequestFeedRepository([]),
        );
        addTearDown(feedCubit.close);

        await avCubit.load();
        await tester.pumpWidget(
          _host(requests: [], avCubit: avCubit, feedCubit: feedCubit),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(JeeberFeedTabView)),
        );
        expect(
          find.text(l10n.jeeberFeedOfflineBannerTitle),
          findsWidgets,
        );
        // Feed list should not be visible when offline.
        expect(find.byKey(JeeberFeedTabView.listKey), findsNothing);
      },
    );

    testWidgets(
      'tier filter strip is hidden when Jeeber is offline',
      (tester) async {
        final avCubit = AvailabilityCubit(
          gateway: InMemoryAvailabilityGateway(
            initial: AvailabilityStatus.initial.copyWith(
              state: AvailabilityState.offline,
            ),
          ),
        );
        addTearDown(avCubit.close);
        final feedCubit = RequestFeedCubit(
          repository: SeededRequestFeedRepository([]),
        );
        addTearDown(feedCubit.close);

        await avCubit.load();
        await tester.pumpWidget(
          _host(requests: [], avCubit: avCubit, feedCubit: feedCubit),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(JeeberFeedTabView.tierStripKey), findsNothing);
      },
    );
  });
}

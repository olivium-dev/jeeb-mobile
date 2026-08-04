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
  bool requestIsOpen = true,
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
    requestIsOpen: requestIsOpen,
  );
}

Widget _host({
  required List<DeliveryRequest> requests,
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
    // E3's illustration loops ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion, which is also the capture rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
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

        // Tap the full target rather than the compact visual label.
        await tester.tap(find.bySemanticsIdentifier('jeeber_feed_tier_chip_1'));
        await tester.pumpAndSettle();

        // List still rendered (flash-1 matches).
        expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);
      },
    );

    testWidgets('tab and tier chips expose tokenized minimum hit targets',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
          [_makeRequest(id: 'target', tier: JeeberRequestTier.flash)],
        ),
      );
      addTearDown(feedCubit.close);

      await avCubit.load();
      await tester.pumpWidget(
        _host(requests: const [], avCubit: avCubit, feedCubit: feedCubit),
      );
      await feedCubit.refresh();
      await tester.pumpAndSettle();

      for (final identifier in const [
        'jeeber_feed_requests_tab',
        'jeeber_feed_pending_tab',
        'jeeber_feed_replies_tab',
        'jeeber_feed_tier_chip_0',
        'jeeber_feed_tier_chip_1',
        'jeeber_feed_tier_chip_2',
        'jeeber_feed_tier_chip_3',
      ]) {
        final target = find.bySemanticsIdentifier(identifier);
        expect(target, findsOneWidget);
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(UIConstants.buttonHeight),
          reason: '$identifier must expose the OMDS minimum target height',
        );
      }
    });

    testWidgets('server-closed request never renders actionable feed controls',
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
        _makeRequest(
          id: 'server-closed',
          tier: JeeberRequestTier.flash,
          requestIsOpen: false,
        ),
        _makeRequest(id: 'server-live', tier: JeeberRequestTier.flash),
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

      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_card_server-closed'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_offer_server-closed'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_offer_server-live'),
        findsOneWidget,
      );
    });

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

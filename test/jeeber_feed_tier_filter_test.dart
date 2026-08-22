import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_filter_pills.dart';
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

AvailabilityCubit _availability(WidgetTester tester, AvailabilityState state) {
  final ticker = StreamController<DateTime>.broadcast();
  addTearDown(ticker.close);
  final cubit = AvailabilityCubit(
    gateway: InMemoryAvailabilityGateway(
      initial: AvailabilityStatus.initial.copyWith(state: state),
    ),
    tickerFactory: () => ticker.stream,
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<RequestFeedCubit> _pumpOnline(
  WidgetTester tester,
  List<DeliveryRequest> requests, {
  Size size = const Size(400, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final avCubit = _availability(tester, AvailabilityState.online);
  final feedCubit = RequestFeedCubit(
    repository: SeededRequestFeedRepository(requests),
  );
  addTearDown(feedCubit.close);
  await avCubit.load();
  await tester.pumpWidget(_host(avCubit: avCubit, feedCubit: feedCubit));
  await tester.pump();
  await feedCubit.refresh();
  await tester.pumpAndSettle();
  return feedCubit;
}

Future<void> _openFilterSheet(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_open'));
  await tester.pumpAndSettle();
}

Finder _card(String id, {bool skipOffstage = true}) =>
    find.byKey(Key('jeeber-feed-card-$id'), skipOffstage: skipOffstage);

void main() {
  group('JeeberFeedTabView – tier facet in the filter sheet', () {
    testWidgets('AC1: the tier group lives in the sheet, not on the board', (
      tester,
    ) async {
      await _pumpOnline(tester, [
        _makeRequest(id: '1', tier: JeeberRequestTier.flash),
      ]);

      // The board is chrome-light at rest: no tier row above the first card.
      expect(find.byKey(JeeberFeedTabView.tierStripKey), findsNothing);

      await _openFilterSheet(tester);

      expect(find.byKey(JeeberFeedTabView.tierStripKey), findsOneWidget);
      expect(find.byKey(JeeberFeedTabView.searchBarKey), findsOneWidget);
    });

    testWidgets('AC2: staging Flash then applying narrows the list by tier', (
      tester,
    ) async {
      await _pumpOnline(tester, [
        _makeRequest(id: 'flash-1', tier: JeeberRequestTier.flash),
        _makeRequest(id: 'std-1', tier: JeeberRequestTier.standard),
      ]);

      expect(_card('flash-1'), findsOneWidget);
      expect(_card('std-1'), findsOneWidget);

      await _openFilterSheet(tester);
      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_tier_chip_1'));
      await tester.pumpAndSettle();

      // Staged only: the feed behind the sheet is untouched until Apply.
      expect(_card('std-1', skipOffstage: false), findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_apply'));
      await tester.pumpAndSettle();

      expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);
      expect(_card('flash-1'), findsOneWidget);
      expect(_card('std-1'), findsNothing);
    });

    testWidgets('the applied tier surfaces as a pill whose ✕ clears it', (
      tester,
    ) async {
      await _pumpOnline(tester, [
        _makeRequest(id: 'flash-1', tier: JeeberRequestTier.flash),
        _makeRequest(id: 'std-1', tier: JeeberRequestTier.standard),
      ]);

      await _openFilterSheet(tester);
      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_tier_chip_1'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_apply'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(JeeberFeedTabView)),
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_filter_pill_tier'),
        findsOneWidget,
      );
      final pill = tester.widget<JeebFilterPill>(find.byType(JeebFilterPill));
      expect(pill.label, l10n.jeeberFeedTierFlash);

      await tester.tap(
        find.bySemanticsIdentifier('jeeber_feed_filter_pill_tier_clear'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_filter_pill_tier'),
        findsNothing,
      );
      expect(_card('std-1'), findsOneWidget);
    });

    testWidgets('tapping a pill body reopens the sheet on the same facet', (
      tester,
    ) async {
      await _pumpOnline(tester, [
        _makeRequest(id: 'flash-1', tier: JeeberRequestTier.flash),
      ]);

      await _openFilterSheet(tester);
      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_tier_chip_1'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_apply'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('jeeber_feed_filter_pill_tier'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_filter_sheet'),
        findsOneWidget,
      );
      expect(find.byKey(JeeberFeedTabView.tierStripKey), findsOneWidget);
    });

    testWidgets('stage tabs and tier chips expose tokenized minimum targets', (
      tester,
    ) async {
      await _pumpOnline(tester, [
        _makeRequest(id: 'target', tier: JeeberRequestTier.flash),
      ], size: const Size(800, 1200));

      for (final identifier in const [
        'jeeber_feed_requests_tab',
        'jeeber_feed_pending_tab',
        'jeeber_feed_replies_tab',
      ]) {
        final target = find.bySemanticsIdentifier(identifier);
        expect(target, findsOneWidget);
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(UIConstants.buttonHeight),
          reason: '$identifier must expose the OMDS minimum target height',
        );
      }

      await _openFilterSheet(tester);

      for (final identifier in const [
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

    testWidgets('the tier group is hidden on stages tier never applied to', (
      tester,
    ) async {
      await _pumpOnline(tester, [
        _makeRequest(id: 'flash-1', tier: JeeberRequestTier.flash),
      ]);

      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_replies_tab'));
      await tester.pumpAndSettle();
      await _openFilterSheet(tester);

      expect(find.byKey(JeeberFeedTabView.searchBarKey), findsOneWidget);
      expect(find.byKey(JeeberFeedTabView.tierStripKey), findsNothing);
    });

    testWidgets('server-closed request never renders actionable feed controls', (
      tester,
    ) async {
      await _pumpOnline(tester, [
        _makeRequest(
          id: 'server-closed',
          tier: JeeberRequestTier.flash,
          requestIsOpen: false,
        ),
        _makeRequest(id: 'server-live', tier: JeeberRequestTier.flash),
      ]);

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

    testWidgets('AC3: offline banner is shown when Jeeber is offline', (
      tester,
    ) async {
      final avCubit = _availability(tester, AvailabilityState.offline);
      final feedCubit = RequestFeedCubit(
        repository: SeededRequestFeedRepository([]),
      );
      addTearDown(feedCubit.close);

      await avCubit.load();
      await tester.pumpWidget(_host(avCubit: avCubit, feedCubit: feedCubit));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(JeeberFeedTabView)),
      );
      expect(find.text(l10n.jeeberFeedOfflineBannerTitle), findsWidgets);
      expect(find.byKey(JeeberFeedTabView.listKey), findsNothing);
    });

    testWidgets('the filter disc is hidden when Jeeber is offline', (
      tester,
    ) async {
      final avCubit = _availability(tester, AvailabilityState.offline);
      final feedCubit = RequestFeedCubit(
        repository: SeededRequestFeedRepository([]),
      );
      addTearDown(feedCubit.close);

      await avCubit.load();
      await tester.pumpWidget(_host(avCubit: avCubit, feedCubit: feedCubit));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_filter_open'),
        findsNothing,
      );
      expect(find.byKey(JeeberFeedTabView.tierStripKey), findsNothing);
    });
  });
}

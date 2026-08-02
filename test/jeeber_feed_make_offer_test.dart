import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offer.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offers_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// JM-048 — Delivery Feed: make-offer routing through the KYC gate / composer
/// and the Pending-Response sub-tab backed by submitted-offer data.
void main() {
  DeliveryRequest incoming(String id) => DeliveryRequest(
        id: id,
        pickup: const RequestLocation(
          label: 'Spinneys Dbayeh',
          latitude: 33.8,
          longitude: 35.5,
        ),
        dropoff: const RequestLocation(
          label: 'Home, Ashrafieh',
          latitude: 33.9,
          longitude: 35.6,
        ),
        tier: JeeberRequestTier.standard,
        estimatedDistanceKm: 1.2,
        potentialEarnings: 10.0,
        currency: 'USD',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        feedStatus: JeeberFeedItemStatus.incoming,
      );

  AvailabilityCubit onlineCubit(StreamController<DateTime> ticker) {
    return AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(
        initial: AvailabilityStatus.initial.copyWith(
          state: AvailabilityState.online,
        ),
      ),
      tickerFactory: () => ticker.stream,
    );
  }

  Widget host({
    required AvailabilityCubit avCubit,
    required RequestFeedCubit feedCubit,
    ValueChanged<DeliveryRequest>? onMakeOffer,
    SubmittedOffersCubit? submittedOffersCubit,
    JeeberFeedTab initialTab = JeeberFeedTab.requests,
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
          child: JeeberFeedTabView(
            initialTab: initialTab,
            onMakeOffer: onMakeOffer,
            submittedOffersCubit: submittedOffersCubit,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'AC1/AC2: feed_make_offer_cta is exposed on the first incoming row and '
    'taps route make-offer (not a plain detail open)',
    (tester) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final avCubit = onlineCubit(ticker);
      addTearDown(avCubit.close);
      final requests = [incoming('req-feed-001'), incoming('req-feed-002')];
      final feedCubit = RequestFeedCubit(
        repository: SeededRequestFeedRepository(requests),
      );
      addTearDown(feedCubit.close);

      DeliveryRequest? offered;
      await avCubit.load();
      await tester.pumpWidget(
        host(
          avCubit: avCubit,
          feedCubit: feedCubit,
          onMakeOffer: (r) => offered = r,
        ),
      );
      await feedCubit.refresh();
      await tester.pumpAndSettle();

      // Exactly one screen-level make-offer CTA (the first incoming row).
      expect(find.bySemanticsIdentifier('feed_make_offer_cta'), findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier('feed_make_offer_cta'));
      await tester.pump();

      // Make-offer routing fired with the first request (the gate/composer
      expect(offered, isNotNull);
      expect(offered!.id, 'req-feed-001');
    },
  );

  testWidgets(
    'AC3: jeeber_feed_pending_tab switches to the Pending sub-tab and renders '
    'pending_offer_0 from submitted-offer data',
    (tester) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final avCubit = onlineCubit(ticker);
      addTearDown(avCubit.close);
      final feedCubit = RequestFeedCubit(
        repository: SeededRequestFeedRepository([incoming('req-feed-001')]),
      );
      addTearDown(feedCubit.close);
      final submittedCubit = SubmittedOffersCubit(
        repository: _FakeSubmittedOffersRepository([
          const SubmittedOffer(
            id: 'pending-offer-jeeber-001',
            requestId: 'req-feed-001',
            price: 9.0,
            currency: 'USD',
            etaMinutes: 25,
          ),
        ]),
      );
      addTearDown(submittedCubit.close);

      await avCubit.load();
      await tester.pumpWidget(
        host(
          avCubit: avCubit,
          feedCubit: feedCubit,
          submittedOffersCubit: submittedCubit,
        ),
      );
      await feedCubit.refresh();
      await tester.pumpAndSettle();

      // The pending tab chip carries the coined id.
      final pendingTab = find.bySemanticsIdentifier('jeeber_feed_pending_tab');
      expect(pendingTab, findsOneWidget);

      await tester.tap(pendingTab);
      await tester.pumpAndSettle();

      // The first submitted offer renders with its row + price + withdraw CTA.
      expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);
      expect(find.bySemanticsIdentifier('pending_offer_0_price'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AC3: withdrawing pending_offer_0 removes it from the list',
    (tester) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final avCubit = onlineCubit(ticker);
      addTearDown(avCubit.close);
      final feedCubit = RequestFeedCubit(
        repository: SeededRequestFeedRepository([incoming('req-feed-001')]),
      );
      addTearDown(feedCubit.close);
      final repo = _FakeSubmittedOffersRepository([
        const SubmittedOffer(
          id: 'pending-offer-jeeber-001',
          requestId: 'req-feed-001',
          price: 9.0,
          currency: 'USD',
          etaMinutes: 25,
        ),
      ]);
      final submittedCubit = SubmittedOffersCubit(repository: repo);
      addTearDown(submittedCubit.close);

      await avCubit.load();
      await tester.pumpWidget(
        host(
          avCubit: avCubit,
          feedCubit: feedCubit,
          submittedOffersCubit: submittedCubit,
          initialTab: JeeberFeedTab.pendingResponse,
        ),
      );
      await feedCubit.refresh();
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('pending_offer_0'), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('pending_offer_0_withdraw_cta'),
      );
      await tester.pumpAndSettle();

      expect(repo.withdrawnIds, ['pending-offer-jeeber-001']);
      expect(find.bySemanticsIdentifier('pending_offer_0'), findsNothing);
    },
  );
}

class _FakeSubmittedOffersRepository implements SubmittedOffersRepository {
  _FakeSubmittedOffersRepository(this._offers);

  final List<SubmittedOffer> _offers;
  final List<String> withdrawnIds = [];

  @override
  Future<List<SubmittedOffer>> listSubmitted() async =>
      List<SubmittedOffer>.unmodifiable(_offers);

  @override
  Future<bool> withdraw(String offerId) async {
    withdrawnIds.add(offerId);
    return true;
  }
}

// UX-03 / UX-04 / LR-06: the Pending sub-tab must show an outage as an outage,
// and a failed withdraw must free the row and say so.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_pending_offers_screen_fixtures.dart';
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

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const _offers = <SubmittedOffer>[
  SubmittedOffer(id: 'o1', requestId: 'r1', price: 12, currency: 'USD'),
];

class _InertFeedRepository implements RequestFeedRepository {
  const _InertFeedRepository();

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport =>
      const Stream<FeedTransportUpdate>.empty();

  @override
  Future<List<DeliveryRequest>> refresh() async => const <DeliveryRequest>[];

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}

AvailabilityCubit _onlineAvailability() => AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(
        initial: const AvailabilityStatus(
          state: AvailabilityState.online,
          activeDeliveryCount: 0,
        ),
      ),
      tickerFactory: () => const Stream<DateTime>.empty(),
    );

Future<void> _pumpPendingTab(
  WidgetTester tester,
  SubmittedOffersCubit offers, {
  Locale locale = const Locale('en'),
}) async {
  final availability = _onlineAvailability();
  addTearDown(availability.close);
  final feed = RequestFeedCubit(repository: const _InertFeedRepository());
  addTearDown(feed.close);

  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapForTest(
      Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<AvailabilityCubit>.value(value: availability),
            BlocProvider<RequestFeedCubit>.value(value: feed),
          ],
          child: JeeberFeedTabView(
            profileName: 'Kamal',
            initialTab: JeeberFeedTab.pendingResponse,
            submittedOffersCubit: offers,
          ),
        ),
      ),
      locale: locale,
    ),
  );
  await availability.load();
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a failed read draws the ERROR rung, never the empty '
        'one', (tester) async {
      final cubit = SubmittedOffersCubit(
        repository: const FailingSubmittedOffersRepository(
          ServerFailure(status: 503),
        ),
      );
      addTearDown(cubit.close);

      await _pumpPendingTab(tester, cubit, locale: locale);

      expect(
        find.bySemanticsIdentifier('jeeber_pending_offers_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_pending_offers_retry_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_pending_offers_empty_state'),
        findsNothing,
        reason: 'an outage is not "no pending offers"',
      );
    });

    testWidgets('[$tag] a failed WITHDRAW frees the row and raises the snack',
        (tester) async {
      final cubit = SubmittedOffersCubit(
        repository: const WithdrawFailingSubmittedOffersRepository(
          _offers,
          NetworkFailure(),
        ),
      );
      addTearDown(cubit.close);

      await _pumpPendingTab(tester, cubit, locale: locale);
      expect(cubit.state.offers, hasLength(1));

      await cubit.withdraw('o1');
      await tester.pumpAndSettle();

      expect(
        cubit.state.isWithdrawing('o1'),
        isFalse,
        reason: 'LR-06: the busy id must clear on the failure path too',
      );
      expect(
        find.bySemanticsIdentifier('pending_offers_withdraw_failed_snack'),
        findsOneWidget,
      );
      expect(cubit.state.offers, hasLength(1));
    });
  }

  testWidgets('the loading rung has its own identifier and headline (ES-08)',
      (tester) async {
    final cubit = SubmittedOffersCubit(
      repository: const JeeberPendingOffersScreenStalledOffers(),
    );
    addTearDown(cubit.close);

    await _pumpPendingTab(tester, cubit);

    expect(
      find.bySemanticsIdentifier('jeeber_pending_offers_loading'),
      findsOneWidget,
    );
  });

  testWidgets('a withdraw that answers a clean FALSE still tells the jeeber',
      (tester) async {
    final cubit = SubmittedOffersCubit(
      repository: const _RefusingRepository(_offers),
    );
    addTearDown(cubit.close);

    await _pumpPendingTab(tester, cubit);
    await cubit.withdraw('o1');
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('pending_offers_withdraw_failed_snack'),
      findsOneWidget,
    );
    expect(cubit.state.isWithdrawing('o1'), isFalse);
  });
}

class _RefusingRepository implements SubmittedOffersRepository {
  const _RefusingRepository(this.offers);

  final List<SubmittedOffer> offers;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => offers;

  @override
  Future<bool> withdraw(String offerId) async => false;
}

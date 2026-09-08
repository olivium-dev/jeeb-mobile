// R6: an unrecoverable kind gets a way OUT. The live 403 for a KYC-pending
// jeeber lands on these rungs; before this they drew a block with no CTA.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_pending_offers_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const AppFailure _forbidden = ForbiddenFailure();

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

/// The block draws exactly ONE CTA: on an unrecoverable kind it must be the
/// exit, and the retry id must be absent.
void _expectExitOnly(String screenId) {
  expect(
    find.bySemanticsIdentifier('${screenId}_exit_cta'),
    findsOneWidget,
    reason: 'an unrecoverable kind must still offer a way out',
  );
  expect(
    find.bySemanticsIdentifier('${screenId}_retry_cta'),
    findsNothing,
    reason: 'a Retry that cannot win is an inert CTA',
  );
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] the dashboard feed 403 offers an exit, not a Retry',
        (tester) async {
      final availability = _onlineAvailability();
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.failedFeed(_forbidden);
      addTearDown(feed.close);

      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<AvailabilityCubit>.value(
            value: availability,
            child: JeeberHomeScreen(requestFeedCubit: feed, profileName: 'Kamal'),
          ),
          locale: locale,
        ),
      );
      await availability.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_home_feed_error'),
        findsOneWidget,
      );
      _expectExitOnly('jeeber_home_feed');
    });

    testWidgets('[$tag] the pending sub-tab 403 offers an exit, not a Retry',
        (tester) async {
      final availability = _onlineAvailability();
      addTearDown(availability.close);
      final feed = RequestFeedCubit(repository: const _InertFeedRepository());
      addTearDown(feed.close);
      final offers = SubmittedOffersCubit(
        repository: const FailingSubmittedOffersRepository(_forbidden),
      );
      addTearDown(offers.close);

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

      expect(
        find.bySemanticsIdentifier('jeeber_pending_offers_error'),
        findsOneWidget,
      );
      _expectExitOnly('jeeber_pending_offers');
    });

    testWidgets('[$tag] the pending-offers SCREEN 403 offers an exit',
        (tester) async {
      final offers = SubmittedOffersCubit(
        repository: const FailingSubmittedOffersRepository(_forbidden),
      );
      addTearDown(offers.close);
      await offers.load();

      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(
          JeeberPendingOffersScreen(cubit: offers),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('pending_offers_error'),
        findsOneWidget,
      );
      _expectExitOnly('pending_offers');
    });
  }
}

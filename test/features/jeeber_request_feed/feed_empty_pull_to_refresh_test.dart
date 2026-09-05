// Brief §C-16: an EMPTY board must still be pullable — on the pending sub-tab
// and on the filtered-empty rung, not just on the unfiltered feed.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
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

/// Counts reads so the pull gesture can be proven to reach the data layer.
class _CountingEmptyOffersRepository implements SubmittedOffersRepository {
  int reads = 0;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    reads++;
    return const <SubmittedOffer>[];
  }

  @override
  Future<bool> withdraw(String offerId) async => true;
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

Widget _host(
  AvailabilityCubit availability,
  RequestFeedCubit feed, {
  SubmittedOffersCubit? offers,
  JeeberFeedTab initialTab = JeeberFeedTab.requests,
}) =>
    wrapForTest(
      Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<AvailabilityCubit>.value(value: availability),
            BlocProvider<RequestFeedCubit>.value(value: feed),
          ],
          child: JeeberFeedTabView(
            profileName: 'Kamal',
            initialTab: initialTab,
            submittedOffersCubit: offers,
          ),
        ),
      ),
    );

void main() {
  testWidgets('the PENDING empty list is pullable and the pull reaches the '
      'repository', (tester) async {
    final availability = _onlineAvailability();
    addTearDown(availability.close);
    final feed = RequestFeedCubit(repository: const _InertFeedRepository());
    addTearDown(feed.close);
    final repository = _CountingEmptyOffersRepository();
    final offers = SubmittedOffersCubit(repository: repository);
    addTearDown(offers.close);

    useReduceMotion(tester);
    await tester.pumpWidget(
      _host(
        availability,
        feed,
        offers: offers,
        initialTab: JeeberFeedTab.pendingResponse,
      ),
    );
    await availability.load();
    await tester.pumpAndSettle();

    final empty = find.bySemanticsIdentifier('jeeber_pending_offers_empty_state');
    expect(empty, findsOneWidget);
    expect(
      find.ancestor(of: empty, matching: find.byType(JeebPullToRefresh)),
      findsWidgets,
      reason: 'the PTR must wrap the whole body, empty list included',
    );

    final before = repository.reads;
    expect(before, greaterThanOrEqualTo(1));

    await tester.fling(empty, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.reads, greaterThan(before));
  });

  // The filtered rung is sliver-hosted, so the page PTR does not see the drag
  // (stage2-wanted §5); only the wrapping is asserted here, not the gesture.
  testWidgets('the FILTERED empty rung sits inside the page pull-to-refresh',
      (tester) async {
    final availability = _onlineAvailability();
    addTearDown(availability.close);
    final feed = JeeberHomeScreenPreviewFixtures.feed(
      JeeberHomeScreenPreviewFixtures.filteredEmptyFeed(),
    );
    addTearDown(feed.close);

    useReduceMotion(tester);
    await tester.pumpWidget(_host(availability, feed));
    await availability.load();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(JeeberFeedTabView.searchBarKey),
        matching: find.byType(EditableText),
      ),
      'zzzz-no-such-request',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_apply'));
    await tester.pumpAndSettle();

    final filtered = find.bySemanticsIdentifier('jeeber_feed_filtered_empty_state');
    expect(filtered, findsOneWidget);
    expect(
      find.ancestor(of: filtered, matching: find.byType(JeebPullToRefresh)),
      findsWidgets,
      reason: 'a filtered board must still sit under the refresh host',
    );
  });
}

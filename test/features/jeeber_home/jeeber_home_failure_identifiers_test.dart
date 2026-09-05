// TEST-10: five ids the jeeber dashboard has shipped unasserted. Bound here so
// a rename is a test failure, not a silently dead Maestro selector.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

AvailabilityCubit _availability({required bool online}) => AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(
        initial: AvailabilityStatus(
          state: online ? AvailabilityState.online : AvailabilityState.offline,
          activeDeliveryCount: 0,
        ),
      ),
      tickerFactory: () => const Stream<DateTime>.empty(),
    );

Widget _home(
  AvailabilityCubit availability,
  RequestFeedCubit feed, {
  Widget? banner,
  Locale locale = const Locale('en'),
}) =>
    wrapForTest(
      BlocProvider<AvailabilityCubit>.value(
        value: availability,
        child: JeeberHomeScreen(
          requestFeedCubit: feed,
          profileName: 'Kamal',
          activeDeliveriesBanner: banner,
          onOpenFeedRequest: (_) {},
        ),
      ),
      locale: locale,
    );

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] the ON-duty empty board binds jeeber_feed_empty_state '
        'and its refresh CTA', (tester) async {
      final availability = _availability(online: true);
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.emptyFeed();
      addTearDown(feed.close);

      useReduceMotion(tester);
      await tester.pumpWidget(_home(availability, feed, locale: locale));
      await availability.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_empty_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_empty_refresh_cta'),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] the OFF-duty board binds '
        'jeeber_feed_offline_empty_state', (tester) async {
      final availability = _availability(online: false);
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.feed(
        JeeberHomeScreenPreviewFixtures.incomingFeed(),
      );
      addTearDown(feed.close);

      useReduceMotion(tester);
      // The duty-off empty body lives on the feed tab view, which the screen
      // only mounts once the board is non-empty.
      await tester.pumpWidget(
        wrapForTest(
          Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<AvailabilityCubit>.value(value: availability),
                BlocProvider<RequestFeedCubit>.value(value: feed),
              ],
              child: const JeeberFeedTabView(profileName: 'Kamal'),
            ),
          ),
          locale: locale,
        ),
      );
      await availability.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_offline_empty_state'),
        findsOneWidget,
      );
      expect(find.byKey(JeeberFeedTabView.offlineBannerKey), findsOneWidget);
    });

    testWidgets('[$tag] the availability failure binds '
        'jeeber_home_load_error_retry_cta', (tester) async {
      final availability = AvailabilityCubit(
        gateway: const FailingAvailabilityGateway(NetworkFailure()),
        tickerFactory: () => const Stream<DateTime>.empty(),
      );
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.emptyFeed();
      addTearDown(feed.close);

      useReduceMotion(tester);
      await tester.pumpWidget(_home(availability, feed, locale: locale));
      await availability.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_home_load_error_retry_cta'),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] a won order binds jeeber_active_deliveries_section',
        (tester) async {
      final availability = _availability(online: true);
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.emptyFeed();
      addTearDown(feed.close);

      useReduceMotion(tester);
      await tester.pumpWidget(
        _home(
          availability,
          feed,
          banner: JeeberActiveDeliveriesBanner(
            repository: JeeberHomeScreenPreviewFixtures.wonOrders(),
            onOpenChat: (_) {},
          ),
          locale: locale,
        ),
      );
      await availability.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_active_deliveries_section'),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] a FAILED accepted read binds the banner failure ids '
        '(OFF-08)', (tester) async {
      final availability = _availability(online: true);
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.emptyFeed();
      addTearDown(feed.close);

      useReduceMotion(tester);
      await tester.pumpWidget(
        _home(
          availability,
          feed,
          banner: const JeeberActiveDeliveriesBanner(
            repository: FailingAcceptedConversationsRepository(
              NetworkFailure(),
            ),
          ),
          locale: locale,
        ),
      );
      await availability.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_active_deliveries_banner_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(
          'jeeber_active_deliveries_banner_retry_cta',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_active_deliveries_section'),
        findsNothing,
      );
    });
  }
}

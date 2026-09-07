// ES-05: "no rows at all" and "your filter hid them" are two screens, and the
// second one needs a way out.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

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
  Locale locale = const Locale('en'),
}) =>
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
    );

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a filter that matches nothing draws the FILTERED '
        'empty and a clear-filters way out', (tester) async {
      final availability = _onlineAvailability();
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.feed(
        JeeberHomeScreenPreviewFixtures.filteredEmptyFeed(),
      );
      addTearDown(feed.close);

      useReduceMotion(tester);
      await tester.pumpWidget(_host(availability, feed, locale: locale));
      await availability.load();
      await tester.pumpAndSettle();

      // A search query no row can match, applied through the real sheet.
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

      expect(
        find.bySemanticsIdentifier('jeeber_feed_filtered_empty_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_clear_filters_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_empty_state'),
        findsNothing,
        reason: 'a filtered board is not an empty board',
      );

      final clear = find.bySemanticsIdentifier('jeeber_feed_clear_filters_cta');
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_filtered_empty_state'),
        findsNothing,
        reason: 'clearing the filter must bring the rows back',
      );
      expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);
    });

    testWidgets('[$tag] with NO rows at all the UNFILTERED empty renders',
        (tester) async {
      final availability = _onlineAvailability();
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.emptyFeed();
      addTearDown(feed.close);

      useReduceMotion(tester);
      await tester.pumpWidget(_host(availability, feed, locale: locale));
      await availability.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_empty_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_feed_filtered_empty_state'),
        findsNothing,
      );
    });
  }
}

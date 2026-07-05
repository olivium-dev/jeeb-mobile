// JEBV4-13 P2-6: the jeeber empty-feed state promises "Pull down to refresh"
// (requestFeedEmptySubtitle) but the online/empty variant was never wrapped in
// a refresh indicator — pulling fired NO feed GET (wave-1 J3). This suite
// drives the REAL pull gesture on the empty state and asserts the repository
// refresh (the feed GET) actually fires.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// Empty-snapshot repository that counts [refresh] calls so the test can
/// assert the pull gesture reached the data layer (the "feed GET").
class _CountingEmptyFeedRepository implements RequestFeedRepository {
  int refreshCalls = 0;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async {
    refreshCalls++;
    return const <DeliveryRequest>[];
  }

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}

Widget _host({
  required AvailabilityCubit availability,
  required RequestFeedCubit feed,
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
    home: BlocProvider<AvailabilityCubit>.value(
      value: availability,
      child: JeeberHomeScreen(requestFeedCubit: feed),
    ),
  );
}

void main() {
  testWidgets(
      'JEBV4-13 P2-6: pull-to-refresh on the ONLINE empty feed fires a real '
      'feed refresh (was a visual no-op)', (tester) async {
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

    final repository = _CountingEmptyFeedRepository();
    final feed = RequestFeedCubit(repository: repository);
    await feed.start();

    await tester.pumpWidget(_host(availability: availability, feed: feed));
    // Bounded pumps (not pumpAndSettle): the availability surface hosts
    // continuously repainting chrome in some states; a settle wait can hang.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Online + zero requests → the empty state whose copy says "Pull down to
    // refresh" is on screen; start() already pulled the initial snapshot.
    expect(find.byKey(JeeberNoRequestsView.rootKey), findsOneWidget);
    final callsBeforePull = repository.refreshCalls;
    expect(callsBeforePull, greaterThanOrEqualTo(1));

    // Drive the REAL pull gesture (not a direct cubit call).
    await tester.fling(
      find.byKey(JeeberNoRequestsView.rootKey),
      const Offset(0, 300),
      1000,
    );
    await tester.pump(); // start the indicator animation
    await tester.pump(const Duration(seconds: 1)); // run onRefresh
    // Let the indicator retract with bounded pumps (see note above).
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(
      repository.refreshCalls,
      callsBeforePull + 1,
      reason: 'the pull gesture must fire exactly one feed refresh '
          '(previously zero — the empty variant was unwired)',
    );

    // Close in-body: the cubit owns a periodic sweep Timer which must be
    // cancelled before the framework's pending-timer invariant runs. Run it
    // under real async (runAsync) — the transport async* generator's cancel
    // future does not resolve inside the fake-async test zone.
    await tester.runAsync(feed.close);
    await tester.pump(const Duration(seconds: 1));
  });
}

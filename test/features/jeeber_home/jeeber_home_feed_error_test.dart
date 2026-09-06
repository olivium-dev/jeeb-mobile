// JHOME-01 / LR-12: the jeeber dashboard must show a feed OUTAGE as an
// outage, never as "quiet street — you're online".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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
      BlocProvider<AvailabilityCubit>.value(
        value: availability,
        child: JeeberHomeScreen(
          requestFeedCubit: feed,
          profileName: 'Kamal',
          onOpenFeedRequest: (_) {},
        ),
      ),
      locale: locale,
    );

Future<void> _pumpHome(
  WidgetTester tester,
  AvailabilityCubit availability,
  RequestFeedCubit feed, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(_host(availability, feed, locale: locale));
  await availability.load();
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a COLD feed failure owns the body, before any empty '
        'block', (tester) async {
      final availability = _onlineAvailability();
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.failedFeed(
        const ServerFailure(status: 503),
      );
      addTearDown(feed.close);

      await _pumpHome(tester, availability, feed, locale: locale);

      expect(
        find.bySemanticsIdentifier('jeeber_home_feed_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_home_feed_retry_cta'),
        findsOneWidget,
      );
      // The lie this fix exists to kill.
      expect(find.bySemanticsIdentifier('jeeber_feed_empty_state'), findsNothing);
    });

    testWidgets('[$tag] a WARM feed failure keeps the rows and raises the '
        'refresh-failed note', (tester) async {
      final availability = _onlineAvailability();
      addTearDown(availability.close);
      final feed = JeeberHomeScreenPreviewFixtures.refreshFailedFeed(
        JeeberHomeScreenPreviewFixtures.incomingFeed(),
        const NetworkFailure(offline: true),
      );
      addTearDown(feed.close);

      await _pumpHome(tester, availability, feed, locale: locale);

      expect(
        find.bySemanticsIdentifier('jeeber_feed_refresh_failed_note'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_home_feed_error'),
        findsNothing,
        reason: 'a warm failure must never throw the rows away',
      );
    });
  }

  testWidgets('the retry CTA re-reads the feed', (tester) async {
    final availability = _onlineAvailability();
    addTearDown(availability.close);
    final repo = _CountingFailingRepository(const NetworkFailure());
    final feed = RequestFeedCubit(repository: repo);
    addTearDown(feed.close);

    useReduceMotion(tester);
    await tester.pumpWidget(_host(availability, feed));
    await availability.load();
    await feed.refresh();
    await tester.pumpAndSettle();

    expect(repo.reads, 1);
    await tester.tap(
      find.bySemanticsIdentifier('jeeber_home_feed_retry_cta'),
    );
    await tester.pumpAndSettle();

    expect(repo.reads, 2, reason: 'the retry must re-read the feed');
  });

  testWidgets('the availability cold read is its OWN loading headline, not '
      'the feed empty title (ES-08)', (tester) async {
    final availability = AvailabilityCubit(
      gateway: const _StalledGateway(),
      tickerFactory: () => const Stream<DateTime>.empty(),
    );
    addTearDown(availability.close);
    final feed = JeeberHomeScreenPreviewFixtures.emptyFeed();
    addTearDown(feed.close);

    useReduceMotion(tester);
    await tester.pumpWidget(_host(availability, feed));
    unawaited(availability.load());
    await tester.pump();

    expect(find.bySemanticsIdentifier('jeeber_home_loading'), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.bySemanticsIdentifier('jeeber_home_loading')),
    );
    expect(find.text(l10n.availabilityLoadingHeadline), findsOneWidget);
    expect(find.text(l10n.requestFeedEmptyTitle), findsNothing);
  });
}

class _CountingFailingRepository implements RequestFeedRepository {
  _CountingFailingRepository(this.failure);

  final AppFailure failure;
  int reads = 0;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport =>
      const Stream<FeedTransportUpdate>.empty();

  @override
  Future<List<DeliveryRequest>> refresh() async {
    reads++;
    throw failure;
  }

  @override
  Future<RequestActionOutcome> accept(String id) async => throw failure;

  @override
  Future<RequestActionOutcome> decline(String id) async => throw failure;

  @override
  Future<void> dispose() async {}
}

class _StalledGateway implements AvailabilityGateway {
  const _StalledGateway();

  @override
  Future<AvailabilityStatus> fetch() => Completer<AvailabilityStatus>().future;

  @override
  Future<AvailabilityToggleResult> toggle({required bool goOnline}) =>
      Completer<AvailabilityToggleResult>().future;

  @override
  Future<GoOnlineLocationOutcome> refreshLocation() =>
      Completer<GoOnlineLocationOutcome>().future;
}

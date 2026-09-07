import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThenSucceeds implements CustomerProfileRepository {
  int reads = 0;
  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (++reads == 1) throw const NetworkFailure(offline: true);
    return const CustomerProfileViewData(name: 'Karim TestJeeber');
  }
}

class _CountingFeed implements RequestFeedRepository {
  _CountingFeed(this.failRefresh);
  final bool failRefresh;
  int reads = 0;
  @override
  Stream<DeliveryRequest> get requests => const Stream.empty();
  @override
  Stream<FeedTransportUpdate> get transport => const Stream.empty();
  @override
  Future<List<DeliveryRequest>> refresh() async {
    if (++reads > 1 && failRefresh) throw const NetworkFailure();
    return [];
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

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final duty in [AvailabilityState.offline, AvailabilityState.online]) {
      for (final hasGreeting in [true, false]) {
        for (final failRefresh in [true, false]) {
          testWidgets('${locale.languageCode}: no-requests pull $duty '
              'greeting=$hasGreeting failure=$failRefresh', (tester) async {
            useReduceMotion(tester);
            final semantics = tester.ensureSemantics();
            try {
              final availability = AvailabilityCubit(
                gateway: InMemoryAvailabilityGateway(
                  initial: AvailabilityStatus(
                    state: duty,
                    activeDeliveryCount: 1,
                  ),
                ),
                tickerFactory: () => const Stream<DateTime>.empty(),
              );
              addTearDown(availability.close);
              final feedRepo = _CountingFeed(failRefresh);
              final feed = RequestFeedCubit(repository: feedRepo);
              addTearDown(feed.close);
              await feed.refresh();
              final profileRepo = _ThenSucceeds();
              final greeting = GreetingProfileCubit(repository: profileRepo);
              addTearDown(greeting.close);
              if (hasGreeting) await greeting.load();
              Widget child = BlocProvider<AvailabilityCubit>.value(
                value: availability,
                child: JeeberHomeScreen(
                  requestFeedCubit: feed,
                  activeDeliveriesBanner: Semantics(
                    identifier: 'test_active_deliveries',
                    child: const Text('Active delivery'),
                  ),
                ),
              );
              if (hasGreeting) {
                child = BlocProvider<GreetingProfileCubit>.value(
                  value: greeting,
                  child: child,
                );
              }
              await tester.pumpWidget(wrapForTest(child, locale: locale));
              await availability.load();
              await tester.pumpAndSettle();
              expect(
                find.bySemanticsIdentifier('jeeber_feed_empty_state'),
                findsOneWidget,
              );
              if (duty == AvailabilityState.offline) {
                final l10n = AppLocalizations.of(
                  tester.element(find.byType(JeeberHomeScreen)),
                );
                expect(
                  find.text(l10n.jeeberFeedDutyOffEmptyHeadline),
                  findsOneWidget,
                );
                expect(
                  find.text(l10n.jeeberFeedDutyOffEmptyBody),
                  findsOneWidget,
                );
                expect(
                  find.bySemanticsIdentifier('jeeber_feed_offline_empty_state'),
                  findsNothing,
                );
              }
              await tester.drag(
                find.byType(CustomScrollView).first,
                const Offset(0, 500),
              );
              await tester.pumpAndSettle();
              expect(feedRepo.reads, 2);
              expect(profileRepo.reads, hasGreeting ? 2 : 0);
              if (hasGreeting) {
                expect(greeting.state.status, GreetingProfileStatus.resolved);
                expect(greeting.state.name, 'Karim TestJeeber');
              }
              expect(availability.state.status.state, duty);
              expect(
                find.bySemanticsIdentifier('availability_switch'),
                findsOneWidget,
              );
              expect(
                find.bySemanticsIdentifier('test_active_deliveries'),
                findsOneWidget,
              );
              if (duty == AvailabilityState.online && failRefresh) {
                expect(
                  find.bySemanticsIdentifier('jeeber_home_feed_error'),
                  findsOneWidget,
                );
                expect(
                  find.bySemanticsIdentifier('jeeber_feed_empty_state'),
                  findsNothing,
                );
              }
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          });
        }
      }
    }
  }
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final hasGreeting in [true, false]) {
      testWidgets('${locale.languageCode}: dashboard retry with greeting '
          'provider=$hasGreeting', (tester) async {
        useReduceMotion(tester);
        final availability = AvailabilityCubit(
          gateway: const FailingAvailabilityGateway(
            NetworkFailure(offline: true),
          ),
          tickerFactory: () => const Stream<DateTime>.empty(),
        );
        addTearDown(availability.close);
        final repo = _ThenSucceeds();
        final greeting = GreetingProfileCubit(repository: repo);
        addTearDown(greeting.close);
        if (hasGreeting) await greeting.load();
        Widget child = BlocProvider<AvailabilityCubit>.value(
          value: availability,
          child: const JeeberHomeScreen(),
        );
        if (hasGreeting) {
          child = BlocProvider<GreetingProfileCubit>.value(
            value: greeting,
            child: child,
          );
        }
        await tester.pumpWidget(wrapForTest(child, locale: locale));
        await availability.load();
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier('jeeber_home_load_error_retry_cta'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (hasGreeting) {
          expect(repo.reads, 2);
          expect(greeting.state.status, GreetingProfileStatus.resolved);
          expect(greeting.state.name, 'Karim TestJeeber');
        } else {
          expect(repo.reads, 0);
        }
      });
    }
  }
}

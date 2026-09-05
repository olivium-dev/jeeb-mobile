// OFF-16 / COPY-06: "offline" belongs to connectivity. A jeeber who switched
// themselves off is OFF DUTY, and the copy must say so in both locales.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] the duty-off banner and empty body speak DUTY, never '
        'connectivity', (tester) async {
      // Cold start resolves OFFLINE — the jeeber's own switch, not the network.
      final availability = AvailabilityCubit(
        gateway: InMemoryAvailabilityGateway(),
        tickerFactory: () => const Stream<DateTime>.empty(),
      );
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
              child: const JeeberFeedTabView(profileName: 'Kamal'),
            ),
          ),
          locale: locale,
        ),
      );
      await availability.load();
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(JeeberFeedTabView)),
      );

      expect(
        find.bySemanticsIdentifier('jeeber_feed_offline_empty_state'),
        findsOneWidget,
      );
      expect(find.text(l10n.availabilityDutyOffTitle), findsWidgets);
      expect(find.text(l10n.availabilityDutyOffSubtitle), findsWidgets);

      // The connectivity vocabulary is gone from the banner and the body.
      // (`availabilityStatusOffline` shares the AR string of the retired
      // banner key, so the assertion is scoped to these two nodes.)
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier('jeeber_feed_offline_empty_state'),
          matching: find.text(l10n.jeeberFeedOfflineBannerSubtitle),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(JeeberFeedTabView.offlineBannerKey),
          matching: find.text(l10n.jeeberFeedOfflineBannerSubtitle),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });
  }
}

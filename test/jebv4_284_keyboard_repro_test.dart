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
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

DeliveryRequest _req(String id) => DeliveryRequest(
  id: id,
  pickup: const RequestLocation(
    label: 'Pickup',
    latitude: 33.8,
    longitude: 35.5,
  ),
  dropoff: const RequestLocation(
    label: 'Dropoff',
    latitude: 33.9,
    longitude: 35.6,
  ),
  tier: JeeberRequestTier.flash,
  estimatedDistanceKm: 1.2,
  potentialEarnings: 5.0,
  currency: 'USD',
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
  feedStatus: JeeberFeedItemStatus.incoming,
);

/// Directly squeezes [JeeberFeedTabView] into a shorter-than-natural-content
/// box, the way the keyboard used to when the feed still owned a search field.
/// The field has since moved into a modal sheet, but short viewports and large
/// text squeeze the same way — the sliver flattening is what absorbs it.
Future<void> _pumpSqueezed(WidgetTester tester, double height) async {
  final ticker = StreamController<DateTime>.broadcast();
  addTearDown(ticker.close);
  final avCubit = AvailabilityCubit(
    gateway: InMemoryAvailabilityGateway(
      initial: AvailabilityStatus.initial.copyWith(
        state: AvailabilityState.online,
      ),
    ),
    tickerFactory: () => ticker.stream,
  );
  addTearDown(avCubit.close);
  final feedCubit = RequestFeedCubit(
    repository: SeededRequestFeedRepository([_req('r1'), _req('r2')]),
  );
  addTearDown(feedCubit.close);
  await avCubit.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 360,
            height: height,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AvailabilityCubit>.value(value: avCubit),
                BlocProvider<RequestFeedCubit>.value(value: feedCubit),
              ],
              child: const JeeberFeedTabView(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await feedCubit.refresh();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'JEBV4-284: JeeberFeedTabView squeezed below its header-stack height '
    'does not RenderFlex-overflow',
    (tester) async {
      // 220px is comfortably below the natural height of greeting +
      // availability card + stage strip + the first card.
      await _pumpSqueezed(tester, 220);

      expect(tester.takeException(), isNull);
      // The board still renders its whole chrome inside the squeeze; the
      // CustomScrollView absorbs the deficit instead of overflowing.
      expect(find.byKey(JeeberFeedTabView.tabStripKey), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_feed_filter_open'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the search field no longer rides the squeezed page — it is a facet of '
    'the modal sheet, which owns its own viewport',
    (tester) async {
      await _pumpSqueezed(tester, 220);

      expect(
        find.byKey(JeeberFeedTabView.searchBarKey, skipOffstage: false),
        findsNothing,
      );

      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_open'));
      await tester.pumpAndSettle();

      expect(find.byKey(JeeberFeedTabView.searchBarKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the applied-filter pill row does not reintroduce the overflow',
    (tester) async {
      await _pumpSqueezed(tester, 220);

      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_open'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_tier_chip_1'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_apply'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_feed_filter_pill_tier'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

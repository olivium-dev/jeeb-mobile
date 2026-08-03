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
      pickup: const RequestLocation(label: 'Pickup', latitude: 33.8, longitude: 35.5),
      dropoff: const RequestLocation(label: 'Dropoff', latitude: 33.9, longitude: 35.6),
      tier: JeeberRequestTier.flash,
      estimatedDistanceKm: 1.2,
      potentialEarnings: 5.0,
      currency: 'USD',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      feedStatus: JeeberFeedItemStatus.incoming,
    );

/// Directly squeezes [JeeberFeedTabView] into a shorter-than-natural-content
/// box the way a keyboard opening on the search field does (Scaffold shrinks
/// the available body height) — a fixed [SizedBox] is a more direct, less
/// confound-prone repro than round-tripping through MediaQuery.viewInsets.
Future<void> _pumpSqueezed(WidgetTester tester, double height) async {
  final ticker = StreamController<DateTime>.broadcast();
  addTearDown(ticker.close);
  final avCubit = AvailabilityCubit(
    gateway: InMemoryAvailabilityGateway(
      initial: AvailabilityStatus.initial.copyWith(state: AvailabilityState.online),
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
    '(keyboard-open equivalent) does not RenderFlex-overflow',
    (tester) async {
      // 220px is comfortably below the natural height of greeting +
      // availability card + search bar + tab/tier strips alone (the fixed
      // header stack) — the exact squeeze a focused search field's keyboard
      // produces on SM-S921B (run-26: "BOTTOM OVERFLOWED BY 100 PIXELS").
      await _pumpSqueezed(tester, 220);

      // C8 (redesign-2026-08): the search field is collapsed behind the
      // magnifier at rest, so the keyboard-open state this test reproduces is
      // reachable only after the toggle — expanding it restores the exact
      // header stack the repro is about (greeting + strip + search + chips).
      await tester.tap(
        find.bySemanticsIdentifier('jeeber_feed_search_toggle'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // No RenderFlex overflow reported.
      expect(tester.takeException(), isNull);
      // The search bar is still mounted (built, no error) even though it may
      // now sit below the fold — a scrollable body degrades to "scroll to see
      // it", never to an overflow. `skipOffstage: false` is required here
      // because the finder's default offstage-culling treats sliver content
      // outside the current viewport as offstage, which is the expected,
      // desired outcome of the fix (scroll instead of overflow), not absence.
      expect(
        find.byKey(JeeberFeedTabView.searchBarKey, skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}

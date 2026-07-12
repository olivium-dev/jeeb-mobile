// Fix 6 — jeeber dashboard active-delivery overflow regression guards.
//
// Two overflows were observed on SM-S921B (Fable 5 visual findings):
//   (a) the card action Row ("Open chat" + "Manage delivery") right-overflowed
//       by 39px — the two OMDS buttons carry non-ellipsizing labels, so an
//       Expanded box narrower than the icon+label intrinsic width clipped.
//   (b) the no-requests surface bottom-overflowed (45px / 477px) — the banner's
//       unbounded Column of cards sat as a fixed child above an Expanded view,
//       pushing the Column past the viewport.
//
// Both are exercised at a narrow 360x640 surface; the test fails if any
// RenderFlex overflow (or other) exception is thrown while laying out.
//
// JEBV4-286 — a THIRD, distinct right-overflow (27px) was found on S908B
// (run-26): that device's card content width sits *above* the side-by-side
// threshold (so the two-Expanded Row is chosen instead of the stacked
// Column), but the per-button slot is still narrower than "Manage
// delivery"'s intrinsic icon+label width. Bumping the threshold only moves
// the breakpoint to the next device, so the fix instead makes the button
// label itself `Flexible` + ellipsizing (see `_ButtonLabel` in
// active_deliveries_banner.dart). Exercised below at a 384-wide surface
// (S908B's approximate logical width) in both LTR and RTL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _FakeActiveDeliveriesRepo implements ActiveDeliveriesRepository {
  _FakeActiveDeliveriesRepo(this._result);
  final List<ActiveDeliverySummary> _result;
  @override
  Future<List<ActiveDeliverySummary>> listActive() async => _result;
}

/// A few active deliveries with long titles/addresses — enough to make the
/// unbounded banner Column exceed a short viewport (reproduces overflow (b)) and
/// each card's action Row narrow (reproduces overflow (a)).
List<ActiveDeliverySummary> _deliveries(int n) => List.generate(
      n,
      (i) => ActiveDeliverySummary(
        id: 'req-$i',
        status: JeeberDeliveryStatus.inTransit,
        conversationId: 'conv-$i',
        title: 'Flash delivery request with a rather long title #$i',
        dropoffAddress: 'Building 12, Rue Verdun, Achrafieh, Beirut, Lebanon',
      ),
    );

Widget _host({
  required AvailabilityCubit availability,
  required ActiveDeliveriesCubit deliveries,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AvailabilityCubit>.value(value: availability),
        BlocProvider<ActiveDeliveriesCubit>.value(value: deliveries),
      ],
      child: JeeberHomeScreen(
        activeDeliveriesBanner: ActiveDeliveriesBanner(
          onOpenChat: (_) {},
          onManageDelivery: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'jeeber dashboard active-delivery cards do not overflow on a narrow '
    '360x640 surface (action Row + card list)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final availability = AvailabilityCubit(
        gateway: InMemoryAvailabilityGateway(),
        tickerFactory: () => ticker.stream,
      );
      addTearDown(availability.close);

      final deliveries = ActiveDeliveriesCubit(
        repository: _FakeActiveDeliveriesRepo(_deliveries(3)),
      )..start();

      await tester.pumpWidget(
        _host(availability: availability, deliveries: deliveries),
      );
      // Drain the async load + the `loaded` emission (no pumpAndSettle — the
      // cubit's 10s poll Timer would otherwise trip the pending-timer invariant).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The banner rendered its cards (deliveries loaded).
      expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
      // No RenderFlex overflow (or any) exception was thrown during layout.
      expect(tester.takeException(), isNull);

      // Cancel the poll Timer before the binding's pending-timer invariant runs.
      await deliveries.close();
    },
  );

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'jeeber active-delivery card actions do not right-overflow on a '
      'S908B-width (384) surface in ${locale.languageCode}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(384, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final ticker = StreamController<DateTime>.broadcast();
        addTearDown(ticker.close);
        final availability = AvailabilityCubit(
          gateway: InMemoryAvailabilityGateway(),
          tickerFactory: () => ticker.stream,
        );
        addTearDown(availability.close);

        final deliveries = ActiveDeliveriesCubit(
          repository: _FakeActiveDeliveriesRepo(_deliveries(1)),
        )..start();

        await tester.pumpWidget(
          _host(
            availability: availability,
            deliveries: deliveries,
            locale: locale,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
        // JEBV4-286 regression guard: no RenderFlex overflow at this width.
        expect(tester.takeException(), isNull);

        await deliveries.close();
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _StaticRepo implements ActiveDeliveriesRepository {
  const _StaticRepo(this.result);

  final List<ActiveDeliverySummary> result;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => result;
}

/// `n` distinct active deliveries, ids 'd0'..'d(n-1)', titles 'Delivery 0'..,
List<ActiveDeliverySummary> _deliveries(int n) => List.generate(
  n,
  (i) => ActiveDeliverySummary(
    id: 'd$i',
    status: JeeberDeliveryStatus.ordered,
    conversationId: 'conv-$i',
    title: 'Delivery $i',
    dropoffAddress: 'Dropoff $i',
  ),
  growable: false,
);

Widget _host({
  required ActiveDeliveriesCubit deliveries,
  required void Function(ActiveDeliverySummary) onOpenChat,
  required void Function(ActiveDeliverySummary) onManageDelivery,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: BlocProvider<ActiveDeliveriesCubit>.value(
        value: deliveries,
        child: ActiveDeliveriesBanner(
          onOpenChat: onOpenChat,
          onManageDelivery: onManageDelivery,
        ),
      ),
    ),
  );
}

/// OMDS cards inside the banner (one per rendered delivery row).
Finder get _bannerCards => find.descendant(
  of: find.byType(ActiveDeliveriesBanner),
  matching: find.byType(OMDSGlassCard),
);

void main() {
  const surface = Size(360, 1400);

  Future<ActiveDeliveriesCubit> pump(
    WidgetTester tester,
    int count, {
    List<String>? opened,
    List<String>? managed,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cubit = ActiveDeliveriesCubit(
      repository: _StaticRepo(_deliveries(count)),
    )..start();

    await tester.pumpWidget(
      _host(
        deliveries: cubit,
        onOpenChat: (d) => opened?.add(d.id),
        onManageDelivery: (d) => managed?.add(d.id),
      ),
    );
    await tester.pump(); // repo future resolves
    await tester.pump(const Duration(milliseconds: 50)); // loaded emission
    return cubit;
  }

  testWidgets('collapsed banner is one summary row with no delivery cards', (
    tester,
  ) async {
    final cubit = await pump(tester, 4);

    expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
    expect(_bannerCards, findsNothing);
    expect(find.text('Your active deliveries'), findsOneWidget);
    expect(find.text('Delivery 0'), findsNothing);
    expect(find.text('Delivery 1'), findsNothing);
    expect(find.text('Delivery 2'), findsNothing);
    expect(find.text('Delivery 3'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.text('View all (4)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await cubit.close();
  });

  testWidgets('"view all" reveals the rest in place; "show less" folds back', (
    tester,
  ) async {
    final cubit = await pump(tester, 4);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();

    expect(_bannerCards, findsNWidgets(4));
    expect(find.text('Delivery 2'), findsOneWidget);
    expect(find.text('Delivery 3'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pump();
    expect(_bannerCards, findsNothing);
    expect(find.text('Delivery 0'), findsNothing);
    expect(find.text('Delivery 3'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(tester.takeException(), isNull);

    await cubit.close();
  });

  testWidgets(
    'onOpenChat / onManageDelivery fire for cards revealed by "view all"',
    (tester) async {
      final opened = <String>[];
      final managed = <String>[];
      final cubit = await pump(tester, 4, opened: opened, managed: managed);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      await tester.tap(find.text('Delivery 0'));
      await tester.pump();
      expect(opened, ['d0']);

      await tester.tap(find.byIcon(Icons.local_shipping_outlined).first);
      await tester.pump();
      expect(managed, ['d0']);

      await tester.tap(find.text('Delivery 3'));
      await tester.pump();
      expect(opened, ['d0', 'd3']);
      expect(tester.takeException(), isNull);

      await cubit.close();
    },
  );

  testWidgets(
    'exactly 2 deliveries are also compact until explicitly expanded',
    (tester) async {
      final cubit = await pump(tester, 2);

      expect(_bannerCards, findsNothing);
      expect(find.text('Delivery 0'), findsNothing);
      expect(find.text('Delivery 1'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('View all (2)'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(tester.takeException(), isNull);

      await cubit.close();
    },
  );

  testWidgets(
    'an empty active-deliveries list collapses the banner to nothing',
    (tester) async {
      final cubit = await pump(tester, 0);

      expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
      expect(_bannerCards, findsNothing);
      expect(find.text('Your active deliveries'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(tester.takeException(), isNull);

      await cubit.close();
    },
  );
}

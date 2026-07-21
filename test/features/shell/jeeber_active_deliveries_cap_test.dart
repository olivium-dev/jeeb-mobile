// UI-cap regression proof for the jeeber active-deliveries banner.
//
// Before this cap the banner rendered EVERY active delivery as a full card in
// an unbounded Column. A jeeber juggling 4 concurrent orders got 4 tall cards
// stacked above the pending-request feed, pushing the feed a whole screen down
// on a 360x800 viewport (the feed rides its own sliver below the banner, so it
// was reachable only by a long scroll). The banner now shows at most 2 cards at
// rest and discloses the rest in place via a "view all (N)" toggle.
//
// These tests pin that contract directly on [ActiveDeliveriesBanner]:
//   * at most 2 cards render collapsed (the 3rd/4th are not even built),
//   * the "view all" toggle reveals the rest in place (and "show less" folds),
//   * onOpenChat / onManageDelivery still fire for both the always-shown and the
//     newly-revealed cards,
//   * with <= 2 deliveries there is no toggle (nothing to reveal),
//   * an empty active-deliveries list still collapses the banner to nothing.

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
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _StaticRepo implements ActiveDeliveriesRepository {
  const _StaticRepo(this.result);

  final List<ActiveDeliverySummary> result;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => result;
}

/// `n` distinct active deliveries, ids 'd0'..'d(n-1)', titles 'Delivery 0'..,
/// so each card's title is individually findable and the cards stay unique.
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

/// Cards inside the banner (one [Card] per rendered delivery row).
Finder get _bannerCards => find.descendant(
      of: find.byType(ActiveDeliveriesBanner),
      matching: find.byType(Card),
    );

void main() {
  // A tall surface so the cap/reveal logic — which is height-independent (it
  // always keeps at most 2 cards until toggled) — is exercised without a
  // scroll-view host: the fully-expanded 4-card list fits, so every card is
  // on-stage and directly assertable.
  const surface = Size(360, 1400);

  Future<ActiveDeliveriesCubit> pump(
    WidgetTester tester,
    int count, {
    List<String>? opened,
    List<String>? managed,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Long poll so the fake-async timer invariant never trips mid-test; we drain
    // the single initial load with explicit pumps below.
    final cubit = ActiveDeliveriesCubit(
      repository: _StaticRepo(_deliveries(count)),
      pollInterval: const Duration(hours: 1),
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

  testWidgets('caps the collapsed banner at 2 cards + a "view all (4)" toggle', (
    tester,
  ) async {
    final cubit = await pump(tester, 4);

    expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
    // Only the first two cards render; the 3rd and 4th are not built at all.
    expect(_bannerCards, findsNWidgets(2));
    expect(find.text('Delivery 0'), findsOneWidget);
    expect(find.text('Delivery 1'), findsOneWidget);
    expect(find.text('Delivery 2'), findsNothing);
    expect(find.text('Delivery 3'), findsNothing);
    // The disclosure toggle is present and labelled with the TOTAL count.
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

    // All four cards now render; the toggle flips to "show less".
    expect(_bannerCards, findsNWidgets(4));
    expect(find.text('Delivery 2'), findsOneWidget);
    expect(find.text('Delivery 3'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);

    // Folding back returns to the 2-card cap.
    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pump();
    expect(_bannerCards, findsNWidgets(2));
    expect(find.text('Delivery 3'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(tester.takeException(), isNull);

    await cubit.close();
  });

  testWidgets(
    'onOpenChat / onManageDelivery fire for shown cards AND for cards revealed '
    'by "view all"',
    (tester) async {
      final opened = <String>[];
      final managed = <String>[];
      final cubit = await pump(tester, 4, opened: opened, managed: managed);

      // Tapping an always-shown card body opens its chat.
      await tester.tap(find.text('Delivery 0'));
      await tester.pump();
      expect(opened, ['d0']);

      // Its "Manage delivery" action fires the manage callback (first visible
      // card's manage button).
      await tester.tap(find.byIcon(Icons.local_shipping_outlined).first);
      await tester.pump();
      expect(managed, ['d0']);

      // Reveal the rest, then a newly-shown card must fire its callback too.
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      await tester.tap(find.text('Delivery 3'));
      await tester.pump();
      expect(opened, ['d0', 'd3']);
      expect(tester.takeException(), isNull);

      await cubit.close();
    },
  );

  testWidgets('with exactly 2 deliveries every card shows and there is no toggle',
      (tester) async {
    final cubit = await pump(tester, 2);

    expect(_bannerCards, findsNWidgets(2));
    expect(find.text('Delivery 0'), findsOneWidget);
    expect(find.text('Delivery 1'), findsOneWidget);
    // Nothing hidden → no disclosure control.
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(tester.takeException(), isNull);

    await cubit.close();
  });

  testWidgets('an empty active-deliveries list collapses the banner to nothing',
      (tester) async {
    final cubit = await pump(tester, 0);

    // The widget is mounted but renders SizedBox.shrink: no title, no cards,
    // no toggle — so it never disturbs the empty/feed states.
    expect(find.byType(ActiveDeliveriesBanner), findsOneWidget);
    expect(_bannerCards, findsNothing);
    expect(find.text('Your active deliveries'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(tester.takeException(), isNull);

    await cubit.close();
  });
}

// M4-35 — the order-history pagination footer, read off the widget.
//
// Goldens tolerate 5% pixel diff and this footer is ~90px of a 956px canvas, so
// every ruling below is an element assertion, never a picture.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_state.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../../support/sync_app_localizations.dart';

final List<OrderSummary> _kOrders = <OrderSummary>[
  OrderSummary(
    id: 'REQ-1042',
    createdAt: DateTime.utc(2026, 6, 20, 14, 30),
    pickupAddress: 'Hamra, Beirut',
    dropoffAddress: 'Achrafieh, Beirut',
    status: OrderRequestStatus.enRoute,
    tier: OrderTier.express,
    amountMinor: 1250,
    currency: 'USD',
  ),
  OrderSummary(
    id: 'REQ-1038',
    createdAt: DateTime.utc(2026, 6, 19, 9, 5),
    pickupAddress: 'Verdun, Beirut',
    dropoffAddress: 'Downtown, Beirut',
    status: OrderRequestStatus.matched,
    tier: OrderTier.flash,
    amountMinor: 900,
    currency: 'USD',
  ),
];

/// Page 1 lands with `hasMore`, page 2 never does.
class _PaginatingRepo implements OrderRepository {
  const _PaginatingRepo();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    if (page > 1) return Completer<OrderPage>().future;
    return OrderPage(
      items: _kOrders
          .where((OrderSummary o) => o.status.tab == tab)
          .toList(growable: false),
      page: page,
      hasMore: true,
    );
  }
}

Widget _harness(
  OrderHistoryCubit cubit, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The skeleton breathes forever by design — mount at the reduce-motion
    // rest frame (M0-4 ruling).
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: BlocProvider<OrderHistoryCubit>.value(
      value: cubit,
      child: const OrderHistoryScreen(),
    ),
  );
}

/// Mounts the screen and settles the FIRST page, leaving the tab `ready`.
///
/// The viewport is tall on purpose: a `ListView` never BUILDS an item past its
/// cache extent, and the footer is the last one.
Future<OrderHistoryCubit> _mountReady(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(440, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final OrderHistoryCubit cubit = OrderHistoryCubit(
    repository: const _PaginatingRepo(),
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(_harness(cubit, locale: locale));
  await tester.pump();
  await tester.pump();
  expect(cubit.state.currentTab.status, OrderTabStatus.ready);
  return cubit;
}

/// Asks for page 2 and settles the footer. The emit reaches `BlocBuilder`
/// through a stream, so one frame is not enough to rebuild the list.
Future<void> _requestNextPage(
  WidgetTester tester,
  OrderHistoryCubit cubit,
) async {
  unawaited(cubit.loadMore());
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Finder get _footer =>
    find.byKey(const Key('order-history-loading-more'), skipOffstage: false);

JeebEmptyState _footerState(WidgetTester tester) => tester.widget<JeebEmptyState>(
  find.descendant(
    of: _footer,
    matching: find.byType(JeebEmptyState),
    skipOffstage: false,
  ),
);

void main() {
  group('M4-35 · the next-page wait is the kit family, not an OMDS spinner', () {
    testWidgets('the footer draws the parcel skeleton at footer density',
        (WidgetTester tester) async {
      final OrderHistoryCubit cubit = await _mountReady(tester);
      await _requestNextPage(tester, cubit);

      expect(cubit.state.currentTab.status, OrderTabStatus.loadingNextPage);
      final JeebEmptyState wait = _footerState(tester);
      expect(
        wait.status,
        JeebEmptyStateStatus.loading,
        reason: 'a pagination wait is the LOADING rung of §2.7, not empty art',
      );
      expect(
        wait.variant,
        JeebEmptyStateVariant.parcel,
        reason: 'order domain — the same subject as the three page states',
      );
      expect(wait.compact, isTrue);
      expect(
        wait.illustrationSize,
        Sizes.tenXLarge,
        reason: 'the kit default (300) and compact default (150) both swallow '
            'the row above the footer',
      );
      expect(wait.identifier, 'order_history_loading_more');
    });

    testWidgets('no OMDS spinner and no bare progress ring survive anywhere',
        (WidgetTester tester) async {
      final OrderHistoryCubit cubit = await _mountReady(tester);
      await _requestNextPage(tester, cubit);

      expect(
        find.byType(OmdsLoadingState, skipOffstage: false),
        findsNothing,
        reason: 'OmdsLoadingState inks its ring colorScheme.primary, which '
            'under Midnight IS the brand orange #D73B00',
      );
      expect(
        find.byType(CircularProgressIndicator, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(LinearProgressIndicator, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('the wait announces itself instead of spinning silently',
        (WidgetTester tester) async {
      final OrderHistoryCubit cubit = await _mountReady(tester);
      await _requestNextPage(tester, cubit);

      final AppLocalizations l10n = await const SyncAppLocalizationsDelegate()
          .load(const Locale('en'));
      expect(
        _footerState(tester).headline,
        l10n.orderHistoryLoadingMore,
        reason: 'ORDH-04: the footer is a pagination wait, not a COLD load',
      );
      expect(
        find.descendant(
          of: _footer,
          matching: find.text(l10n.orderHistoryLoadingMore),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('an idle footer slot draws NO chrome — no reserved gap',
        (WidgetTester tester) async {
      await _mountReady(tester);

      expect(
        _footer,
        findsNothing,
        reason: 'the old footer padded 16/16 around a SizedBox.shrink on every '
            'ready frame, reserving a gap under the last row',
      );
      expect(find.byType(JeebEmptyState, skipOffstage: false), findsNothing);
    });

    testWidgets('the wait keeps one loading idiom on the screen',
        (WidgetTester tester) async {
      final OrderHistoryCubit cubit = await _mountReady(tester);
      await _requestNextPage(tester, cubit);

      final Iterable<JeebEmptyState> all = tester.widgetList<JeebEmptyState>(
        find.byType(JeebEmptyState, skipOffstage: false),
      );
      expect(all, isNotEmpty);
      expect(
        all.every(
          (JeebEmptyState s) => s.variant == JeebEmptyStateVariant.parcel,
        ),
        isTrue,
        reason: 'a second subject in the footer would read as a second screen',
      );
    });

    testWidgets('renders RTL without throwing', (WidgetTester tester) async {
      final OrderHistoryCubit cubit = await _mountReady(
        tester,
        locale: const Locale('ar'),
      );
      await _requestNextPage(tester, cubit);

      expect(_footerState(tester).status, JeebEmptyStateStatus.loading);
      expect(tester.takeException(), isNull);
    });
  });
}

// TEMP capture harness for M2-17 (R21 + E4). Mirrors
// `test/tools/catalog_capture_test.dart` but imports ONLY the order-history
// feature, so a sibling lane mid-edit cannot block this row's captures.
@Tags(<String>['capture'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/order_history_screen_fixtures.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../support/load_test_fonts.dart';
import '../support/sync_app_localizations.dart';

const Size _kCanvas = Size(440, 956);
const String _kOut = '../../docs/redesign-midnight/captures/M2-17-r21-e4';

OrderSummary _row(
  String id,
  OrderRequestStatus status, {
  required String pickup,
  required int? amountMinor,
  OrderTier tier = OrderTier.express,
  DateTime? createdAt,
}) => OrderSummary(
  id: id,
  createdAt: createdAt ?? DateTime.utc(2026, 6, 26, 12),
  pickupAddress: pickup,
  dropoffAddress: 'Achrafieh, Beirut',
  status: status,
  tier: tier,
  amountMinor: amountMinor,
  currency: 'USD',
);

final List<OrderSummary> _tileCast = <OrderSummary>[
  _row(
    'REQ-1042',
    OrderRequestStatus.enRoute,
    pickup: 'Pharmacie du Musée',
    amountMinor: 800,
    tier: OrderTier.flash,
    createdAt: DateTime.utc(2026, 6, 28, 14),
  ),
  _row(
    'REQ-1039',
    OrderRequestStatus.delivered,
    pickup: 'Spinneys Achrafieh',
    amountMinor: 600,
    createdAt: DateTime.utc(2026, 6, 26, 10),
  ),
  _row(
    'REQ-1035',
    OrderRequestStatus.delivered,
    pickup: 'Hamra notary',
    amountMinor: 1000,
    createdAt: DateTime.utc(2026, 6, 24, 10),
  ),
  _row(
    'REQ-1030',
    OrderRequestStatus.cancelled,
    pickup: 'Ashrafieh florist',
    amountMinor: null,
    createdAt: DateTime.utc(2026, 6, 20, 10),
  ),
];

Widget _screen(OrderRepository repository) => BlocProvider<OrderHistoryCubit>(
  create: (_) => OrderHistoryCubit(repository: repository),
  child: const OrderHistoryScreen(),
);

void main() {
  setUpAll(loadCatalogCaptureFonts);

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget screen, {
    String? tapTab,
  }) async {
    tester.view.physicalSize = _kCanvas;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final GoRouter router = GoRouter(
      initialLocation: '/capture',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(),
          routes: <RouteBase>[
            GoRoute(
              path: 'capture',
              builder: (BuildContext context, _) => Scaffold(body: screen),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      OmdsColorTokensProvider(
        tokens: jeebMidnightOmdsTokens,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: withCaptureTestFonts(AppTheme.midnight()),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object?>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    if (tapTab != null) {
      await tester.tap(find.bySemanticsIdentifier(tapTab));
      for (int f = 0; f < 6; f++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    for (int f = 0; f < 4; f++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_kOut/$name.png'),
    );
  }

  testWidgets('capture r21-active-live', (WidgetTester tester) async {
    await capture(
      tester,
      'r21-active-live',
      _screen(OrderHistoryScreenStaticOrders(_tileCast)),
    );
  });

  testWidgets('capture r21-completed-rows', (WidgetTester tester) async {
    await capture(
      tester,
      'r21-completed-rows',
      _screen(OrderHistoryScreenStaticOrders(_tileCast)),
      tapTab: 'order_history_completed_tab',
    );
  });

  testWidgets('capture r21-cancelled-expired', (WidgetTester tester) async {
    await capture(
      tester,
      'r21-cancelled-expired',
      _screen(OrderHistoryScreenStaticOrders(_tileCast)),
      tapTab: 'order_history_cancelled_tab',
    );
  });

  testWidgets('capture e4-empty-no-orders', (WidgetTester tester) async {
    await capture(
      tester,
      'e4-empty-no-orders',
      _screen(
        const OrderHistoryScreenStaticOrders(OrderHistoryScreenOrders.none),
      ),
    );
  });

  testWidgets('capture r21-loading', (WidgetTester tester) async {
    await capture(
      tester,
      'r21-loading',
      _screen(const OrderHistoryScreenStalledOrders()),
    );
  });

  testWidgets('capture r21-error', (WidgetTester tester) async {
    await capture(
      tester,
      'r21-error',
      _screen(
        const OrderHistoryScreenFailingOrders(OrderRepositoryErrorKind.server),
      ),
    );
  });
}

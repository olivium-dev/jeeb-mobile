// Regression gate for "the customer's status chip goes stale", seen on real
// hardware during the live COD run: the chip read "Pending" while the jeeber
// had already moved to Picked / InTransit.
//
// ESTABLISHED FIRST-HAND BEFORE FIXING, because the suspected cause was wrong.
// The hypothesis was that the chip sat on the push-only status axis that commit
// 134bea4 introduced. It does not. `OrderStatusChip` is the only customer-facing
// status chip in the app that can render "Pending" (`orderHistoryStatusPending`),
// it lives in `OrderHistoryCard` on the Delivery tab, and it was on NO refresh
// axis at all — a strictly worse failure than push-only:
//
//   OrderHistoryScreen.initState  -> initialLoad(), once
//   shell_screen.dart:128         -> IndexedStack keeps OrdersTab mounted, so
//                                    initState never runs again
//   OrderHistoryCubit             -> takes no refreshSignals; no push reaches it
//   grep -c 'TabVisibility|AppResumeSignals|ResumeRefetch|
//            resolvePushRefreshStream|RouteAware'
//     order_history_screen.dart / order_history_cubit.dart / orders_tab.dart
//                                 -> 0 / 0 / 0
//
// So the list held its first-seen snapshot for the life of the process.
//
// Controls this file runs, against the REAL screen, the REAL chip and the REAL
// ARBs, with a repository scripted to advance Pending -> En route between reads
// exactly as a jeeber does:
//   NEGATIVE — with the tab never regaining focus, no resume and no push, the
//              chip stays "Pending" and the repository is read exactly ONCE.
//              This is the pre-fix behaviour, reproduced rather than described.
//   POSITIVE — flipping TabVisibility false -> true re-reads and the chip
//              becomes "En route".
//   POSITIVE — an `order` push while the tab is visible re-reads.
//   BOUNDED  — a push while the tab is HIDDEN does not read (the customer is
//              not looking, and truncating a paginated list they may be
//              scrolled into is the cost); regaining focus then pays it once.
//   NO DOUBLE-MOUNT — the refetcher does not add a second read at mount;
//              `initialLoad` still owns the first one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/features/order_history/presentation/orders_resume_refetcher.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// A repository that advances the order's status on every read, the way the
/// gateway does while a jeeber works the delivery. Read N returns the Nth entry
/// of [script] (the last entry repeats).
class _AdvancingRepo implements OrderRepository {
  _AdvancingRepo(this.script);

  final List<OrderRequestStatus> script;
  int reads = 0;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    final index = reads.clamp(0, script.length - 1);
    reads++;
    return OrderPage(
      items: [_order(script[index])],
      page: page,
      hasMore: false,
    );
  }
}

OrderSummary _order(OrderRequestStatus status) => OrderSummary(
      id: 'order-cod-001',
      createdAt: DateTime.utc(2026, 7, 31, 19, 40),
      pickupAddress: 'Hamra',
      dropoffAddress: 'Achrafieh',
      status: status,
      tier: OrderTier.express,
      amountMinor: 600,
      currency: 'USD',
    );

/// Mounts the Delivery tab's real subtree: the cubit provider, the refetcher
/// under test, the real screen — inside a [TabVisibility] the test drives, so
/// the shell's IndexedStack behaviour is reproduced rather than simulated.
class _TabHost extends StatefulWidget {
  const _TabHost({
    super.key,
    required this.repo,
    required this.pushSignals,
    this.withRefetcher = true,
  });

  final OrderRepository repo;
  final Stream<void> pushSignals;
  final bool withRefetcher;

  @override
  State<_TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<_TabHost> {
  bool _visible = true;

  void setVisible(bool value) => setState(() => _visible = value);

  @override
  Widget build(BuildContext context) {
    const screen = Scaffold(body: OrderHistoryScreen());
    return BlocProvider<OrderHistoryCubit>(
      create: (_) => OrderHistoryCubit(repository: widget.repo, pageSize: 20),
      child: TabVisibility(
        isVisible: _visible,
        child: widget.withRefetcher
            ? OrdersResumeRefetcher(
                refreshSignals: widget.pushSignals,
                child: screen,
              )
            : screen,
      ),
    );
  }
}

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

Future<_TabHostState> _pump(
  WidgetTester tester, {
  required OrderRepository repo,
  required Stream<void> pushSignals,
  bool withRefetcher = true,
}) async {
  final key = GlobalKey<_TabHostState>();
  await tester.pumpWidget(
    _app(
      _TabHost(
        key: key,
        repo: repo,
        pushSignals: pushSignals,
        withRefetcher: withRefetcher,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

void main() {
  late StreamController<void> push;

  setUp(() {
    push = StreamController<void>.broadcast();
  });

  tearDown(() async {
    await push.close();
  });

  testWidgets(
      'NEGATIVE CONTROL — with no refocus, no resume and no push the chip is '
      'frozen on its first-seen value and the repo is read exactly ONCE', (
    tester,
  ) async {
    final repo = _AdvancingRepo(
      [OrderRequestStatus.pending, OrderRequestStatus.enRoute],
    );

    await _pump(tester, repo: repo, pushSignals: push.stream);

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('En route'), findsNothing);

    // Time passing changes nothing — there is no cadence, by design.
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();

    expect(repo.reads, 1, reason: 'this is the whole defect: one read, ever');
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets(
      'POSITIVE — regaining shell-tab focus re-reads and the chip advances '
      'Pending -> En route', (tester) async {
    final repo = _AdvancingRepo(
      [OrderRequestStatus.pending, OrderRequestStatus.enRoute],
    );

    final host = await _pump(tester, repo: repo, pushSignals: push.stream);
    expect(find.text('Pending'), findsOneWidget);

    // The customer switches away and comes back to check on their order.
    host.setVisible(false);
    await tester.pumpAndSettle();
    host.setVisible(true);
    await tester.pumpAndSettle();

    expect(repo.reads, 2);
    expect(
      find.text('En route'),
      findsOneWidget,
      reason: 'the chip must reflect where the jeeber actually is',
    );
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('POSITIVE — an `order` push while the tab is visible re-reads', (
    tester,
  ) async {
    final repo = _AdvancingRepo(
      [OrderRequestStatus.pending, OrderRequestStatus.pickedUp],
    );

    await _pump(tester, repo: repo, pushSignals: push.stream);
    expect(find.text('Pending'), findsOneWidget);

    push.add(null);
    await tester.pumpAndSettle();

    expect(repo.reads, 2);
    expect(find.text('Picked up'), findsOneWidget);
  });

  testWidgets(
      'BOUNDED — a push while the tab is HIDDEN issues no read; regaining '
      'focus pays the debt exactly once', (tester) async {
    final repo = _AdvancingRepo(
      [OrderRequestStatus.pending, OrderRequestStatus.enRoute],
    );

    final host = await _pump(tester, repo: repo, pushSignals: push.stream);
    host.setVisible(false);
    await tester.pumpAndSettle();

    push.add(null);
    push.add(null);
    push.add(null);
    await tester.pumpAndSettle();
    expect(repo.reads, 1, reason: 'nobody is looking at this list');

    host.setVisible(true);
    await tester.pumpAndSettle();
    expect(repo.reads, 2, reason: 'N hidden pushes cost ONE read, not N');
    expect(find.text('En route'), findsOneWidget);
  });

  testWidgets('the refetcher adds no second read at mount', (tester) async {
    final repo = _AdvancingRepo([OrderRequestStatus.pending]);

    await _pump(tester, repo: repo, pushSignals: push.stream);

    expect(
      repo.reads,
      1,
      reason: 'initialLoad still owns the first read; no double-fetch',
    );
  });

  testWidgets(
      'without the refetcher the screen behaves exactly as before (the '
      'refetcher is the whole change)', (tester) async {
    final repo = _AdvancingRepo(
      [OrderRequestStatus.pending, OrderRequestStatus.enRoute],
    );

    final host = await _pump(
      tester,
      repo: repo,
      pushSignals: push.stream,
      withRefetcher: false,
    );
    host.setVisible(false);
    await tester.pumpAndSettle();
    host.setVisible(true);
    await tester.pumpAndSettle();
    push.add(null);
    await tester.pumpAndSettle();

    expect(repo.reads, 1);
    expect(find.text('Pending'), findsOneWidget);
  });
}

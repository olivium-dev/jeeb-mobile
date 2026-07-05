import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import '../dev_screen_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME & SHELL screens — the bottom-nav host plus the three primary tab bodies.
// Each entry's states + inline fakes are ported EXACTLY from the matching
// integration_test/screens/<file>_test.dart (privatised, file-local; nothing
// imported from test/ or integration_test/). Navigation callbacks are safe
// no-ops and any poll/clock tick uses const Stream.empty() so previews carry no
// runaway timers.
// ─────────────────────────────────────────────────────────────────────────────

// ── Client Home (Requests tab) ── ported from client_home_test.dart ──────────

/// Populated snapshot mirroring the widget test's Figma mock data (screens
/// 13/14/15): one in-progress, one pending, and one replies request.
ClientHomeRepository _clientHomePopulatedRepo() {
  return InMemoryClientHomeRepository.fromSnapshot(
    const ClientHomeSnapshot(
      inProgress: [
        ClientHomeRequest(
          id: 'ip-1',
          title: 'Kamal Hajj',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.enRoute,
          tier: ClientRequestTier.flash,
          progressStep: 3,
        ),
      ],
      pending: [
        ClientHomeRequest(
          id: 'pen-1',
          title: 'ORD-23470',
          displayId: 'ORD-23470',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.searching,
          tier: ClientRequestTier.express,
        ),
      ],
      replies: [
        ClientHomeRequest(
          id: 'rep-1',
          title: 'ORD-23470',
          displayId: 'ORD-23470',
          destinationLabel: '1 kilo potato, water gallon, coffee blend',
          itemsSummary: '1 kilo potato, water gallon, coffee blend',
          status: ClientRequestStatus.offersReceived,
          tier: ClientRequestTier.express,
          offerCount: 9,
          offerAvatarUrls: ['', '', ''],
          conversationId: 'conv-rep-1',
        ),
      ],
    ),
    latency: Duration.zero,
  );
}

/// Wrap the screen in a Scaffold (its root is a Stack, not a Scaffold) and a
/// BlocProvider carrying the cubit. Callbacks are no-ops so the New Order FAB /
/// Track CTAs render.
Widget _clientHome({required ClientHomeRepository repo, String? name}) {
  return Scaffold(
    body: BlocProvider(
      create: (_) => ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => name,
      ),
      child: ClientHomeScreen(
        onCreateRequest: () {},
        onTrack: (_) {},
      ),
    ),
  );
}

// ── Order History (Delivery tab) ── ported from order_history_test.dart ──────

OrderSummary _order(String id, OrderRequestStatus status) => OrderSummary(
      id: id,
      createdAt: DateTime.utc(2026, 5, 17, 10),
      pickupAddress: 'Pickup $id',
      dropoffAddress: 'Dropoff $id',
      status: status,
      tier: OrderTier.express,
      amountMinor: 1234_00,
      currency: 'USD',
    );

/// Fake mirroring the test's `_FakeRepo`: serves the scripted page for the first
/// call per tab, then an empty terminal page.
class _FakeOrderRepo implements OrderRepository {
  _FakeOrderRepo(this._pages);

  final Map<OrderHistoryTab, List<OrderPage>> _pages;
  final Map<OrderHistoryTab, int> _calls = {};

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    final call = _calls.update(tab, (v) => v + 1, ifAbsent: () => 0);
    final list = _pages[tab] ?? const [];
    if (call >= list.length) {
      return OrderPage(items: const [], page: page, hasMore: false);
    }
    return list[call];
  }
}

/// Wrap in a Scaffold (the screen returns a Column and hosts a Material TabBar)
/// with the cubit provided.
Widget _orderHistory(OrderRepository repo) {
  final cubit = OrderHistoryCubit(repository: repo, pageSize: 2);
  return Scaffold(
    body: BlocProvider.value(
      value: cubit,
      child: const OrderHistoryScreen(),
    ),
  );
}

// ── Jeeber Home (Dashboard tab) ── ported from jeeber_home_test.dart ─────────

/// Registered path: provide the AvailabilityCubit the screen reads (its
/// didChangeDependencies calls load()). The empty ticker stream keeps the
/// preview free of pending timers.
Widget _jeeberHomeRegistered() {
  final cubit = AvailabilityCubit(
    gateway: InMemoryAvailabilityGateway(),
    tickerFactory: () => const Stream<DateTime>.empty(),
  );
  return BlocProvider<AvailabilityCubit>.value(
    value: cubit,
    child: const JeeberHomeScreen(profileName: 'Kamal'),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Entries sorted alphabetically by title.
final List<DevScreenEntry> homeShellScreens = <DevScreenEntry>[
  // Client Home (Requests tab) — cubit / fake-repo backed.
  DevScreenEntry(
    id: 'home-requests',
    title: 'Client Home (Requests tab)',
    group: 'Home & Shell',
    keywords: const <String>[
      'requests',
      'home',
      'client',
      'in progress',
      'pending',
      'replies',
      'new order',
      'track',
      'dashboard',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Populated (EN)',
        locale: const Locale('en'),
        builder: (_) => _clientHome(repo: _clientHomePopulatedRepo(), name: 'Layla'),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'Empty (EN)',
        locale: const Locale('en'),
        builder: (_) => _clientHome(
          repo: InMemoryClientHomeRepository(latency: Duration.zero),
          name: 'Layla',
        ),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Populated (AR)',
        locale: const Locale('ar'),
        builder: (_) => _clientHome(repo: _clientHomePopulatedRepo(), name: 'ليلى'),
      ),
    ],
  ),

  // Jeeber Home (Dashboard tab) — upsell + registered/offline sub-views.
  DevScreenEntry(
    id: 'jeeber-home',
    title: 'Jeeber Home (Dashboard tab)',
    group: 'Home & Shell',
    keywords: const <String>[
      'jeeber',
      'courier',
      'driver',
      'dashboard',
      'availability',
      'online',
      'offline',
      'register',
      'upsell',
      'feed',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'unregistered-en',
        label: 'Unregistered upsell (EN)',
        locale: const Locale('en'),
        builder: (_) =>
            const JeeberHomeScreen(isRegistered: false, profileName: 'Kamal'),
      ),
      DevScreenState(
        id: 'no-requests-en',
        label: 'Registered, offline / no requests (EN)',
        locale: const Locale('en'),
        builder: (_) => _jeeberHomeRegistered(),
      ),
      DevScreenState(
        id: 'no-requests-ar',
        label: 'Registered, offline / no requests (AR)',
        locale: const Locale('ar'),
        builder: (_) => _jeeberHomeRegistered(),
      ),
    ],
  ),

  // Order History (Delivery tab) — fake-repo backed, Active list + empty.
  DevScreenEntry(
    id: 'delivery-tab',
    title: 'Order History (Delivery tab)',
    group: 'Home & Shell',
    keywords: const <String>[
      'orders',
      'order history',
      'delivery',
      'active',
      'completed',
      'cancelled',
      'tabs',
      'pagination',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Populated Active list (EN)',
        locale: const Locale('en'),
        builder: (_) => _orderHistory(
          _FakeOrderRepo({
            OrderHistoryTab.active: [
              OrderPage(
                items: [
                  _order('a1', OrderRequestStatus.enRoute),
                  _order('a2', OrderRequestStatus.pickedUp),
                ],
                page: 1,
                hasMore: false,
              ),
            ],
          }),
        ),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'Empty Active tab (EN)',
        locale: const Locale('en'),
        builder: (_) => _orderHistory(_FakeOrderRepo(const {})),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Populated Active list (AR)',
        locale: const Locale('ar'),
        builder: (_) => _orderHistory(
          _FakeOrderRepo({
            OrderHistoryTab.active: [
              OrderPage(
                items: [_order('a1', OrderRequestStatus.enRoute)],
                page: 1,
                hasMore: false,
              ),
            ],
          }),
        ),
      ),
    ],
  ),

  // Shell (Bottom Nav) — the IndexedStack host; renders badge-less on Requests.
  DevScreenEntry(
    id: 'shell',
    title: 'Shell (Bottom Nav)',
    group: 'Home & Shell',
    keywords: const <String>[
      'shell',
      'bottom nav',
      'navigation',
      'tabs',
      'scaffold',
      'indexed stack',
      'chrome',
      'host',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'landing-en',
        label: 'Bottom-nav host, requests landing (EN)',
        locale: const Locale('en'),
        builder: (_) => const ShellScreen(),
      ),
      DevScreenState(
        id: 'landing-ar',
        label: 'Bottom-nav host (AR)',
        locale: const Locale('ar'),
        builder: (_) => const ShellScreen(),
      ),
    ],
  ),
];

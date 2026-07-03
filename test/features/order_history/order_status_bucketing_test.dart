// Run-22 P1-B / lane item 6 regression guard — status → bucket table.
//
// The customer "Delivery" surface (order_history: Active / Completed /
// Cancelled tabs) must classify BOTH the canonical V3 status vocabulary
// (Ordered → Picked → InTransit → AtDoor → Done) AND the legacy snake_case
// aliases, including the accepted-but-not-yet-picked state, which MUST land
// in the Active (In Progress) bucket. Before this fix the parser only knew
// the legacy lowercase names — every canonical status fell into `unknown`,
// so `Done` orders lingered under Active and the Completed/Cancelled tabs
// never matched a canonical row.
//
// (The run-22 empty-Active-bucket symptom itself was root-caused to the
// GATEWAY list endpoints returning [] post-accept — owned by the gateway
// lane. This table guarantees the client buckets correctly the moment the
// list returns data.)

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/data/dio_order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

void main() {
  group('OrderRequestStatus.parse → tab (status → bucket table)', () {
    const active = OrderHistoryTab.active;
    const completed = OrderHistoryTab.completed;
    const cancelled = OrderHistoryTab.cancelled;

    const table = <String, (OrderRequestStatus, OrderHistoryTab)>{
      // Canonical V3 vocabulary (SM-1 Ordered → Picked → InTransit → AtDoor
      // → Done) — all pre-terminal states are Active.
      'Ordered': (OrderRequestStatus.matched, active),
      'Picked': (OrderRequestStatus.pickedUp, active),
      'InTransit': (OrderRequestStatus.enRoute, active),
      'AtDoor': (OrderRequestStatus.enRoute, active),
      'Done': (OrderRequestStatus.delivered, completed),
      // Accepted-pre-pickup (offer accepted, no shipment on the road yet) —
      // the run-22 P1-B state. MUST be Active/In Progress.
      'accepted': (OrderRequestStatus.matched, active),
      'ACCEPTED': (OrderRequestStatus.matched, active),
      'assigned': (OrderRequestStatus.matched, active),
      // Legacy snake_case aliases.
      'pending': (OrderRequestStatus.pending, active),
      'matched': (OrderRequestStatus.matched, active),
      'picked_up': (OrderRequestStatus.pickedUp, active),
      'en_route': (OrderRequestStatus.enRoute, active),
      'in_transit': (OrderRequestStatus.enRoute, active),
      'heading_off': (OrderRequestStatus.enRoute, active),
      'delivered': (OrderRequestStatus.delivered, completed),
      'completed': (OrderRequestStatus.delivered, completed),
      'rated': (OrderRequestStatus.delivered, completed),
      'cancelled': (OrderRequestStatus.cancelled, cancelled),
      'canceled': (OrderRequestStatus.cancelled, cancelled),
      'expired': (OrderRequestStatus.cancelled, cancelled),
      'disputed': (OrderRequestStatus.disputed, cancelled),
      // Unknown / future states stay VISIBLE on Active (never silently lost).
      'teleporting': (OrderRequestStatus.unknown, active),
      '': (OrderRequestStatus.unknown, active),
    };

    for (final entry in table.entries) {
      final (status, tab) = entry.value;
      test('"${entry.key}" → $status → ${tab.name}', () {
        final parsed = OrderRequestStatus.parse(entry.key);
        expect(parsed, status);
        expect(parsed.tab, tab);
      });
    }

    test('null → unknown → active (visible, not dropped)', () {
      expect(OrderRequestStatus.parse(null), OrderRequestStatus.unknown);
      expect(OrderRequestStatus.parse(null).tab, OrderHistoryTab.active);
    });
  });

  group('DioOrderRepository client-side tab filtering (item 6)', () {
    late _StubAdapter adapter;
    late DioOrderRepository repo;

    setUp(() {
      adapter = _StubAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
      repo = DioOrderRepository(dio);
    });

    // A loosely-filtered server page mixing canonical + legacy + terminal
    // statuses — what a drifting `status=` filter actually returns.
    List<Map<String, Object?>> mixedPage() => [
          {'id': 'r-accepted', 'status': 'accepted', 'createdAt': '2026-07-03T00:44:05Z'},
          {'id': 'r-ordered', 'status': 'Ordered', 'createdAt': '2026-07-03T00:44:05Z'},
          {'id': 'r-intransit', 'status': 'InTransit', 'createdAt': '2026-07-03T00:44:05Z'},
          {'id': 'r-done', 'status': 'Done', 'createdAt': '2026-07-03T00:44:05Z'},
          {'id': 'r-delivered', 'status': 'delivered', 'createdAt': '2026-07-03T00:44:05Z'},
          {'id': 'r-cancelled', 'status': 'Cancelled', 'createdAt': '2026-07-03T00:44:05Z'},
          {'id': 'r-expired', 'status': 'expired', 'createdAt': '2026-07-03T00:44:05Z'},
        ];

    test('Active tab keeps accepted/Ordered/InTransit, drops Done/terminals',
        () async {
      adapter.body = {'items': mixedPage()};

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 20,
      );

      expect(
        page.items.map((o) => o.id),
        ['r-accepted', 'r-ordered', 'r-intransit'],
      );
    });

    test('Completed tab keeps only Done/delivered', () async {
      adapter.body = {'items': mixedPage()};

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.completed,
        page: 1,
        pageSize: 20,
      );

      expect(page.items.map((o) => o.id), ['r-done', 'r-delivered']);
    });

    test('Cancelled tab keeps only Cancelled/expired (canonical + legacy)',
        () async {
      adapter.body = {'items': mixedPage()};

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.cancelled,
        page: 1,
        pageSize: 20,
      );

      expect(page.items.map((o) => o.id), ['r-cancelled', 'r-expired']);
    });

    test('hasMore derives from the WIRE page size, not the filtered count',
        () async {
      // Server filled the page (2/2) but filtering trims one row — more pages
      // may still exist.
      adapter.body = {
        'items': [
          {'id': 'r-1', 'status': 'accepted', 'createdAt': '2026-07-03T00:00:00Z'},
          {'id': 'r-2', 'status': 'Done', 'createdAt': '2026-07-03T00:00:00Z'},
        ],
      };

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 2,
      );

      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
    });

    test('flat numeric amount (live wire shape) maps to minor units', () async {
      adapter.body = {
        'items': [
          {
            'id': 'r-amt',
            'status': 'accepted',
            'createdAt': '2026-07-03T00:00:00Z',
            'amount': 12,
          },
        ],
      };

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 20,
      );

      expect(page.items.single.amountMinor, 1200);
      expect(page.items.single.currency, 'USD');
    });

    test('{ minorUnits, currency } money object still maps', () async {
      adapter.body = {
        'items': [
          {
            'id': 'r-amt2',
            'status': 'accepted',
            'createdAt': '2026-07-03T00:00:00Z',
            'amount': {'minorUnits': 950, 'currency': 'USD'},
          },
        ],
      };

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 20,
      );

      expect(page.items.single.amountMinor, 950);
      expect(page.items.single.hasKnownAmount, isTrue);
    });

    // ── T11 / SW-02: money truth on history rows ────────────────────────────
    test('ABSENT amount → amountMinor null, NOT a fabricated 0 (\$0.00)',
        () async {
      // The row the audit caught: a completed order whose list entry carries no
      // amount key. The old `_ => 0` fallback rendered "\$0.00" on every row.
      adapter.body = {
        'items': [
          {
            'id': 'r-noamt',
            'status': 'Done',
            'createdAt': '2026-07-03T00:00:00Z',
          },
        ],
      };

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.completed,
        page: 1,
        pageSize: 20,
      );

      final row = page.items.single;
      expect(row.amountMinor, isNull);
      expect(row.hasKnownAmount, isFalse); // → card shows "—", never \$0.00
    });

    // ── SW-03 family: local-time truth on history rows ──────────────────────
    test('zone-less createdAt is normalized to a UTC instant', () async {
      // A gateway string WITHOUT a zone marker is a UTC instant; parsing it raw
      // would read it as device-local, so the card's toLocal() would be a no-op
      // and print the UTC wall clock (feed read "12:31" under a 14:31 clock).
      adapter.body = {
        'items': [
          {
            'id': 'r-zl',
            'status': 'accepted',
            'createdAt': '2026-07-03T12:31:00',
          },
        ],
      };

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 20,
      );

      final created = page.items.single.createdAt;
      expect(created.isUtc, isTrue);
      expect(created, DateTime.utc(2026, 7, 3, 12, 31));
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  Map<String, Object?> body = const {'items': <Object?>[]};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

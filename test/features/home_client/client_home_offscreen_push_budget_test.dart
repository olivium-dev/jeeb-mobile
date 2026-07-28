import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';

/// READ ECONOMICS — the customer home summary must not read for pixels nobody
/// can see.
///
/// Measured on device, ONE `delivery` push on the customer phone produced TEN
/// gateway reads: `/v1/offers` ×4 and `/requests` ×2 among them. Six of those
/// came from HERE — `ClientHomeCubit` lives in the shell's `IndexedStack`, so it
/// stays mounted and subscribed while `/delivery/:id` or `/chat/:id` sits on top
/// of the shell, and its snapshot is a FAN-OUT (three list reads plus one
/// `GET /v1/offers?requestId=` per non-accepted request).
///
/// Neither wave-D lever could reach this: the topic filter is already correct
/// (`{order, offers}` — this cubit really does render order + auction state), and
/// the single-flight latch has nothing to collapse onto because the other reads
/// belong to DIFFERENT subscribers.
///
/// The bar asserted here, and the exact numbers are read off the real
/// `DioClientHomeRepository` over a recording adapter, never hand-typed:
///
///   1. off screen + one push  → **ZERO** reads;
///   2. off screen + a BURST   → still zero (N pushes collapse to one debt);
///   3. back on screen         → **exactly one snapshot**, so nothing the user
///      can see was stale;
///   4. on screen + one push   → one snapshot, unchanged from before the fix.
///
/// (4) is the control: it proves the gate is a VISIBILITY gate and not a mute
/// button — without it, a test suite that only asserts "zero reads" would pass on
/// a cubit that had simply stopped listening.
void main() {
  late _RecordingAdapter adapter;
  late Dio dio;
  late PushRefreshSignals bus;
  late ClientHomeCubit cubit;

  /// Snapshot read count for this fixture, measured (not assumed) from the cold
  /// load: 3 list reads + one `/v1/offers?requestId=` per pending request.
  late int snapshotReads;

  setUp(() async {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
      ..httpClientAdapter = adapter;
    bus = PushRefreshSignals();
    cubit = ClientHomeCubit(
      repository: DioClientHomeRepository(dio),
      greetingNameProvider: () => null,
      // Exactly what `home_tab.dart` subscribes with.
      refreshSignals: bus.streamFor(const {
        RefreshTopic.order,
        RefreshTopic.offers,
      }),
    );
    await cubit.load();
    await pumpEventQueue();
    snapshotReads = adapter.paths.length;
    adapter.clear();
  });

  tearDown(() async {
    await cubit.close();
    await bus.dispose();
  });

  test('the fixture really does fan out — the pre-fix cost of one push', () {
    // Guards the whole file: if the fixture ever stops fanning out, every
    // "zero reads" assertion below would pass for the wrong reason.
    expect(snapshotReads, greaterThanOrEqualTo(6), reason: adapter.summary);
  });

  test('off screen: ONE push costs ZERO reads', () async {
    cubit.setPollingVisible(false);

    bus.signal(const {RefreshTopic.order});
    await pumpEventQueue();

    expect(adapter.paths, isEmpty, reason: adapter.summary);
  });

  test('off screen: a BURST of five pushes still costs ZERO reads', () async {
    cubit.setPollingVisible(false);

    for (var i = 0; i < 5; i++) {
      bus.signal(const {RefreshTopic.order});
    }
    await pumpEventQueue();

    expect(adapter.paths, isEmpty, reason: adapter.summary);
  });

  test(
    'back on screen: the deferred debt is paid ONCE — five pushes, one snapshot',
    () async {
      cubit.setPollingVisible(false);
      for (var i = 0; i < 5; i++) {
        bus.signal(const {RefreshTopic.order});
      }
      await pumpEventQueue();
      expect(adapter.paths, isEmpty, reason: 'still hidden');

      cubit.setPollingVisible(true);
      await pumpEventQueue();

      expect(
        adapter.paths.length,
        snapshotReads,
        reason: 'exactly one snapshot, not five: ${adapter.summary}',
      );
    },
  );

  test(
    'back on screen with NOTHING pending reads nothing — becoming visible is not an event',
    () async {
      cubit.setPollingVisible(false);
      await pumpEventQueue();
      cubit.setPollingVisible(true);
      await pumpEventQueue();

      expect(adapter.paths, isEmpty, reason: adapter.summary);
    },
  );

  test(
    'CONTROL — on screen, one push still reads: this is a visibility gate, not a mute',
    () async {
      // Never hidden: the default. The pre-fix behaviour must be preserved
      // exactly for the surface the user is actually looking at.
      bus.signal(const {RefreshTopic.order});
      await pumpEventQueue();

      expect(adapter.paths.length, snapshotReads, reason: adapter.summary);
    },
  );
}

/// Records every request path+query the repository actually puts on the wire.
///
/// A recording ADAPTER, not an interceptor: it sits below the whole Dio stack,
/// so anything an interceptor (single-flight coalescer, rate-limit gate) collapses
/// is collapsed before it is counted. The count is therefore WIRE reads, which is
/// what a device capture counts too.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> paths = <String>[];

  void clear() => paths.clear();

  String get summary => 'wire reads (${paths.length}): $paths';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final query = options.uri.query;
    paths.add(query.isEmpty ? options.path : '${options.path}?$query');
    return ResponseBody.fromString(
      jsonEncode(_bodyFor(options)),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  /// Four PENDING client requests, no active deliveries, no offers. Four pending
  /// rows is what makes the repo fire four `GET /v1/offers?requestId=` probes —
  /// the `/v1/offers` ×4 the device capture recorded.
  Object _bodyFor(RequestOptions options) {
    final path = options.path;
    if (path.contains('/offers')) return <Object>[];
    if (path.contains('/requests')) {
      return <Object>[
        for (var i = 1; i <= 4; i++)
          <String, Object?>{
            'id': 'req-$i',
            'status': 'pending',
            'title': 'Request $i',
            'displayId': 'JB-00$i',
            'createdAt': '2026-07-28T06:00:00Z',
          },
      ];
    }
    return <Object>[];
  }

  @override
  void close({bool force = false}) {}
}

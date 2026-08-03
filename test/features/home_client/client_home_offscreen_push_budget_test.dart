import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';

/// READ ECONOMICS — the customer home summary must not read for pixels nobody
/// can see.
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
      bus.signal(const {RefreshTopic.order});
      await pumpEventQueue();

      expect(adapter.paths.length, snapshotReads, reason: adapter.summary);
    },
  );
}

/// Records every request path+query the repository actually puts on the wire.
/// A recording ADAPTER, not an interceptor: it sits below the whole Dio stack,
/// so anything an interceptor (single-flight coalescer, rate-limit gate) collapses
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

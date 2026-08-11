// BUG-8 (sprint-008 run-7) regression guard — customer order-chat pinned-summary

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/data/dio_order_chat_summary_repository.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioOrderChatSummaryRepository originRepo() =>
      DioOrderChatSummaryRepository(dio, originGateway: true);
  DioOrderChatSummaryRepository mockRepo() =>
      DioOrderChatSummaryRepository(dio, originGateway: false);

  test('origin: reads the PLURAL GET /v1/deliveries/{id} — NOT the singular '
      '/v1/delivery/{id} that 404s on the live gateway (BUG-8)', () async {
    await originRepo().fetchSummary(_deliveryId);

    expect(adapter.getPaths, contains('/v1/deliveries/$_deliveryId'));
    expect(
      adapter.getPaths,
      isNot(contains('/v1/delivery/$_deliveryId')),
      reason: 'BUG-8: the singular route 404s on the live origin gateway',
    );
  });

  test('mock: keeps the singular GET /v1/delivery/{id} alias when '
      'originGateway:false', () async {
    await mockRepo().fetchSummary(_deliveryId);

    expect(adapter.getPaths, contains('/v1/delivery/$_deliveryId'));
    expect(adapter.getPaths, isNot(contains('/v1/deliveries/$_deliveryId')));
  });

  // ---------------------------------------------------------------------

  test('P3/M1: reads the description from the DELIVERY row', () async {
    adapter.bodies['/v1/deliveries/$_deliveryId'] = const {
      'description': '2 kilos apples',
      'status': 'Ordered',
    };

    final summary = await originRepo().fetchSummary(_deliveryId);

    expect(summary.description, '2 kilos apples');
    expect(summary.hasDescription, isTrue);
  });

  test('P3/M2: falls back to the REQUEST row when the delivery carries none',
      () async {
    adapter.bodies['/v1/deliveries/$_deliveryId'] = const <String, Object?>{};
    adapter.bodies['/v1/requests/$_deliveryId'] = const {
      'description': '2 kilos apples',
    };

    final summary = await originRepo().fetchSummary(_deliveryId);

    expect(summary.description, '2 kilos apples');
  });

  test('P3/M3: the legacy :4010 `title` alias still resolves', () async {
    adapter.bodies['/v1/delivery/$_deliveryId'] = const {'title': 'apples'};
    adapter.bodies['/v1/requests/$_deliveryId'] = const <String, Object?>{};

    final summary = await mockRepo().fetchSummary(_deliveryId);

    expect(summary.description, 'apples');
  });

  test('P3/M4: Jeeber mode fires ONLY the participant-scoped delivery leg — '
      'never the owner-scoped /v1/requests or /v1/offers reads', () async {
    adapter.bodies['/v1/deliveries/$_deliveryId'] = const {
      'description': 'apples',
    };

    final summary = await DioOrderChatSummaryRepository(
      dio,
      originGateway: true,
      ownerScopedReads: false,
    ).fetchSummary(_deliveryId);

    expect(adapter.getPaths, contains('/v1/deliveries/$_deliveryId'));
    expect(
      adapter.getPaths.any((p) => p.startsWith('/v1/requests/')),
      isFalse,
      reason: '/v1/requests/{id} is owner-scoped → 403 for the Jeeber',
    );
    expect(
      adapter.getPaths.any((p) => p.startsWith('/v1/offers')),
      isFalse,
      reason: '/v1/offers?requestId= is owner-scoped → 403 for the Jeeber',
    );
    expect(summary.description, 'apples');
  });

  test('P3/M5: customer mode (default) still fires all three legs', () async {
    await originRepo().fetchSummary(_deliveryId);

    expect(adapter.getPaths, contains('/v1/deliveries/$_deliveryId'));
    expect(adapter.getPaths, contains('/v1/requests/$_deliveryId'));
    expect(adapter.getPaths, contains('/v1/offers'));
  });

  // --- counterparty identity (chat header + rating avatar) ----------------

  test('counterparty: reads jeeberAvatarUrl/clientName/clientAvatarUrl from '
      'the DELIVERY row on BOTH legs', () async {
    adapter.bodies['/v1/deliveries/$_deliveryId'] = const {
      'jeeberName': 'Karim',
      'jeeberAvatarUrl': 'http://gw.test/api/users/j-1/avatar?v=abc',
      'clientName': 'Nour',
      'clientAvatarUrl': 'http://gw.test/api/users/c-1/avatar?v=def',
    };

    final client = await originRepo().fetchSummary(_deliveryId);
    expect(client.jeeberName, 'Karim');
    expect(client.jeeberAvatarUrl, 'http://gw.test/api/users/j-1/avatar?v=abc');
    expect(client.clientName, 'Nour');
    expect(client.clientAvatarUrl, 'http://gw.test/api/users/c-1/avatar?v=def');

    // The jeeber leg reads the SAME delivery row (no owner-scoped hop).
    final jeeber = await DioOrderChatSummaryRepository(
      dio,
      originGateway: true,
      ownerScopedReads: false,
    ).fetchSummary(_deliveryId);
    expect(jeeber.clientName, 'Nour');
    expect(jeeber.clientAvatarUrl, 'http://gw.test/api/users/c-1/avatar?v=def');
  });

  test('counterparty: keys ABSENT (old gateway) ⇒ empty, never a throw',
      () async {
    adapter.bodies['/v1/deliveries/$_deliveryId'] = const {
      'jeeberName': 'Karim',
    };

    final summary = await originRepo().fetchSummary(_deliveryId);

    expect(summary.jeeberAvatarUrl, '');
    expect(summary.clientName, '');
    expect(summary.clientAvatarUrl, '');
  });

  test('P3/M6: no description anywhere ⇒ empty, no throw', () async {
    adapter.bodies['/v1/deliveries/$_deliveryId'] = const <String, Object?>{};
    adapter.bodies['/v1/requests/$_deliveryId'] = const <String, Object?>{};

    final summary = await originRepo().fetchSummary(_deliveryId);

    expect(summary.description, '');
    expect(summary.hasDescription, isFalse);
  });
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  final List<String> getPaths = <String>[];

  /// P3: per-path body overrides. A path with no entry falls back to the
  /// generic 2xx map the BUG-8 route tests rely on.
  final Map<String, Map<String, Object?>> bodies = <String, Map<String, Object?>>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') getPaths.add(options.path);
    final override = bodies[options.path];
    if (override != null) return _json(override);
    // Any 2xx map lets fetchSummary complete through its request/offer reads.
    if (options.path.contains('/offers')) {
      return _json(const {'items': <Object?>[]});
    }
    return _json({'id': _deliveryId, 'requestId': _deliveryId});
  }
}

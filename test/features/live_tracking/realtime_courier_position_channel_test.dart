import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/live_tracking/data/realtime_courier_position_channel.dart';

import '../../support/fake_web_socket_channel.dart';

/// `GET /v1/realtime/jeeb:delivery:{id}` → subscribe, or degrade.
/// ## The claim under test is the DEGRADATION, not the happy path
void main() {
  const deliveryId = 'DLV-42';
  const topic = 'jeeb:delivery:$deliveryId';
  const channelName = 'topic:$topic';

  late List<Uri> dialled;
  late FakeWebSocketChannel ws;
  late List<String> requestedPaths;

  Map<String, dynamic> descriptor({
    Object? socketUrl = 'wss://realtime.test/socket/websocket',
    String token = 'guardian-subscribe-jwt',
    Object? topicValue = topic,
    Object? channelValue = channelName,
    Object? streamValue = 'location',
  }) =>
      <String, dynamic>{
        'deliveryId': deliveryId,
        'topic': topicValue,
        'channel': channelValue,
        'stream': streamValue,
        'socketUrl': socketUrl,
        'token': token,
        'expiresAt': '2026-08-01T09:15:00+00:00',
      };

  /// A Dio whose adapter is replaced by a scripted responder — no server, but
  /// the shipped `RealtimeCourierPositionChannel` code path in full, including
  Dio dioAnswering({
    int status = 200,
    Map<String, dynamic>? body,
  }) {
    requestedPaths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requestedPaths.add(options.path);
        if (status >= 200 && status < 300) {
          handler.resolve(Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: status,
            data: body,
          ));
          return;
        }
        handler.reject(DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: status,
          ),
          type: DioExceptionType.badResponse,
        ));
      },
    ));
    return dio;
  }

  RealtimeCourierPositionChannel channelOver(
    Dio dio, {
    bool factoryThrows = false,
  }) {
    dialled = <Uri>[];
    ws = FakeWebSocketChannel();
    return RealtimeCourierPositionChannel(
      dio,
      channelFactory: (uri) {
        dialled.add(uri);
        if (factoryThrows) throw StateError('unreachable host');
        return ws;
      },
    );
  }

  tearDown(() async {
    await ws.dispose();
  });

  group('the happy path — POSITIVE CONTROL for every degrade below', () {
    test('a full descriptor opens a subscription on the descriptor socketUrl, '
        'channel and token', () async {
      final channel = channelOver(dioAnswering(body: descriptor()));

      final positions = await channel.open(deliveryId: deliveryId);

      expect(positions, isNotNull);
      expect(requestedPaths.single, '/v1/realtime/jeeb:delivery:$deliveryId');
      expect(dialled.single.host, 'realtime.test');
      expect(dialled.single.queryParameters['token'], 'guardian-subscribe-jwt');
      final join =
          ws.sentByClient.firstWhere((f) => f.contains('phx_join'));
      expect(join, contains(channelName));
      expect(join, contains('location'));
    });
  });

  group('degrade — every one of these must be indistinguishable from '
      '"the feature is off"', () {
    Future<void> expectDegraded(
      RealtimeCourierPositionChannel channel, {
      required String because,
    }) async {
      final positions = await channel.open(deliveryId: deliveryId);
      expect(positions, isNull, reason: because);
      expect(dialled, isEmpty,
          reason: 'a null return that still dialled a socket is a leak, not a '
              'degrade ($because)');
    }

    test('socketUrl is null — the gateway default, not an edge case', () async {
      await expectDegraded(
        channelOver(dioAnswering(body: descriptor(socketUrl: null))),
        because: 'Services:Realtime:PublicSocketUrl is unset',
      );
    });

    test('socketUrl is an empty string', () async {
      await expectDegraded(
        channelOver(dioAnswering(body: descriptor(socketUrl: ''))),
        because: 'an empty url is not a url',
      );
    });

    test('socketUrl is not a ws(s) scheme', () async {
      await expectDegraded(
        channelOver(dioAnswering(body: descriptor(socketUrl: 'http://x:5804/'))),
        because: 'dialling it would produce an obscure transport error rather '
            'than a clean degrade',
      );
    });

    test('cleartext ws is rejected outside the development flavor', () async {
      await expectDegraded(
        channelOver(dioAnswering(
          body: descriptor(socketUrl: 'ws://realtime.test/socket/websocket'),
        )),
        because: 'staging and production tracking require encrypted WSS',
      );
    });

    test('403 — the caller is not a party to this delivery', () async {
      await expectDegraded(
        channelOver(dioAnswering(status: 403)),
        because: 'fail-closed at the gateway',
      );
    });

    test('404 — unknown delivery', () async {
      await expectDegraded(channelOver(dioAnswering(status: 404)),
          because: 'no such delivery');
    });

    test('503 — no Guardian secret configured on the gateway', () async {
      await expectDegraded(channelOver(dioAnswering(status: 503)),
          because: 'the gateway refuses to hand back a useless descriptor');
    });

    test('a gateway that does not serve the route at all', () async {
      await expectDegraded(channelOver(dioAnswering(status: 405)),
          because: 'an older gateway predates #339');
    });

    test('an empty body', () async {
      await expectDegraded(channelOver(dioAnswering()),
          because: '200 with no descriptor is not a descriptor');
    });

    test('a descriptor with no token', () async {
      await expectDegraded(
        channelOver(dioAnswering(body: descriptor(token: ''))),
        because: 'joining without a credential is refused anyway, and we do '
            'NOT fall back to the service\'s open "*" minter',
      );
    });

    test('a malformed descriptor (no topic)', () async {
      await expectDegraded(
        channelOver(dioAnswering(body: descriptor(topicValue: null))),
        because: 'null on any parse failure is the contract',
      );
    });

    test('a descriptor whose types are wrong throws nothing', () async {
      await expectDegraded(
        channelOver(dioAnswering(body: descriptor(topicValue: 12345))),
        because: 'an unchecked cast on the wire is how "total" promises break',
      );
    });

    test('an unreachable host — the socket itself refuses', () async {
      final channel = channelOver(
        dioAnswering(body: descriptor()),
        factoryThrows: true,
      );

      final positions = await channel.open(deliveryId: deliveryId);

      expect(positions, isNull);
      // Here the dial IS expected — that is what threw. The claim is that the
      expect(dialled, hasLength(1));
    });
  });

  group('descriptor parsing', () {
    test('derives the channel only when the gateway did not send one', () async {
      final channel =
          channelOver(dioAnswering(body: descriptor(channelValue: null)));

      await channel.open(deliveryId: deliveryId);

      expect(
        ws.sentByClient.firstWhere((f) => f.contains('phx_join')),
        contains(channelName),
      );
    });

    test('accepts snake_case socket_url', () async {
      final body = descriptor(socketUrl: null)
        ..['socket_url'] = 'wss://realtime.test/socket/websocket';
      final channel = channelOver(dioAnswering(body: body));

      final positions = await channel.open(deliveryId: deliveryId);

      expect(positions, isNotNull);
      expect(dialled.single.host, 'realtime.test');
    });

    test('resolve() surfaces the descriptor fields verbatim', () async {
      final channel = channelOver(dioAnswering(body: descriptor()));

      final d = await channel.resolve(deliveryId);

      expect(d, isNotNull);
      expect(d!.topic, topic);
      expect(d.channel, channelName);
      expect(d.stream, 'location');
      expect(d.token, 'guardian-subscribe-jwt');
      expect(d.socketUrl, 'wss://realtime.test/socket/websocket');
      expect(d.expiresAt, isNotNull);
    });
  });
}

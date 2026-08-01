import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/live_tracking/data/courier_position_socket.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';

import '../../support/fake_web_socket_channel.dart';

/// The WIRE CONTRACT of the courier-position subscription, asserted frame by
/// frame against the shapes `realtime-comunication-service` actually
/// implements.
///
/// ## What these can and cannot prove
///
/// They prove the client dials the right URL, joins the right channel with the
/// right payload, keeps the channel alive on the server's own schedule, keeps
/// exactly the `location` envelopes and drops everything else, and closes the
/// socket when its reader goes away. That is a `suite` claim about the client
/// half.
///
/// They prove nothing about the server. Whether MSI's Phoenix accepts the
/// gateway-minted credential and fans a real courier's GPS onto this topic is a
/// `device`/`capture` claim; the gateway lane established it separately against
/// `192.168.2.39:5804` (3/3 positions on the owning delivery, refused on
/// another, 0 frames idle).
///
/// ## Every silence assertion is paired
///
/// A test that asserts "no fix arrived" is satisfied by a socket that never
/// delivers anything at all. So each negative below runs on the SAME socket
/// instance that has already been shown to deliver a fix, or is immediately
/// followed by a frame that MUST land. A probe that cannot see the thing it is
/// asserting the absence of is not a probe.
void main() {
  const channelName = 'topic:jeeb:delivery:DLV-1';
  const stream = 'location';

  late FakeWebSocketChannel ws;
  late List<Uri> dialled;

  CourierPositionSocket build({
    String token = 'guardian-jwt',
    Duration keepAlive = const Duration(seconds: 20),
  }) {
    ws = FakeWebSocketChannel();
    dialled = <Uri>[];
    return CourierPositionSocket(
      socketUri: Uri.parse('ws://realtime.test/socket/websocket'),
      token: token,
      channel: channelName,
      stream: stream,
      keepAlive: keepAlive,
      channelFactory: (uri) {
        dialled.add(uri);
        return ws;
      },
    );
  }

  /// One `LiveComm.Protocol.Envelope` as `TopicChannel` pushes it:
  /// `push(socket, "event", envelope)` on the joined channel.
  String envelopeFrame({
    String topic = channelName,
    String event = 'event',
    String envelopeStream = stream,
    Object? lat = 33.8938,
    Object? lng = 35.5018,
    Object? accuracy,
    String? timestamp,
    String? jeeberId,
  }) =>
      jsonEncode(<Object?>[
        '1',
        null,
        topic,
        event,
        <String, Object?>{
          'v': 1,
          'id': '01HXYZ',
          'type': 'event',
          'topic': 'jeeb:delivery:DLV-1',
          'stream': envelopeStream,
          'ts': 1785600000000,
          'seq': 7,
          'meta': <String, Object?>{},
          'data': <String, Object?>{
            'lat': lat,
            'lng': lng,
            'accuracy': ?accuracy,
            'deliveryId': 'DLV-1',
            'jeeberId': ?jeeberId,
            'timestamp': ?timestamp,
          },
        },
      ]);

  List<dynamic> decodeFrame(String raw) => jsonDecode(raw) as List<dynamic>;

  group('CourierPositionSocket — connect + join', () {
    test('dials with the gateway credential as `token` and vsn=2.0.0', () async {
      final socket = build(token: 'scoped-subscribe-jwt');
      await socket.connect();

      // The token param is what `LiveCommSocket.connect/3` reads; without it
      // the upgrade is refused `missing_token` and no frame ever arrives.
      expect(dialled.single.queryParameters['token'], 'scoped-subscribe-jwt');
      expect(dialled.single.queryParameters['vsn'], '2.0.0');
      await socket.close();
    });

    test('joins the descriptor CHANNEL with {"streams":["location"]}', () async {
      final socket = build();
      await socket.connect();

      final join = decodeFrame(
        ws.sentByClient.firstWhere((f) => f.contains('phx_join')),
      );
      // [joinRef, ref, topic, event, payload]
      expect(join[0], isNotNull, reason: 'a v2 join must carry a joinRef');
      expect(join[2], channelName,
          reason: 'the routing prefix comes from the gateway descriptor, '
              'never reconstructed here');
      expect(join[3], 'phx_join');
      expect((join[4]! as Map)['streams'], <String>['location']);
      await socket.close();
    });
  });

  group('CourierPositionSocket — inbound', () {
    test('a location envelope becomes a fix (POSITIVE CONTROL for every '
        'silence assertion below)', () async {
      final socket = build();
      final fixes = <CourierPositionFix>[];
      socket.positions.listen(fixes.add);
      await socket.connect();

      ws.serverToClient.add(envelopeFrame(
        accuracy: 12.5,
        timestamp: '2026-08-01T09:00:00.0000000Z',
        jeeberId: 'jeeber-7',
      ));
      await pumpEventQueue();

      expect(fixes, hasLength(1));
      expect(fixes.single.lat, closeTo(33.8938, 1e-9));
      expect(fixes.single.lng, closeTo(35.5018, 1e-9));
      expect(fixes.single.accuracy, closeTo(12.5, 1e-9));
      expect(fixes.single.jeeberId, 'jeeber-7');
      expect(fixes.single.timestamp, isNotNull);
      expect(socket.frameCount, 1);
      await socket.close();
    });

    test('INTEGER coordinates still land — JSON 33 decodes to int, and an '
        '`as double` there is how a live feed goes silent', () async {
      final socket = build();
      final fixes = <CourierPositionFix>[];
      socket.positions.listen(fixes.add);
      await socket.connect();

      ws.serverToClient.add(envelopeFrame(lat: 33, lng: 35));
      await pumpEventQueue();

      expect(fixes, hasLength(1));
      expect(fixes.single.lat, 33.0);
      expect(fixes.single.lng, 35.0);
      await socket.close();
    });

    test('everything that is NOT a location envelope is dropped — and the '
        'same socket then accepts one that is', () async {
      final socket = build();
      final fixes = <CourierPositionFix>[];
      socket.positions.listen(fixes.add);
      await socket.connect();

      // 1. Another stream on the same topic. The server does NOT filter its
      //    fan-out by the join's `streams`, so this is a real arrival.
      ws.serverToClient.add(envelopeFrame(envelopeStream: 'chat'));
      // 2. Phoenix lifecycle frames.
      ws.serverToClient.add(jsonEncode(
          <Object?>['1', '1', channelName, 'phx_reply', <String, Object?>{}]));
      ws.serverToClient.add(jsonEncode(<Object?>[
        null,
        null,
        channelName,
        'presence_state',
        <String, Object?>{}
      ]));
      // 3. A replay — a position the courier has already left.
      ws.serverToClient.add(envelopeFrame(event: 'replay_event'));
      // 4. A frame addressed to a different channel.
      ws.serverToClient
          .add(envelopeFrame(topic: 'topic:jeeb:delivery:SOMEONE-ELSE'));
      // 5. A malformed coordinate.
      ws.serverToClient.add(envelopeFrame(lat: 'thirty-three'));
      // 6. Not a v2 frame at all.
      ws.serverToClient.add('not json');
      ws.serverToClient.add(jsonEncode(<String, Object?>{'v1': 'object shape'}));
      await pumpEventQueue();

      expect(fixes, isEmpty, reason: 'none of the above is a location fix');

      // THE PAIRING. The probe is demonstrably still able to see one.
      ws.serverToClient.add(envelopeFrame(lat: 1.5, lng: 2.5));
      await pumpEventQueue();
      expect(fixes, hasLength(1));
      expect(fixes.single.lat, 1.5);
      await socket.close();
    });
  });

  group('CourierPositionSocket — keepalive', () {
    // Driven under `fakeAsync`, deliberately. A first draft used real
    // `Future.delayed` waits and passed in isolation, then went red inside the
    // full suite: wall-clock waits measured against a 20 s production interval
    // are a load-dependent coin flip, and a flaky gate teaches people to re-run
    // rather than to read. Virtual time asserts the SCHEDULE, which is the
    // actual claim.
    test('sends a CHANNEL ping and a transport heartbeat once the interval '
        'elapses, and NOTHING before it', () {
      fakeAsync((async) {
        final socket = build(keepAlive: const Duration(seconds: 20));
        unawaited(socket.connect());
        async.flushMicrotasks();

        // NEGATIVE CONTROL: one tick short of the interval.
        async.elapse(const Duration(seconds: 19));
        expect(ws.sentByClient.where((f) => f.contains('"ping"')), isEmpty,
            reason: 'the timer must not fire early');

        async.elapse(const Duration(seconds: 2));

        final pings = ws.sentByClient
            .map(decodeFrame)
            .where((f) => f[3] == 'ping')
            .toList();
        final beats = ws.sentByClient
            .map(decodeFrame)
            .where((f) => f[3] == 'heartbeat')
            .toList();

        // The ping must be on OUR channel: `TopicChannel.handle_in("ping", …)`
        // is the only thing that resets `missed_heartbeats`, and it only runs
        // for a frame addressed to the channel. A ping sent to `phoenix` would
        // keep the socket up while the channel died at 75 s anyway.
        expect(pings, hasLength(1));
        expect(pings.first[2], channelName);
        // And the transport heartbeat is on the reserved topic.
        expect(beats, hasLength(1));
        expect(beats.first[2], 'phoenix');

        // It keeps going, comfortably inside the server's 75 s ceiling.
        async.elapse(const Duration(seconds: 60));
        expect(
          ws.sentByClient.map(decodeFrame).where((f) => f[3] == 'ping').length,
          4,
        );

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('close() stops the keepalive — no frames after teardown', () {
      fakeAsync((async) {
        final socket = build(keepAlive: const Duration(seconds: 20));
        unawaited(socket.connect());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 25));
        expect(ws.sentByClient.any((f) => f.contains('"ping"')), isTrue,
            reason: 'POSITIVE CONTROL: it was pinging before close');

        unawaited(socket.close());
        async.flushMicrotasks();
        final afterClose = ws.sentByClient.length;
        async.elapse(const Duration(minutes: 5));

        expect(ws.sentByClient, hasLength(afterClose),
            reason: 'a live timer after close is a leaked socket');
        expect(async.periodicTimerCount, 0);
      });
    });
  });

  group('CourierPositionSocket — teardown', () {
    test('cancelling the subscription CLOSES the socket (not merely stops '
        'reading it)', () async {
      final socket = build();
      final sub = socket.positions.listen((_) {});
      await socket.connect();
      expect(ws.sinkClosed, isFalse);

      await sub.cancel();
      await pumpEventQueue();

      expect(ws.sinkClosed, isTrue);
    });

    test('a server-side close ends the feed rather than hanging it', () async {
      final socket = build();
      var done = false;
      socket.positions.listen((_) {}, onDone: () => done = true);
      await socket.connect();

      await ws.serverToClient.close();
      await pumpEventQueue();

      expect(done, isTrue);
    });

    test('a transport error ends the feed WITHOUT surfacing an error the '
        'screen would have to catch', () async {
      final socket = build();
      var done = false;
      Object? surfaced;
      socket.positions.listen(
        (_) {},
        onError: (Object e) => surfaced = e,
        onDone: () => done = true,
      );
      await socket.connect();

      ws.serverToClient.addError(StateError('socket blew up'));
      await pumpEventQueue();

      expect(done, isTrue);
      expect(surfaced, isNull,
          reason: 'the transport reports its own death by ENDING, so a '
              'caller that forgets onError cannot be faulted by it');
    });

    test('close() is idempotent', () async {
      final socket = build();
      await socket.connect();
      await socket.close();
      await socket.close();
    });
  });
}

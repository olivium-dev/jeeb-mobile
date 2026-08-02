import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';

/// Wire-contract lock for the Dev Tool's "Send message" action 
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

/// Every request that reached the wire, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

const String kRequestId = 'req-8f21';
const String kConversationId = 'b5e04750-13dc-4881-8315-234a1f8c69d1';

/// The exact projection the live gateway returns (snake_case, p
const Map<String, Object?> kConversationRow = <String, Object?>{
  'conversation_id': kConversationId,
  'correlation_key': kRequestId,
  'phase': 'broadcasting',
};

/// Serves the mint, then whatever [onConversationRead] / [onApp
_ScriptedAdapter _adapterFor({
  ResponseBody Function()? onConversationRead,
  ResponseBody Function()? onAppend,
}) {
  return _ScriptedAdapter((RequestOptions options) {
    if (options.path == '/auth/tokens') {
      return _json(<String, Object?>{'accessToken': 'act-as-token'}, 200);
    }
    if (options.method == 'GET' && options.path == '/v1/conversations') {
      return (onConversationRead ?? () => _json(kConversationRow, 200))();
    }
    if (options.method == 'POST' && options.path.endsWith('/messages')) {
      return (onAppend ??
          () => _json(<String, Object?>{'message_id': 'm-1'}, 201))();
    }
    return _json(<String, Object?>{'unexpected': options.path}, 500);
  });
}

DevGatewayClient _clientOn(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://gw.test'));
  dio.httpClientAdapter = adapter;
  return DevGatewayClient(dio: dio);
}

Future<String> _send(DevGatewayClient client, {String text = 'hello'}) =>
    client.sendMessage(
      asUserId: 'u-1',
      asRole: 'client',
      requestId: kRequestId,
      text: text,
    );

void main() {
  group('DevGatewayClient.sendMessage — post-#350 wire contract', () {
    test('resolves requestId → conversationId, then appends to the '
        'conversation route', () async {
      final adapter = _adapterFor();

      final conversationId = await _send(_clientOn(adapter));

      expect(conversationId, kConversationId);
      expect(adapter.requests.map((RequestOptions r) => r.path), <String>[
        '/auth/tokens',
        '/v1/conversations',
        '/v1/conversations/$kConversationId/messages',
      ]);

      final read = adapter.requests[1];
      expect(read.method, 'GET');
      expect(read.queryParameters['correlationKey'], kRequestId);

      final append = adapter.requests[2];
      expect(append.method, 'POST');
      expect(append.data, <String, dynamic>{'kind': 'text', 'body': 'hello'});
      expect(append.headers['Authorization'], 'Bearer act-as-token');
    });

    test('NEGATIVE CONTROL — never touches the retired channel-write route',
        () async {
      final adapter = _adapterFor();

      await _send(_clientOn(adapter));

      expect(
        adapter.requests.where(
          (RequestOptions r) => r.path.contains('/api/Chat/channels'),
        ),
        isEmpty,
      );
    });

    test('stamps a UNIQUE Idempotency-Key per send, so a second Run posts a '
        'new line instead of replaying the first', () async {
      final adapter = _adapterFor();
      final client = _clientOn(adapter);

      await _send(client, text: 'first');
      await _send(client, text: 'second');

      final keys = adapter.requests
          .where((RequestOptions r) => r.path.endsWith('/messages'))
          .map((RequestOptions r) => r.headers['Idempotency-Key'])
          .toList();
      expect(keys, hasLength(2));
      expect(keys.every((Object? k) => k != null), isTrue);
      expect(keys[0], isNot(keys[1]));
    });

    test('NEGATIVE CONTROL — a row carrying only `id`/`conversationId` FAILS '
        'rather than sending to the wrong place', () async {
      final adapter = _adapterFor(
        onConversationRead: () => _json(<String, Object?>{
          'id': kConversationId,
          'conversationId': kConversationId,
        }, 200),
      );

      await expectLater(
        _send(_clientOn(adapter)),
        throwsA(isA<DevGatewayException>()),
      );
      expect(
        adapter.requests.where((RequestOptions r) => r.method == 'POST'
            && r.path.endsWith('/messages')),
        isEmpty,
      );
    });

    test('a 404 on the resolve blames the missing conversation, NOT the '
        'dev-endpoints flag', () async {
      final adapter = _adapterFor(
        onConversationRead: () => _json(<String, Object?>{'status': 404}, 404),
      );

      try {
        await _send(_clientOn(adapter));
        fail('expected a DevGatewayException');
      } on DevGatewayException catch (e) {
        expect(e.statusCode, 404);
        expect(e.message, contains('no conversation is correlated'));
        expect(e.message, isNot(contains('Features:DevEndpoints')));
      }
    });

    test('a 410 is reported as a permanent retirement, not a transient fault',
        () async {
      final adapter = _adapterFor(
        onAppend: () => _json(<String, Object?>{'status': 410}, 410),
      );

      try {
        await _send(_clientOn(adapter));
        fail('expected a DevGatewayException');
      } on DevGatewayException catch (e) {
        expect(e.statusCode, 410);
        expect(e.message, contains('RETIRED'));
      }
    });
  });
}

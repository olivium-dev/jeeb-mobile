import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_delta_reader.dart';

const _conversationId = 'conversation-1';
const _cursor = 'cursor-1';

class _WireDio {
  _WireDio({required this.rawResponse, this.statusCode = 200}) {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          paths.add(options.path);
          final decoded = jsonDecode(rawResponse);
          final response = Response<dynamic>(
            data: decoded,
            statusCode: statusCode,
            requestOptions: options,
          );
          if (statusCode >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(response);
        },
      ),
    );
  }

  final String rawResponse;
  final int statusCode;
  late final Dio dio;
  int requests = 0;
  final List<String> paths = <String>[];
}

DioChatGateway _gateway(_WireDio wire, {String currentUserId = 'user-me'}) {
  final gateway = DioChatGateway(dio: wire.dio, currentUserId: currentUserId);
  addTearDown(gateway.dispose);
  return gateway;
}

Future<ChatHistoryBatch> _read(String raw, {String currentUserId = 'user-me'}) {
  final wire = _WireDio(rawResponse: raw);
  return _gateway(
    wire,
    currentUserId: currentUserId,
  ).loadHistorySince(_conversationId, _cursor);
}

void _expectOneMalformed(ChatHistoryBatch batch) {
  expect(batch.messages, isEmpty);
  expect(batch.malformedCount, 1);
  expect(batch.nextCursor, isNull);
}

void main() {
  test(
    'AC5 presence control: a RESOLVED conversation id DOES issue the '
    'since-route GET and preserves server ids plus the physical-final cursor',
    () async {
      final wire = _WireDio(
        rawResponse: r'''
          {
            "items": [
              {
                "message_id": "srv-1",
                "author_id": "user-them",
                "created_at": "2026-07-26T10:00:00Z",
                "kind": "text",
                "body": "first"
              },
              {
                "message_id": "srv-2",
                "author_id": "user-me",
                "created_at": "2026-07-26T10:01:00Z",
                "kind": "text",
                "body": "second"
              }
            ]
          }
        ''',
      );
      final batch = await _gateway(
        wire,
      ).loadHistorySince(_conversationId, _cursor);

      expect(_conversationId, isNot('new'));
      expect(wire.requests, 1);
      expect(wire.paths, <String>[
        '/v1/conversations/$_conversationId/messages/since/$_cursor',
      ]);
      expect(batch.messages.map((message) => message.id), ['srv-1', 'srv-2']);
      expect(batch.malformedCount, isZero);
      expect(batch.nextCursor, 'srv-2');
    },
  );

  test('D-a absent or blank message_id is rejected and counted', () async {
    for (final raw in <String>[
      r'''
        [{
          "author_id": "user-them",
          "created_at": "2026-07-26T10:00:00Z",
          "kind": "text",
          "body": "missing id"
        }]
      ''',
      r'''
        [{
          "message_id": "",
          "author_id": "user-them",
          "created_at": "2026-07-26T10:00:00Z",
          "kind": "text",
          "body": "blank id"
        }]
      ''',
    ]) {
      _expectOneMalformed(await _read(raw));
    }
  });

  test('D-b a non-string message_id is rejected and counted', () async {
    final batch = await _read(r'''
        [{
          "message_id": 12345,
          "author_id": "user-them",
          "created_at": "2026-07-26T10:00:00Z",
          "kind": "text",
          "body": "wrong id type"
        }]
      ''');
    _expectOneMalformed(batch);
  });

  test('D-c absent author_id with empty currentUserId is rejected before every '
      'row can become isMine', () async {
    final batch = await _read(r'''
          [{
            "message_id": "srv-1",
            "created_at": "2026-07-26T10:00:00Z",
            "kind": "text",
            "body": "missing author"
          }]
        ''', currentUserId: '');
    _expectOneMalformed(batch);
  });

  // D-d / D-e — INVERTED (bilateral empty-thread fix).
  test(
    'D-d absence of all four timestamp aliases still DECODES the message, '
    'anchored on its server position rather than dropped',
    () async {
      final batch = await _read(r'''
          [{
            "message_id": "srv-1",
            "author_id": "user-them",
            "kind": "text",
            "body": "missing timestamp"
          }]
        ''');
      expect(batch.malformedCount, isZero);
      expect(batch.messages.single.id, 'srv-1');
      expect(batch.messages.single.text, 'missing timestamp');
      expect(batch.messages.single.hasServerTimestamp, isFalse);
      // The physical final row decoded cleanly, so the delta cursor advances.
      expect(batch.nextCursor, 'srv-1');
    },
  );

  test(
    'D-e the 0001-01-01 timestamp husk decodes as timestamp-ABSENT, never as a '
    'year-1 send time',
    () async {
      final batch = await _read(r'''
        [{
          "message_id": "srv-1",
          "author_id": "user-them",
          "created_at": "0001-01-01T00:00:00+00:00",
          "kind": "text",
          "body": "ancient timestamp"
        }]
      ''');
      expect(batch.malformedCount, isZero);
      expect(batch.messages.single.hasServerTimestamp, isFalse);
      expect(batch.messages.single.sentAt.year, isNot(1));
    },
  );

  test('D-f an unknown message kind is rejected and counted', () async {
    final batch = await _read(r'''
        [{
          "message_id": "srv-1",
          "author_id": "user-them",
          "created_at": "2026-07-26T10:00:00Z",
          "kind": "some_new_server_kind",
          "body": "unknown kind"
        }]
      ''');
    _expectOneMalformed(batch);
  });

  test('D-g body arrays and numbers are rejected and counted', () async {
    for (final raw in <String>[
      r'''
        [{
          "message_id": "srv-1",
          "author_id": "user-them",
          "created_at": "2026-07-26T10:00:00Z",
          "kind": "text",
          "body": []
        }]
      ''',
      r'''
        [{
          "message_id": "srv-1",
          "author_id": "user-them",
          "created_at": "2026-07-26T10:00:00Z",
          "kind": "text",
          "body": 42
        }]
      ''',
    ]) {
      _expectOneMalformed(await _read(raw));
    }
  });

  test(
    'D-h an envelope with none of items messages or data is flagged',
    () async {
      final batch = await _read(r'''
          {
            "unexpected_messages": [
              {
                "message_id": "srv-1",
                "author_id": "user-them",
                "created_at": "2026-07-26T10:00:00Z",
                "kind": "text",
                "body": "hidden by envelope rename"
              }
            ]
          }
        ''');
      _expectOneMalformed(batch);
    },
  );

  test('D-i a non-map list row is counted so parsed plus malformed equals the '
      'physical wire count', () async {
    final batch = await _read(r'''
          [
            "not-a-map",
            {
              "message_id": "srv-2",
              "author_id": "user-them",
              "created_at": "2026-07-26T10:01:00Z",
              "kind": "text",
              "body": "valid final row"
            }
          ]
        ''');

    expect(batch.messages.map((message) => message.id), ['srv-2']);
    expect(batch.malformedCount, 1);
    expect(batch.messages.length + batch.malformedCount, 2);
    expect(batch.nextCursor, 'srv-2');
  });

  test('AC5 a malformed physical final row yields no cursor and never scans '
      'backward', () async {
    final batch = await _read(r'''
          [
            {
              "message_id": "srv-valid-before-final",
              "author_id": "user-them",
              "created_at": "2026-07-26T10:00:00Z",
              "kind": "text",
              "body": "valid prior row"
            },
            42
          ]
        ''');

    expect(batch.messages.map((message) => message.id), [
      'srv-valid-before-final',
    ]);
    expect(batch.malformedCount, 1);
    expect(batch.nextCursor, isNull);
  });

  test('D-j a blank cursor is rejected before it reaches the wire', () async {
    final wire = _WireDio(rawResponse: r'''{"wire_reached": true}''');
    final gateway = _gateway(wire);

    for (final cursor in <String>['', '   ']) {
      await expectLater(
        gateway.loadHistorySince(_conversationId, cursor),
        throwsA(isA<ArgumentError>()),
      );
    }
    expect(wire.requests, isZero);
    expect(wire.paths, isEmpty);
  });

  test(
    'D-k slash and percent cursors are encoded as one path segment',
    () async {
      for (final entry in <(String, String)>[('/', '%2F'), ('%', '%25')]) {
        final wire = _WireDio(
          rawResponse: r'''
          [{
            "message_id": "srv-1",
            "author_id": "user-them",
            "created_at": "2026-07-26T10:00:00Z",
            "kind": "text",
            "body": "encoded cursor"
          }]
        ''',
        );
        final batch = await _gateway(
          wire,
        ).loadHistorySince(_conversationId, entry.$1);

        expect(wire.requests, 1);
        expect(
          wire.paths.single,
          '/v1/conversations/$_conversationId/messages/since/${entry.$2}',
        );
        expect(batch.messages, hasLength(1));
      }
    },
  );

  test('D-l a 403 surfaces and the requested cursor is unchanged', () async {
    final wire = _WireDio(
      rawResponse: r'''{"error": "forbidden"}''',
      statusCode: 403,
    );
    final gateway = _gateway(wire);

    await expectLater(
      gateway.loadHistorySince(_conversationId, _cursor),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    expect(wire.requests, 1);
    expect(wire.paths.single, endsWith('/since/$_cursor'));
  });

  test('D-m a 503 remains observable to the caller', () async {
    final wire = _WireDio(
      rawResponse: r'''{"error": "chat disabled"}''',
      statusCode: 503,
    );
    final gateway = _gateway(wire);

    await expectLater(
      gateway.loadHistorySince(_conversationId, _cursor),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    expect(wire.requests, 1);
  });

  test(
    'AC5 unresolved conversations short-circuit the delta route exactly like '
    'full history',
    () async {
      final wire = _WireDio(rawResponse: r'''{"wire_reached": true}''');
      final batch = await _gateway(wire).loadHistorySince('new', _cursor);

      expect(wire.requests, isZero);
      expect(batch.messages, isEmpty);
      expect(batch.malformedCount, isZero);
      expect(batch.nextCursor, isNull);
    },
  );

  test(
    'AC5 loadHistory keeps its List signature while using the shared decoder',
    () async {
      final wire = _WireDio(
        rawResponse: r'''
          [{
            "message_id": "srv-full-1",
            "author_id": "user-them",
            "created_at": "2026-07-26T10:00:00Z",
            "kind": "text",
            "body": "full history"
          }]
        ''',
      );
      final messages = await _gateway(wire).loadHistory(_conversationId);

      expect(messages.map((message) => message.id), ['srv-full-1']);
      expect(wire.paths.single, '/v1/conversations/$_conversationId/messages');
    },
  );
}

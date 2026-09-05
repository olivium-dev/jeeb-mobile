// The inbox read THROWS a classified failure; it never answers "no rows" for
// a failure (EP-02 / ES-01, at its source).

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_conversations_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

DioException _dioError(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/v1/requests'),
      type: type,
    );

Dio _dio(Future<ResponseBody> Function(RequestOptions) respond) =>
    Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = _ScriptedAdapter(respond)
      ..transformer = SyncTransformer();

void main() {
  test('a 200 envelope decodes into rows', () async {
    final repo = DioChatConversationsRepository(
      _dio((_) async => _json(
            '{"items":[{"id":"r1","status":"InTransit","title":"Pharmacy"}]}',
            200,
          )),
    );

    final page = await repo.fetchConversations();

    expect(page.conversations, hasLength(1));
    expect(page.conversations.single.requestId, 'r1');
    expect(page.conversations.single.status, OrderRequestStatus.enRoute);
    expect(page.skippedRows, 0);
  });

  test('a 503 throws a ServerFailure — never an empty page', () async {
    final repo = DioChatConversationsRepository(
      _dio((_) async => _json('{"items":[]}', 503)),
    );

    await expectLater(
      repo.fetchConversations(),
      throwsA(isA<ServerFailure>().having((f) => f.status, 'status', 503)),
    );
  });

  test('a connection error throws a NetworkFailure', () async {
    final repo = DioChatConversationsRepository(
      _dio((_) async => throw _dioError(DioExceptionType.connectionError)),
    );

    await expectLater(
      repo.fetchConversations(),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('a receive timeout throws a TimeoutFailure', () async {
    final repo = DioChatConversationsRepository(
      _dio((_) async => throw _dioError(DioExceptionType.receiveTimeout)),
    );

    await expectLater(
      repo.fetchConversations(),
      throwsA(isA<TimeoutFailure>()),
    );
  });

  test('a body that is not the expected shape throws, and marks parse',
      () async {
    // A top-level JSON ARRAY: the `Map<String, dynamic>` response type cannot
    // hold it, and the resulting TypeError used to strand the tab loading.
    final repo = DioChatConversationsRepository(
      _dio((_) async => _json('[1,2,3]', 200)),
    );

    await expectLater(
      repo.fetchConversations(),
      throwsA(isA<UnknownFailure>().having((f) => f.parse, 'parse', isTrue)),
    );
  });

  test('a row with neither id is counted, not silently dropped', () async {
    final repo = DioChatConversationsRepository(
      _dio((_) async => _json(
            '{"items":[{"id":"r1","status":"Accepted"},{"status":"Accepted"}]}',
            200,
          )),
    );

    final page = await repo.fetchConversations();

    expect(page.conversations, hasLength(1));
    expect(page.skippedRows, 1);
  });

  test('a row WITHOUT conversationId still survives (SHELL-02)', () async {
    final repo = DioChatConversationsRepository(
      _dio((_) async =>
          _json('{"items":[{"id":"r1","status":"Ordered"}]}', 200)),
    );

    final page = await repo.fetchConversations();

    expect(page.conversations.single.conversationId, isEmpty);
    expect(page.conversations.single.chatRouteId, 'r1');
  });

  // Contract drift, not an empty inbox: a 200 that lost its envelope must not
  // decode to "No conversations yet".
  test('a 200 whose body has no items list throws parse', () async {
    for (final String body in const <String>['{}', '{"items":null}']) {
      final repo = DioChatConversationsRepository(
        _dio((_) async => _json(body, 200)),
      );

      await expectLater(
        repo.fetchConversations(),
        throwsA(isA<UnknownFailure>().having((f) => f.parse, 'parse', isTrue)),
      );
    }
  });

  test('an empty 200 is an EMPTY page, and that is the only way to get one',
      () async {
    final repo = DioChatConversationsRepository(
      _dio((_) async => _json('{"items":[]}', 200)),
    );

    final page = await repo.fetchConversations();

    expect(page.conversations, isEmpty);
    expect(page.skippedRows, 0);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final script in <List<int>>[
    [400],
    [409],
    [500],
    [503, 503, 503],
    [404, 404],
    [503, 200],
    [404, 200],
    [429],
  ]) {
    test('production profile wire script $script', () async {
      final transport = _LocalTransport(script);
      final logs = <String>[];
      final originalPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final dio = MockGatewayClient.createDio(
            baseUrl: 'https://profile-wire.invalid',
            tokenStore: _EmptyTokens(),
          );
          try {
            Future<void> read(int expectedStatus) async {
              if (expectedStatus == 200) {
                final response = await dio.get<dynamic>('/v1/users/me');
                expect(response.statusCode, 200);
              } else {
                await expectLater(
                  dio.get<dynamic>('/v1/users/me'),
                  throwsA(
                    isA<DioException>().having(
                      (error) => error.response?.statusCode,
                      'terminal status',
                      expectedStatus,
                    ),
                  ),
                );
              }
            }

            await read(script.last);
            expect(transport.arrivals.map((entry) => entry.status), script);
            final expectedPaths = script.first == 404
                ? ['/v1/users/me', '/users/me']
                : List.filled(script.length, '/v1/users/me');
            expect(
              transport.arrivals.map((entry) => entry.path),
              expectedPaths,
            );
            expect(
              transport.arrivals.map((entry) => entry.requestId).toSet(),
              hasLength(1),
            );
            expect(transport.arrivals.first.requestId, isNotEmpty);
            final sends = logs.where((line) => line.startsWith('[http→]'));
            expect(sends, hasLength(script.length));
            for (var index = 0; index < expectedPaths.length; index++) {
              expect(
                sends.elementAt(index),
                contains('GET ${expectedPaths[index]}'),
              );
            }
            if (script.last == 200) {
              expect(
                logs.where((line) => line.startsWith('[http←]')),
                isNotEmpty,
              );
              expect(
                logs.where((line) => line.startsWith('[http✗]')).length,
                lessThan(transport.arrivals.length),
              );
            }
            if (script.first == 429) {
              final before = logs.length;
              await expectLater(
                dio.get<dynamic>('/v1/users/me'),
                throwsA(isA<DioException>()),
              );
              expect(transport.arrivals, hasLength(1));
              expect(
                logs.skip(before).where((line) => line.startsWith('[http→]')),
                isEmpty,
              );
              expect(
                logs.skip(before).where((line) => line.startsWith('[http✗]')),
                isNotEmpty,
              );
            }
            expect(transport.clients, hasLength(script.first == 503 ? 2 : 1));
          } finally {
            MockGatewayClient.disposeDio(dio);
          }
          expect(transport.clients.every((client) => client.closed), isTrue);
          expect(transport.unexpectedCalls, isEmpty);
        }, transport);
      } finally {
        debugPrint = originalPrint;
      }
    });
  }

  for (final target in ['headers', 'response']) {
    test('journals swallowed unsupported replay $target operation', () async {
      final logs = <String>[];
      final originalPrint = debugPrint;
      addTearDown(() => debugPrint = originalPrint);
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      final transport = _LocalTransport(
        [404, 404],
        beforeReplayHeaders: (response) {
          if (target == 'headers') {
            expect(response._headers.contentType, isNull);
          } else {
            expect(response.persistentConnection, isFalse);
          }
        },
      );
      await HttpOverrides.runWithHttpOverrides(() async {
        final dio = MockGatewayClient.createDio(
          baseUrl: 'https://profile-wire.invalid',
          tokenStore: _EmptyTokens(),
        );
        try {
          await expectLater(
            dio.get<dynamic>('/v1/users/me'),
            throwsA(
              isA<DioException>()
                  .having((error) => error.response?.statusCode, 'status', 404)
                  .having(
                    (error) => error.requestOptions.path,
                    'original request path',
                    '/v1/users/me',
                  ),
            ),
          );
          expect(transport.arrivals.map((entry) => entry.status), [404, 404]);
          expect(transport.arrivals.map((entry) => entry.path), [
            '/v1/users/me',
            '/users/me',
          ]);
          expect(
            logs.where((line) => line.startsWith('[http→]')),
            hasLength(2),
          );
        } finally {
          MockGatewayClient.disposeDio(dio);
        }
        expect(transport.clients.every((client) => client.closed), isTrue);
        expect(transport.unexpectedCalls, [
          target == 'headers'
              ? 'HttpHeaders.${#contentType}'
              : 'HttpClientResponse.${#persistentConnection}',
        ]);
      }, transport);
    });
  }
}

class _EmptyTokens extends AuthTokenStore {
  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
}

class _Arrival {
  _Arrival(this.path, this.status, this.requestId);
  final String path;
  final int status;
  final String requestId;
}

class _LocalTransport extends HttpOverrides {
  _LocalTransport(this.statuses, {this.beforeReplayHeaders});
  final List<int> statuses;
  final void Function(_Response)? beforeReplayHeaders;
  final arrivals = <_Arrival>[];
  final unexpectedCalls = <String>[];
  final clients = <_LocalClient>[];

  Never reject(String call) {
    unexpectedCalls.add(call);
    throw StateError('Unscripted local transport call: $call');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = _LocalClient(this);
    clients.add(client);
    return client;
  }

  HttpClientResponse arrive(String method, Uri uri, _Headers headers) {
    final index = arrivals.length;
    final path = statuses.first == 404 && index == 1
        ? '/users/me'
        : '/v1/users/me';
    if (index >= statuses.length ||
        method != 'GET' ||
        uri != Uri.parse('https://profile-wire.invalid$path')) {
      reject('$method ${uri.path}');
    }
    final status = statuses[index];
    arrivals.add(
      _Arrival(uri.path, status, headers.value('x-request-id') ?? ''),
    );
    return _Response(
      this,
      status,
      beforeHeaders: index == 1 ? beforeReplayHeaders : null,
    );
  }
}

class _LocalClient implements HttpClient {
  _LocalClient(this.transport);
  final _LocalTransport transport;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (closed) transport.reject('open after close');
    return _Request(transport, method, url);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      transport.reject('HttpClient.${invocation.memberName}');
}

class _Request implements HttpClientRequest {
  _Request(this.transport, this.method, this.uri)
    : headers = _Headers(transport);
  final _LocalTransport transport;
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final _Headers headers;
  @override
  bool followRedirects = false;
  @override
  int maxRedirects = 0;
  @override
  bool persistentConnection = false;
  @override
  Future<HttpClientResponse> close() async =>
      transport.arrive(method, uri, headers);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      transport.reject('HttpClientRequest.${invocation.memberName}');
}

class _Headers implements HttpHeaders {
  _Headers(this.transport);
  final _LocalTransport transport;
  final values = <String, List<String>>{};
  // Dio reads this runtime HttpHeaders getter dynamically.
  String get protocolVersion => '1.1';
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = [value.toString()];
  }

  @override
  String? value(String name) => values[name.toLowerCase()]?.single;
  @override
  void forEach(void Function(String, List<String>) action) =>
      values.forEach(action);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      transport.reject('HttpHeaders.${invocation.memberName}');
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.transport, this.statusCode, {this.beforeHeaders})
    : _headers = _Headers(transport) {
    _headers.set('content-type', 'application/json');
    if (statusCode == 429) _headers.set('retry-after', '30');
  }
  final _LocalTransport transport;
  final void Function(_Response)? beforeHeaders;
  final _Headers _headers;
  @override
  final int statusCode;
  @override
  _Headers get headers {
    beforeHeaders?.call(this);
    return _headers;
  }

  @override
  int get contentLength => 2;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  String get reasonPhrase => 'Local scripted response';
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  X509Certificate? get certificate => null;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(utf8.encode('{}')).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      transport.reject('HttpClientResponse.${invocation.memberName}');
}

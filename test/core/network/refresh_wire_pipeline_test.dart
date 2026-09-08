import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/auth_interceptor.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/core/session/auth_loss_signals.dart';

const _oldAccess = 'factory-old-access-credential-canary';
const _oldRefresh = 'factory-old-refresh-credential-canary';
const _newAccess = 'factory-new-access-credential-canary';
const _newRefresh = 'factory-new-refresh-credential-canary';
const _headerCanary = 'factory-response-header-canary';
const _nestedCanary = 'factory-nested-response-canary';
const _compatCanary = 'factory-compat-error-body-canary';
const _failureCanary = 'factory-refresh-failure-raw-body-canary';
const _failureHeaderCanary = 'factory-refresh-failure-header-canary';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final compatibilityReplay in [false, true]) {
    test(
      compatibilityReplay
          ? 'factory refresh 404 compatibility replay has two private sends'
          : 'factory ten concurrent 401s share one private refresh and replay',
      () async {
        final count = compatibilityReplay ? 1 : 10;
        final transport = _RefreshTransport(count, compatibilityReplay);
        final tokens = _Tokens();
        final logs = <String>[];
        final originalPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };
        try {
          await HttpOverrides.runWithHttpOverrides(() async {
            final dio = MockGatewayClient.createDio(
              baseUrl: 'https://refresh-wire.invalid',
              tokenStore: tokens,
            );
            try {
              final pending = _settle(
                Future.wait([
                  for (var index = 0; index < count; index++)
                    dio.get<dynamic>('/v1/users/me'),
                ]),
              );
              // All old-bearer requests arrive before any 401 is released;
              // refresh waits until those arrivals are independently checked.
              await transport.refreshStarted.future.timeout(
                const Duration(seconds: 5),
              );
              expect(transport.oldReads, count);
              expect(transport.newReads, 0);
              expect(tokens.saves, 0);
              transport.releaseRefresh.complete();
              final outcome = await pending.timeout(const Duration(seconds: 5));
              expect(outcome, isA<List<Response<dynamic>>>());
              final responses = outcome as List<Response<dynamic>>;
              expect(responses, hasLength(count));
              expect(
                responses.every((response) => response.statusCode == 200),
                isTrue,
              );
              expect(tokens.saves, 1);
              expect(tokens.clears, 0);
              expect(await tokens.accessToken, _newAccess);
              expect(await tokens.refreshToken, _newRefresh);
              expect(await tokens.userId, 'factory-user');
              expect(transport.oldReads, count);
              expect(transport.newReads, count);
              final refreshArrivals = transport.arrivals
                  .where((arrival) => arrival.method == 'POST')
                  .toList();
              final refreshPaths = [
                '/v1/auth/refresh',
                if (compatibilityReplay) '/auth/refresh',
              ];
              expect(
                refreshArrivals.map((arrival) => arrival.path),
                refreshPaths,
              );
              expect(
                refreshArrivals.map((arrival) => arrival.status),
                compatibilityReplay ? [404, 200] : [200],
              );
              expect(
                transport.arrivals,
                hasLength(2 * count + refreshPaths.length),
              );

              // This ledger comes only from debugPrint, never the transport.
              final outgoing = logs
                  .where((line) => line.startsWith('[http→]'))
                  .toList();
              expect(outgoing, hasLength(2 * count + refreshPaths.length));
              expect(
                outgoing.where((line) => line.contains('POST ')),
                refreshPaths.map((path) => '[http→] POST $path'),
              );
              final refreshLogs = logs
                  .where(
                    (line) =>
                        line.startsWith('[http') && line.contains('POST '),
                  )
                  .toList();
              expect(
                refreshLogs.where((line) => line.startsWith('[http←]')),
                isNotEmpty,
              );
              for (final line in refreshLogs) {
                expect(
                  RegExp(
                    r'^\[http(?:→|←|✗)\] (?:200 )?POST /(?:v1/)?auth/refresh$',
                  ).hasMatch(line),
                  isTrue,
                  reason: 'Refresh logs must contain only exact metadata',
                );
              }
              final completeCapture = logs.join('\n');
              for (final canary in [
                _oldAccess,
                _oldRefresh,
                _newAccess,
                _newRefresh,
                _headerCanary,
                _nestedCanary,
                _compatCanary,
              ]) {
                expect(
                  completeCapture.contains(canary),
                  isFalse,
                  reason: 'Credential or payload canary escaped into logs',
                );
              }
              expect(transport.clients, hasLength(3));
            } finally {
              if (!transport.releaseRefresh.isCompleted) {
                transport.releaseRefresh.complete();
              }
              MockGatewayClient.disposeDio(dio);
              expect(
                transport.clients.every((client) => client.closed),
                isTrue,
              );
              expect(transport.unexpectedCalls, isEmpty);
            }
          }, transport);
        } finally {
          debugPrint = originalPrint;
        }
      },
    );
  }

  for (final refreshStatus in [401, 503]) {
    test(
      'factory refresh $refreshStatus preserves private failure semantics',
      () async {
        final terminal = refreshStatus == 401;
        final transport = _RefreshTransport(
          1,
          false,
          failureStatus: refreshStatus,
        );
        final tokens = _Tokens();
        final logs = <String>[];
        final losses = <AuthLossReason>[];
        final signals = AuthLossSignals.instance;
        signals.clearReason();
        final subscription = signals.stream.listen(losses.add);
        final originalPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };
        try {
          await HttpOverrides.runWithHttpOverrides(() async {
            final dio = MockGatewayClient.createDio(
              baseUrl: 'https://refresh-wire.invalid',
              tokenStore: tokens,
            );
            try {
              final pending = _settle(dio.get<dynamic>('/v1/users/me'));
              await transport.refreshStarted.future.timeout(
                const Duration(seconds: 5),
              );
              expect(transport.oldReads, 1);
              expect(transport.newReads, 0);
              expect(tokens.saves, 0);
              expect(tokens.clears, 0);
              transport.releaseRefresh.complete();
              final first = await pending.timeout(const Duration(seconds: 5));
              _expectOriginal401(first, recovering: !terminal);
              expect(transport.arrivals.map((arrival) => arrival.status), [
                401,
                refreshStatus,
              ]);
              expect(transport.arrivals.map((arrival) => arrival.method), [
                'GET',
                'POST',
              ]);
              expect(transport.arrivals.map((arrival) => arrival.path), [
                '/v1/users/me',
                '/v1/auth/refresh',
              ]);

              if (!terminal) {
                // The next GET still reaches the server; only refresh is local.
                transport.allowCooldownRead = true;
                final second = await _settle(
                  dio.get<dynamic>('/v1/users/me'),
                ).timeout(const Duration(seconds: 5));
                _expectOriginal401(second, recovering: true);
                expect(transport.arrivals.map((arrival) => arrival.status), [
                  401,
                  503,
                  401,
                ]);
                expect(transport.arrivals.map((arrival) => arrival.method), [
                  'GET',
                  'POST',
                  'GET',
                ]);
                expect(transport.arrivals.last.path, '/v1/users/me');
              }
              expect(tokens.saves, 0);
              expect(tokens.clears, terminal ? 1 : 0);
              expect(await tokens.accessToken, terminal ? null : _oldAccess);
              expect(await tokens.refreshToken, terminal ? null : _oldRefresh);
              expect(await tokens.userId, terminal ? null : 'factory-user');
              expect(
                losses,
                terminal ? [AuthLossReason.sessionExpired] : isEmpty,
              );
              expect(
                signals.lastReason,
                terminal ? AuthLossReason.sessionExpired : null,
              );
              expect(transport.oldReads, terminal ? 1 : 2);
              expect(transport.newReads, 0);
              expect(transport.refreshPosts, 1);
              expect(transport.arrivals, hasLength(terminal ? 2 : 3));

              final outgoing = logs
                  .where((line) => line.startsWith('[http→]'))
                  .toList();
              expect(outgoing, hasLength(terminal ? 2 : 3));
              expect(outgoing.where((line) => line.contains('POST ')), [
                '[http→] POST /v1/auth/refresh',
              ]);
              final refreshLogs = logs.where(
                (line) => line.startsWith('[http') && line.contains('POST '),
              );
              expect(refreshLogs, [
                '[http→] POST /v1/auth/refresh',
                '[http✗] POST /v1/auth/refresh',
              ]);
              final completeCapture = logs.join('\n');
              for (final canary in [
                _oldAccess,
                _oldRefresh,
                _newAccess,
                _newRefresh,
                _headerCanary,
                _failureCanary,
                _failureHeaderCanary,
              ]) {
                expect(
                  completeCapture.contains(canary),
                  isFalse,
                  reason: 'Credential or failure canary escaped into logs',
                );
              }
              expect(transport.clients, hasLength(2));
            } finally {
              if (!transport.releaseRefresh.isCompleted) {
                transport.releaseRefresh.complete();
              }
              MockGatewayClient.disposeDio(dio);
              expect(
                transport.clients.every((client) => client.closed),
                isTrue,
              );
              expect(transport.unexpectedCalls, isEmpty);
            }
          }, transport);
        } finally {
          debugPrint = originalPrint;
          await subscription.cancel();
          signals.clearReason();
        }
      },
    );
  }
}

Future<Object?> _settle<T>(Future<T> pending) => pending.then<Object?>(
  (value) => value,
  onError: (Object error, StackTrace stack) => error,
);

void _expectOriginal401(Object? outcome, {required bool recovering}) {
  expect(outcome, isA<DioException>());
  final error = outcome as DioException;
  expect(error.response?.statusCode, 401);
  expect(error.requestOptions.method, 'GET');
  expect(error.requestOptions.path, '/v1/users/me');
  expect(error.response?.data, <String, dynamic>{});
  expect(
    error.requestOptions.extra[TokenRefreshInterceptor.recoveringFlag],
    recovering ? true : null,
  );
}

class _Tokens extends AuthTokenStore {
  String? _access = _oldAccess;
  String? _refresh = _oldRefresh;
  String? _user = 'factory-user';
  int saves = 0;
  int clears = 0;
  @override
  Future<String?> get accessToken async => _access;
  @override
  Future<String?> get refreshToken async => _refresh;
  @override
  Future<String?> get userId async => _user;
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    saves++;
    _access = accessToken;
    _refresh = refreshToken;
    if (userId != null) _user = userId;
  }

  @override
  Future<void> clear() async {
    clears++;
    _access = null;
    _refresh = null;
    _user = null;
  }
}

class _Arrival {
  _Arrival(this.method, this.path, this.status);
  final String method;
  final String path;
  final int status;
}

class _RefreshTransport extends HttpOverrides {
  _RefreshTransport(this.count, this.compatibilityReplay, {this.failureStatus});
  final int count;
  final bool compatibilityReplay;
  final int? failureStatus;
  bool allowCooldownRead = false;
  final arrivals = <_Arrival>[];
  final unexpectedCalls = <String>[];
  final clients = <_Client>[];
  final allOldReads = Completer<void>();
  final refreshStarted = Completer<void>();
  final releaseRefresh = Completer<void>();
  int oldReads = 0;
  int newReads = 0;
  int refreshPosts = 0;

  Never reject(String member) {
    unexpectedCalls.add(member);
    throw StateError('Unscripted local transport call: $member');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = _Client(this);
    clients.add(client);
    return client;
  }

  Future<HttpClientResponse> arrive(_Request request) async {
    final path = request.uri.path;
    if (request.uri != Uri.parse('https://refresh-wire.invalid$path')) {
      reject('unexpected origin, query, or fragment');
    }
    if (request.method == 'GET' && path == '/v1/users/me') {
      if (request.bytes.isNotEmpty) reject('GET body');
      final bearer = request.headers.value('authorization');
      if (bearer == 'Bearer $_oldAccess') {
        if (allowCooldownRead) {
          if (failureStatus != 503 ||
              oldReads != 1 ||
              refreshPosts != 1 ||
              !releaseRefresh.isCompleted) {
            reject('unexpected cooldown read');
          }
          oldReads++;
          arrivals.add(_Arrival('GET', path, 401));
          return _Response(this, 401, '{}');
        }
        if (++oldReads > count || refreshPosts != 0) reject('extra old read');
        arrivals.add(_Arrival('GET', path, 401));
        if (oldReads == count) allOldReads.complete();
        await allOldReads.future;
        return _Response(this, 401, '{}');
      }
      if (bearer == 'Bearer $_newAccess') {
        if (failureStatus != null) reject('replay after refresh failure');
        if (++newReads > count || !releaseRefresh.isCompleted) {
          reject('extra or premature new read');
        }
        arrivals.add(_Arrival('GET', path, 200));
        return _Response(this, 200, '{}');
      }
      reject('unexpected profile bearer');
    }
    final expectedPath = refreshPosts == 0
        ? '/v1/auth/refresh'
        : '/auth/refresh';
    if (request.method != 'POST' ||
        path != expectedPath ||
        refreshPosts >= (compatibilityReplay ? 2 : 1) ||
        oldReads != count) {
      reject('unexpected method, path, or refresh count');
    }
    final dynamic payload;
    try {
      payload = jsonDecode(utf8.decode(request.bytes));
    } catch (_) {
      reject('invalid refresh encoding');
    }
    if (payload is! Map ||
        payload.length != 1 ||
        payload['refreshToken'] != _oldRefresh) {
      reject('unexpected refresh bytes');
    }
    if (request.headers.value('authorization') != null) {
      reject('unexpected refresh authorization');
    }
    final status =
        failureStatus ?? (compatibilityReplay && refreshPosts == 0 ? 404 : 200);
    refreshPosts++;
    arrivals.add(_Arrival('POST', path, status));
    if (!refreshStarted.isCompleted) refreshStarted.complete();
    await releaseRefresh.future;
    if (failureStatus != null) {
      return _Response(
        this,
        status,
        '$_failureCanary-$status',
        rawFailure: true,
      );
    }
    return _Response(
      this,
      status,
      status == 404
          ? _compatCanary
          : jsonEncode({
              'accessToken': _newAccess,
              'refreshToken': _newRefresh,
              'unrecognized': {'nested': _nestedCanary},
            }),
    );
  }
}

class _Client implements HttpClient {
  _Client(this.transport);
  final _RefreshTransport transport;
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
  final _RefreshTransport transport;
  final bytes = <int>[];
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
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() => transport.arrive(this);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      transport.reject('HttpClientRequest.${invocation.memberName}');
}

class _Headers implements HttpHeaders {
  _Headers(this.transport);
  final _RefreshTransport transport;
  final values = <String, List<String>>{};
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
  _Response(
    this.transport,
    this.statusCode,
    String body, {
    bool rawFailure = false,
  }) : bytes = utf8.encode(body),
       headers = _Headers(transport) {
    headers.set(
      'content-type',
      statusCode == 404 || rawFailure ? 'text/plain' : 'application/json',
    );
    headers.set('x-private-canary', _headerCanary);
    if (rawFailure) headers.set('x-failure-canary', _failureHeaderCanary);
  }
  final _RefreshTransport transport;
  final List<int> bytes;
  @override
  final _Headers headers;
  @override
  final int statusCode;
  @override
  int get contentLength => bytes.length;
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
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      transport.reject('HttpClientResponse.${invocation.memberName}');
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import '../support/sync_app_localizations.dart';

const _startupConsumers = ['RoleSync.sync', 'GreetingProfileCubit.load'];
const _consumers = [..._startupConsumers, 'CustomerProfileCubit.load'];

void main() {
  setUp(() async {
    await sl.reset();
    await NetworkReachabilitySignals.debugReset();
    SharedPreferences.setMockInitialValues({'app.onboarding.completed': true});
  });

  tearDown(() async {
    await sl.reset();
    await NetworkReachabilitySignals.debugReset();
  });

  for (final status in [400, 409, 500, 503, 404]) {
    testWidgets('production app attributes profile wire status $status', (
      tester,
    ) async {
      final transport = _LocalTransport(status);
      final logs = <String>[];
      final originalPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final production = MockGatewayClient.createDio(
            baseUrl: 'https://profile-wire.invalid',
            tokenStore: _EmptyTokens(),
          );
          final spy = _AttributionDio(production, transport);
          sl.registerSingleton<Dio>(spy);
          try {
            await tester.pumpWidget(
              JeebApp(
                preferences: await SharedPreferences.getInstance(),
                localizationsDelegateOverride:
                    const SyncAppLocalizationsDelegate(),
                sessionGate: const AlwaysAuthenticatedSessionGate(),
              ),
            );
            for (var frame = 0; frame < 80; frame++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(find.byType(ShellScreen), findsOneWidget);
            expect(spy.roots, hasLength(2));
            expect(spy.roots.every((root) => root.completed), isTrue);
            for (final consumer in _startupConsumers) {
              expect(
                spy.roots.where((root) => root.stack.contains(consumer)),
                hasLength(1),
                reason: '$consumer must account for one completed startup read',
              );
            }
            expect(
              spy.roots.where(
                (root) => root.stack.contains('CustomerProfileCubit.load'),
              ),
              isEmpty,
              reason: 'The hidden Profile tab must not read eagerly',
            );
            final startupIds = spy.roots.map((root) => root.requestId).toSet();
            expect(startupIds, hasLength(2));
            expect(
              startupIds.every((id) => id != null && id.isNotEmpty),
              isTrue,
            );
            expect(spy.roots.map((root) => root.status), everyElement(status));
            final arrivalsBeforeProfile = transport.arrivals.length;
            final logsBeforeProfile = logs.length;
            for (var frame = 0; frame < 20; frame++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              spy.roots,
              hasLength(2),
              reason: 'No hidden profile polling',
            );
            expect(transport.arrivals, hasLength(arrivalsBeforeProfile));
            expect(
              logs
                  .skip(logsBeforeProfile)
                  .where((line) => line.startsWith('[http→]')),
              isEmpty,
              reason: 'Completed startup reads must remain quiet',
            );

            await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
            for (var frame = 0; frame < 80; frame++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(spy.roots, hasLength(3));
            expect(spy.roots.last.stack, contains('CustomerProfileCubit.load'));
            expect(startupIds, isNot(contains(spy.roots.last.requestId)));
            expect(spy.roots.every((root) => root.completed), isTrue);
            for (final consumer in _consumers) {
              expect(
                spy.roots.where((root) => root.stack.contains(consumer)),
                hasLength(1),
                reason: '$consumer must account for one completed read',
              );
            }
            final ids = spy.roots.map((root) => root.requestId).toSet();
            expect(ids, hasLength(3));
            expect(ids.every((id) => id != null && id.isNotEmpty), isTrue);
            expect(spy.roots.map((root) => root.status), everyElement(status));

            final expectedPathsPerRoot = switch (status) {
              503 => ['/v1/users/me', '/v1/users/me', '/v1/users/me'],
              404 => ['/v1/users/me', '/users/me'],
              _ => ['/v1/users/me'],
            };
            final profile = transport.arrivals
                .where(
                  (arrival) =>
                      arrival.uri.path == '/v1/users/me' ||
                      arrival.uri.path == '/users/me',
                )
                .toList();
            expect(
              profile.map((arrival) => arrival.status),
              everyElement(status),
            );
            expect(profile.map((arrival) => arrival.requestId).toSet(), ids);
            for (final root in spy.roots) {
              expect(
                profile
                    .where((arrival) => arrival.requestId == root.requestId)
                    .map((arrival) => arrival.uri.path)
                    .toList(),
                expectedPathsPerRoot,
                reason: 'Each actual consumer owns its ordered route attempts',
              );
            }
            final sends = logs
                .where((line) => line.startsWith('[http→] GET '))
                .map((line) => line.split(' ')[2])
                .where((path) => path == '/v1/users/me' || path == '/users/me')
                .toList();
            expect(sends, profile.map((arrival) => arrival.uri.path).toList());
            for (final path in ['/v1/users/me', '/users/me']) {
              final expectedCount =
                  spy.roots.length *
                  expectedPathsPerRoot.where((route) => route == path).length;
              expect(
                profile.where((arrival) => arrival.uri.path == path),
                hasLength(expectedCount),
                reason: 'Transport arrival count for $path',
              );
              expect(
                sends.where((route) => route == path),
                hasLength(expectedCount),
                reason: 'Independent outgoing app log count for $path',
              );
            }

            final arrivalsBeforeQuiet = transport.arrivals.length;
            final logsBeforeQuiet = logs.length;
            for (var frame = 0; frame < 20; frame++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              spy.roots,
              hasLength(3),
              reason: 'No additional consumer after showing Profile',
            );
            expect(transport.arrivals, hasLength(arrivalsBeforeQuiet));
            expect(
              logs
                  .skip(logsBeforeQuiet)
                  .where((line) => line.startsWith('[http→]')),
              isEmpty,
              reason: 'Outgoing traffic must remain quiet after completion',
            );
            expect(tester.takeException(), isNull);
          } finally {
            try {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(milliseconds: 200));
            } finally {
              MockGatewayClient.disposeDio(production);
            }
          }
          expect(transport.clients, hasLength(status == 503 ? 2 : 1));
          expect(transport.clients.every((client) => client.closed), isTrue);
          expect(transport.unexpectedCalls, isEmpty);
        }, transport);
      } finally {
        debugPrint = originalPrint;
      }
    });
  }
}

class _Root {
  _Root(this.stack);
  final String stack;
  bool completed = false;
  int? status;
  String? requestId;

  void finish(RequestOptions options, int? responseStatus) {
    completed = true;
    status = responseStatus;
    requestId = options.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'x-request-id')
        .map((entry) => entry.value.toString())
        .single;
  }
}

class _AttributionDio implements Dio {
  _AttributionDio(this.production, this.transport);
  final Dio production;
  final _LocalTransport transport;
  final roots = <_Root>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    final root = path == '/v1/users/me'
        ? _Root(StackTrace.current.toString())
        : null;
    if (root != null) roots.add(root);
    return _forward<T>(
      root,
      path,
      data,
      queryParameters,
      options,
      cancelToken,
      onReceiveProgress,
    );
  }

  Future<Response<T>> _forward<T>(
    _Root? root,
    String path,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  ) async {
    try {
      final response = await production.get<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      root?.finish(response.requestOptions, response.statusCode);
      return response;
    } on DioException catch (error) {
      root?.finish(error.requestOptions, error.response?.statusCode);
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      transport.reject('Dio.${invocation.memberName}');
}

class _EmptyTokens extends AuthTokenStore {
  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
}

class _Arrival {
  _Arrival(this.uri, this.status, this.requestId);
  final Uri uri;
  final int status;
  final String requestId;
}

class _LocalTransport extends HttpOverrides {
  _LocalTransport(this.profileStatus);
  final int profileStatus;
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
    if (method != 'GET' ||
        uri.scheme != 'https' ||
        uri.host != 'profile-wire.invalid' ||
        uri.port != 443) {
      reject('$method $uri');
    }
    final int status;
    switch (uri.path) {
      case '/v1/users/me':
        if (uri.hasQuery) reject('Profile query ${uri.query}');
        status = profileStatus;
      case '/users/me':
        if (profileStatus != 404 || uri.hasQuery) {
          reject('Unscripted profile fallback $uri');
        }
        final prior = arrivals
            .where(
              (arrival) =>
                  arrival.requestId == headers.value('x-request-id') &&
                  (arrival.uri.path == '/v1/users/me' ||
                      arrival.uri.path == '/users/me'),
            )
            .toList();
        if (prior.length != 1 ||
            prior.single.uri.path != '/v1/users/me' ||
            prior.single.status != 404) {
          reject('Fallback requires one versioned 404 for the same root');
        }
        status = 404;
      case '/v1/requests':
        if (!mapEquals(uri.queryParameters, const <String, String>{
          'status': 'active',
          'page': '1',
          'pageSize': '20',
        })) {
          reject('Unscripted active requests query ${uri.query}');
        }
        status = 400;
      case '/requests':
      case '/deliveries':
      case '/v1/notifications':
        status = 400;
      default:
        reject('$method $uri');
    }
    arrivals.add(_Arrival(uri, status, headers.value('x-request-id') ?? ''));
    return _Response(this, status);
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
  _Response(this.transport, this.statusCode) : headers = _Headers(transport) {
    headers.set('content-type', 'application/json');
  }
  final _LocalTransport transport;
  @override
  final _Headers headers;
  @override
  final int statusCode;
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

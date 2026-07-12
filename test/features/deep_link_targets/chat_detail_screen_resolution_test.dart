// Live-contract resolution + real-session-id guard for ChatDetailScreen.
//
// Two bugs are pinned here (both confirmed against the live gateway at
// 192.168.2.39:10090, see docs/sprints/sprint-006/order-create-trace.md):
//
//   1. RESOLUTION ROUTE. The screen used to resolve the conversation via
//      `GET /v1/chat/jeeb/conversations/{id}` + `/by-request/{id}`. That prefix
//      is CREATE-ONLY on the live gateway and 404s for reads, so the screen
//      fell into "compose" and a send wrongly created a NEW request. The fix
//      resolves against `GET /v1/conversations?correlationKey={requestId}`
//      (correlationKey == request id) and treats a 200 from
//      `GET /v1/conversations/{id}/messages` as a real, openable conversation.
//      This test asserts the live route IS queried and the 404 prefix is NEVER
//      touched.
//
//   2. REAL SESSION ID. The gateway used to be constructed with a hardcoded
//      `currentUserId: 'user-client-001'`, which folded EVERY message (incl.
//      the local user's own) as `them`. The fix reads the authenticated user id
//      from AuthTokenStore. This test asserts the constructed DioChatGateway
//      carries the real session id, not the hardcoded sentinel.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Records every outbound request and resolves a canned response keyed on path.
class _RecordingDio {
  _RecordingDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          Object? body = const <String, dynamic>{};
          const status = 200;
          if (path == '/v1/conversations') {
            // correlationKey lookup → the conversation row (live shape).
            body = <String, dynamic>{
              'id': conversationId,
              'phase': 'accepted',
              'requestId': requestId,
              'winnerJeeberId': 'd1000000-0000-4000-8000-000000000002',
            };
          } else if (path == '/v1/conversations/$conversationId/messages') {
            body = const <dynamic>[];
          } else if (path == '/v1/requests/$requestId') {
            body = <String, dynamic>{'title': 'Deliver a parcel'};
          }
          handler.resolve(
            Response(data: body, statusCode: status, requestOptions: options),
          );
        },
      ),
    );
  }

  static const conversationId = 'conv-live-7f3a';
  static const requestId = 'req-real-abc123';

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<String> get paths => requests.map((r) => r.path);
}

/// The REAL live-gateway snake_case shape observed in physical-run7
/// (`docs/sprints/sprint-008/screenshots/physical-run7/wire-step4-accept.txt`):
/// the customer opens `chat-detail` keyed on the REQUEST id, the correlationKey
/// lookup 200s with `{ conversation_id, correlation_key, phase:"broadcasting",
/// participants:[ …, {role_in_convo:"jeeber_winner"} ] }`, and the ONLY openable
/// messages route is `/v1/conversations/{conversation_id}/messages`. Posting to
/// `/v1/conversations/{requestId}/messages` 404s ("Conversation '…' does not
/// exist"). This double reproduces that wire so the screen must resolve to the
/// conversation_id for BOTH read and send.
class _LiveSnakeCaseDio {
  _LiveSnakeCaseDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          // The requestId-keyed messages route does NOT exist server-side.
          if (path == '/v1/conversations/$requestId/messages') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  data: const <String, dynamic>{
                    'status': 404,
                    'detail': "Conversation does not exist.",
                  },
                  statusCode: 404,
                  requestOptions: options,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          Object? body = const <String, dynamic>{};
          if (path == '/v1/conversations') {
            // Live snake_case row: id under `conversation_id`, winner seated in
            // the participants roster, phase still `broadcasting` post-accept.
            body = <String, dynamic>{
              'conversation_id': conversationId,
              'correlation_key': requestId,
              'phase': 'broadcasting',
              'participants': <Map<String, dynamic>>[
                <String, dynamic>{
                  'user_id': 'client-1',
                  'role_in_convo': 'client',
                  'removed_at': null,
                },
                <String, dynamic>{
                  'user_id': 'jeeber-1',
                  'role_in_convo': 'jeeber_winner',
                  'removed_at': null,
                },
              ],
            };
          } else if (path == '/v1/conversations/$conversationId/messages') {
            body = const <String, dynamic>{'messages': <dynamic>[]};
          } else if (path == '/v1/requests/$requestId') {
            body = <String, dynamic>{'title': 'Deliver a parcel'};
          }
          handler.resolve(
            Response(data: body, statusCode: 200, requestOptions: options),
          );
        },
      ),
    );
  }

  static const conversationId = '2896ca8d-88f8-4bb0-bc4d-be3c1e8fa3d4';
  static const requestId = '92fb0b67-e056-42c8-968d-36b5c6e77f3f';

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<String> get paths => requests.map((r) => r.path);
}

/// Reproduces the PRE-ACCEPT wire (physical-run8 `customer-full-logcat.txt`
/// lines 532–1048): the customer opens order-chat keyed on the REQUEST id
/// BEFORE any Jeeber accepts, so there is NO conversation yet. Both resolution
/// probes 404 — `GET /v1/conversations?correlationKey={requestId}` and
/// `GET /v1/conversations/{requestId}/messages` ("Conversation does not exist")
/// — and the screen must hand the gateway the unresolved sentinel so its
/// history/phase reads short-circuit instead of polling the requestId messages
/// path every tick.
class _PreAcceptDio {
  _PreAcceptDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          // No conversation exists for this request id yet → every conversation
          // read 404s, exactly like the live chat-service pre-accept.
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                data: const <String, dynamic>{
                  'status': 404,
                  'detail': "Conversation does not exist.",
                },
                statusCode: 404,
                requestOptions: options,
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );
  }

  static const requestId = 'd9366a8a-db84-4dff-9c52-d72f4b52108d';

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<String> get paths => requests.map((r) => r.path);

  int get requestIdMessagesReadCount => requests
      .where((r) => r.path == '/v1/conversations/$requestId/messages')
      .length;
}

/// Reproduces the run-12 JEEBER chat-load wire: the jeeber opens the accepted
/// order-chat keyed on the CONVERSATION id (from the accepted feed entry). The
/// chat-service resolves a conversation ONLY by correlationKey == request id and
/// 404s a `?correlationKey={conversationId}` read ("Conversation … does not
/// exist"), while `GET /v1/conversations/{conversationId}/messages` 200s. So the
/// screen must resolve via the messages probe and NEVER issue the guaranteed-404
/// correlationKey read (BUG-14 / physical-run12 [Med] chat-load 404 ×2).
class _JeeberConversationIdDio {
  _JeeberConversationIdDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          // A correlationKey read keyed on the conversation id is the run-12
          // 404 shape — the screen must not issue it for the jeeber.
          if (path == '/v1/conversations') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  data: const <String, dynamic>{
                    'status': 404,
                    'detail': "Conversation does not exist.",
                  },
                  statusCode: 404,
                  requestOptions: options,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          Object? body = const <String, dynamic>{};
          if (path == '/v1/conversations/$conversationId/messages') {
            body = const <String, dynamic>{'messages': <dynamic>[]};
          }
          handler.resolve(
            Response(data: body, statusCode: 200, requestOptions: options),
          );
        },
      ),
    );
  }

  static const conversationId = 'c134f5ed-e403-4bc9-8b50-3734ca1970f0';

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<String> get paths => requests.map((r) => r.path);

  int get correlationKeyLookups =>
      requests.where((r) => r.path == '/v1/conversations').length;
}

/// Reproduces a CLIENT opening the order-chat by a CONVERSATION id (e.g. the
/// dashboard active-delivery `chatRouteId`, which is a conversation id). The
/// correlationKey lookup 404s (a conversationId is NOT a correlationKey) and
/// resolution succeeds ONLY via the `/messages` probe — so the resolved row
/// carries NO `correlation_key`. In that probe-only state the CLIENT pinned-
/// summary fetch MUST be skipped: feeding the conversationId to the summary
/// read fires `GET /v1/deliveries/{convId}` + `/v1/requests/{convId}` +
/// `/v1/offers?requestId={convId}` — a guaranteed triple-404 (BUG-17, fix a3).
class _ClientConversationIdProbeDio {
  _ClientConversationIdProbeDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          // correlationKey keyed on a conversationId does not resolve → 404.
          if (path == '/v1/conversations') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  data: const <String, dynamic>{
                    'status': 404,
                    'detail': 'Conversation does not exist.',
                  },
                  statusCode: 404,
                  requestOptions: options,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          // The messages probe on the conversation id 200s (a real thread).
          if (path == '/v1/conversations/$conversationId/messages') {
            handler.resolve(
              Response(
                data: const <String, dynamic>{'messages': <dynamic>[]},
                statusCode: 200,
                requestOptions: options,
              ),
            );
            return;
          }
          // Any owner-scoped summary read (deliveries/requests/offers) — this
          // is EXACTLY the triple-404 storm fix a3 must prevent. Resolve 200 so
          // that if it (wrongly) fires the test still asserts on `paths`.
          handler.resolve(
            Response(
              data: const <String, dynamic>{},
              statusCode: 200,
              requestOptions: options,
            ),
          );
        },
      ),
    );
  }

  static const conversationId = 'c0ffee00-aaaa-4bbb-8ccc-dddddddddddd';

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<String> get paths => requests.map((r) => r.path);

  /// True iff any leg of the owner-scoped pinned-summary triple-read fired.
  bool get emittedSummaryRead => paths.any(
    (p) =>
        p.startsWith('/v1/deliveries/') ||
        p.startsWith('/v1/requests/') ||
        p.startsWith('/v1/offers'),
  );
}

/// AuthTokenStore double that returns a known session user id without touching
/// the platform keychain.
class _StubAuthTokenStore extends AuthTokenStore {
  _StubAuthTokenStore(this._uid) : super(storage: const FlutterSecureStorage());
  final String? _uid;
  @override
  Future<String?> get userId async => _uid;
}

const _sessionUserId = 'd1000000-0000-4000-8000-000000000001';

Widget _host(RoleCubit role, String chatId) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<RoleCubit>.value(
    value: role,
    // JEBV4-282: this suite exercises live-contract RESOLUTION, not the
    // pinned-summary poll. Disable the poll so its periodic timer never
    // outlives pumpAndSettle (the poll itself is covered separately).
    child: ChatDetailScreen(chatId: chatId, summaryPollInterval: null),
  ),
);

Future<RoleCubit> _roleCubit(UserRole role) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: role);
}

void main() {
  late _RecordingDio rec;

  setUp(() {
    rec = _RecordingDio();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
    sl.registerSingleton<Dio>(rec.dio);
    sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
  });

  group('ChatDetailScreen — live-contract resolution', () {
    testWidgets(
      'resolves via GET /v1/conversations?correlationKey and NEVER the '
      'create-only /v1/chat/jeeb/conversations prefix',
      (tester) async {
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _RecordingDio.requestId));
        await tester.pumpAndSettle();

        // The correlationKey lookup ran with the route param as the request id.
        final corr = rec.requests.firstWhere(
          (r) => r.path == '/v1/conversations',
          orElse: () => RequestOptions(path: '__none__'),
        );
        expect(
          corr.path,
          '/v1/conversations',
          reason: 'must query the live correlationKey route',
        );
        expect(corr.queryParameters['correlationKey'], _RecordingDio.requestId);

        // The historical create-only 404 prefix must NEVER be touched.
        expect(
          rec.paths.any((p) => p.startsWith('/v1/chat/jeeb/conversations')),
          isFalse,
          reason:
              'the create-only prefix 404s on live; never use it to resolve',
        );
      },
    );

    testWidgets('constructs DioChatGateway with the REAL session id, not '
        'the hardcoded user-client-001 sentinel', (tester) async {
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _RecordingDio.requestId));
      await tester.pumpAndSettle();

      final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
      final gateway = chatScreen.gateway;
      expect(gateway, isA<DioChatGateway>());
      expect((gateway! as DioChatGateway).currentUserId, _sessionUserId);
      expect(
        (gateway as DioChatGateway).currentUserId,
        isNot('user-client-001'),
      );
    });
  });

  group('ChatDetailScreen — live snake_case conversation resolution (run-7)', () {
    late _LiveSnakeCaseDio live;

    setUp(() {
      live = _LiveSnakeCaseDio();
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
      sl.registerSingleton<Dio>(live.dio);
      sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
    });

    testWidgets(
      'opened by REQUEST id, resolves the live `conversation_id` and drives '
      'chat send/read at /v1/conversations/{conversationId}/messages (NOT the '
      'requestId path that 404s)',
      (tester) async {
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        // The customer accept sheet pushes chat-detail keyed on the REQUEST id.
        await tester.pumpWidget(_host(role, _LiveSnakeCaseDio.requestId));
        await tester.pumpAndSettle();

        // The chat surface is wired to the RESOLVED conversation id — every
        // send/loadHistory/subscribe the cubit issues uses this id.
        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(
          chatScreen.deliveryId,
          _LiveSnakeCaseDio.conversationId,
          reason:
              'must resolve the snake_case `conversation_id`, not fall back '
              'to the requestId (the run-7 Step-5 404 blocker)',
        );

        // The requestId-keyed messages route must NEVER be called — that is the
        // path that 404d in run-7. Reads go to the conversationId path.
        expect(
          live.paths.any(
            (p) =>
                p ==
                '/v1/conversations/${_LiveSnakeCaseDio.requestId}/messages',
          ),
          isFalse,
          reason: 'sends/reads must target the conversationId, never requestId',
        );
        expect(
          live.paths.contains(
            '/v1/conversations/${_LiveSnakeCaseDio.conversationId}/messages',
          ),
          isTrue,
          reason: 'history read must hit the resolved conversation id',
        );
      },
    );

    testWidgets(
      'a seated `jeeber_winner` participant (phase still `broadcasting`) lands '
      'the client in ACCEPTED, so a send POSTs to the conversation instead of '
      'broadcasting a NEW request',
      (tester) async {
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _LiveSnakeCaseDio.requestId));
        await tester.pumpAndSettle();

        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        // Compose mode wires `onFirstMessageBroadcast`; the accepted state
        // leaves it null so the composer's send goes straight to the gateway
        // (POST /v1/conversations/{conversationId}/messages) rather than
        // creating and broadcasting a brand-new request.
        expect(
          chatScreen.onFirstMessageBroadcast,
          isNull,
          reason: 'a seated jeeber_winner must exit compose so sends persist',
        );
      },
    );

    testWidgets(
      'post-accept phase read queries ?correlationKey={requestId} (200) — '
      'NEVER ?correlationKey={conversationId} (the run-8 READ 404 #2)',
      (tester) async {
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _LiveSnakeCaseDio.requestId));
        await tester.pumpAndSettle();

        // Every conversation-aggregate lookup (resolution + the cubit phase
        // read) must key off the request id (correlation_key), not the resolved
        // conversation id — the chat-service only supports the correlationKey
        // read and 404s a conversationId-keyed one.
        final corrLookups = live.requests
            .where((r) => r.path == '/v1/conversations')
            .toList();
        expect(corrLookups, isNotEmpty);
        for (final r in corrLookups) {
          expect(
            r.queryParameters['correlationKey'],
            _LiveSnakeCaseDio.requestId,
            reason: 'phase/resolution must use the requestId correlation key',
          );
          expect(
            r.queryParameters['correlationKey'],
            isNot(_LiveSnakeCaseDio.conversationId),
            reason: 'conversationId-keyed lookup is the run-8 404 shape',
          );
        }
      },
    );

    testWidgets(
      'the JEEBER variant does NOT fetch the client-only pinned summary — so it '
      'never fires the owner-scoped GET /v1/requests/{id} that 404s (READ #3)',
      (tester) async {
        final role = await _roleCubit(UserRole.jeeber);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _LiveSnakeCaseDio.requestId));
        await tester.pumpAndSettle();

        // The pinned summary (delivery + request + offer reads) is a client-only
        // surface; the jeeber must not fetch it. The owner-scoped request read
        // is the one that 404d for the non-owner jeeber in run-8.
        expect(
          live.paths.any((p) => p.startsWith('/v1/requests/')),
          isFalse,
          reason: 'jeeber never renders the summary → skip the owner-only read',
        );
      },
    );
  });

  group('ChatDetailScreen — pre-accept (no conversation yet)', () {
    late _PreAcceptDio pre;

    setUp(() {
      pre = _PreAcceptDio();
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
      sl.registerSingleton<Dio>(pre.dio);
      sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
    });

    testWidgets(
      'opened by REQUEST id before accept: the chat surface is wired to the '
      'unresolved compose sentinel so reads short-circuit (NO requestId '
      'messages poll — physical-run8 READ 404 #1)',
      (tester) async {
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _PreAcceptDio.requestId));
        await tester.pumpAndSettle();

        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        // The gateway channel id is the sentinel → DioChatGateway short-circuits
        // loadHistory/loadPhase (no HTTP), so the 5s poll never hits the
        // requestId messages path.
        expect(
          chatScreen.deliveryId,
          kComposeConversationSentinel,
          reason:
              'no conversation yet → hand the gateway the sentinel, never '
              'the requestId it would poll to a 404',
        );
        // Still the client compose surface (a first send creates/broadcasts the
        // request; it does NOT post to the requestId messages path).
        expect(chatScreen.onFirstMessageBroadcast, isNotNull);

        // The requestId messages route is touched AT MOST once (the one-shot
        // resolution probe), never repeatedly polled.
        expect(
          pre.requestIdMessagesReadCount,
          lessThanOrEqualTo(1),
          reason: 'the pre-accept requestId messages path must not be polled',
        );
      },
    );
  });

  group('ChatDetailScreen — jeeber opens accepted chat by CONVERSATION id '
      '(BUG-14)', () {
    late _JeeberConversationIdDio jeeb;

    setUp(() {
      jeeb = _JeeberConversationIdDio();
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
      sl.registerSingleton<Dio>(jeeb.dio);
      sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
    });

    testWidgets(
      'resolves via the messages-probe fallback after a single correlationKey '
      'attempt (no conversationId-keyed chat-load 404 STORM)',
      (tester) async {
        final role = await _roleCubit(UserRole.jeeber);
        addTearDown(role.close);

        // The jeeber taps the accepted feed row, which is keyed on the
        // conversation id.
        await tester.pumpWidget(
          _host(role, _JeeberConversationIdDio.conversationId),
        );
        await tester.pumpAndSettle();

        // The chat surface is wired to the conversation id (resolved by the
        // messages probe).
        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(chatScreen.deliveryId, _JeeberConversationIdDio.conversationId);

        // BUG-17 fix (b) runs correlationKey-FIRST for BOTH roles, so a
        // conversationId param now attempts the correlationKey lookup exactly
        // ONCE (it 404s, caught) then resolves via the messages-probe fallback.
        // Crucially the gateway's loadPhase short-circuit (BUG-14,
        // dio_chat_gateway.dart L163-165) still prevents any FURTHER
        // conversationId-keyed correlationKey read — so this is a single caught
        // attempt, never the repeated chat-load 404 STORM BUG-14 fixed.
        expect(
          jeeb.correlationKeyLookups,
          1,
          reason:
              'correlationKey-first attempts the lookup once (404) then '
              'falls back to the probe; the gateway short-circuit prevents any '
              'further conversationId-keyed read (BUG-14 preserved)',
        );
        // History is read on the conversation-id messages route.
        expect(
          jeeb.paths.contains(
            '/v1/conversations/${_JeeberConversationIdDio.conversationId}'
            '/messages',
          ),
          isTrue,
          reason: 'reads target the resolved conversation id',
        );
      },
    );
  });

  // BUG-17 fix (b): the role-based resolution ordering is GONE — BOTH roles
  // resolve correlationKey-FIRST. When the route param is a requestId (the
  // accept sheet, the chat push tap via notification_deep_link, the accepted-
  // feed CTA, the In-Progress "Open chat" CTA all hand over the request id),
  // the `/v1/conversations/{requestId}/messages` probe is a GUARANTEED 404, so
  // it must NEVER be issued first (the physical-run14 jeeber-probe-first 404).
  group('ChatDetailScreen — correlationKey-first for BOTH roles (BUG-17)', () {
    late _LiveSnakeCaseDio live;

    setUp(() {
      live = _LiveSnakeCaseDio();
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
      sl.registerSingleton<Dio>(live.dio);
      sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
    });

    for (final role in <UserRole>[UserRole.client, UserRole.jeeber]) {
      testWidgets(
        'the ${role.name} opens by requestId → correlationKey resolves FIRST '
        'and the requestId messages-probe (guaranteed 404) NEVER fires',
        (tester) async {
          final roleCubit = await _roleCubit(role);
          addTearDown(roleCubit.close);

          await tester.pumpWidget(
            _host(roleCubit, _LiveSnakeCaseDio.requestId),
          );
          await tester.pumpAndSettle();

          // THE FIX: with correlationKey-first, the requestId-keyed messages
          // probe is never issued for EITHER role (the old jeeber path ran it
          // first and 404'd on a requestId push tap).
          expect(
            live.paths.contains(
              '/v1/conversations/${_LiveSnakeCaseDio.requestId}/messages',
            ),
            isFalse,
            reason:
                'requestId messages-probe is a guaranteed 404 — never first',
          );

          // The FIRST conversation lookup is the correlationKey resolve.
          final firstConvoCall = live.requests.firstWhere(
            (r) =>
                r.path == '/v1/conversations' ||
                r.path.startsWith('/v1/conversations/'),
            orElse: () => RequestOptions(path: '__none__'),
          );
          expect(
            firstConvoCall.path,
            '/v1/conversations',
            reason: 'correlationKey lookup must run before any messages probe',
          );
          expect(
            firstConvoCall.queryParameters['correlationKey'],
            _LiveSnakeCaseDio.requestId,
          );

          // Both roles land on the resolved conversation id for reads/sends.
          final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
          expect(chatScreen.deliveryId, _LiveSnakeCaseDio.conversationId);
        },
      );
    }
  });

  // BUG-17 fix (a3): when a CLIENT opens by a CONVERSATION id, resolution
  // succeeds ONLY via the messages probe (the row has no correlation_key), so
  // the owner-scoped pinned-summary triple-read MUST be skipped — otherwise it
  // fires GET /v1/deliveries/{convId} + /v1/requests/{convId} +
  // /v1/offers?requestId={convId}, a guaranteed triple-404.
  group('ChatDetailScreen — probe-only resolution skips the summary '
      'triple-read (BUG-17)', () {
    late _ClientConversationIdProbeDio probe;

    setUp(() {
      probe = _ClientConversationIdProbeDio();
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
      sl.registerSingleton<Dio>(probe.dio);
      sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
    });

    testWidgets(
      'CLIENT opened by conversationId resolves via the messages probe and '
      'emits NO summary read (no deliveries/requests/offers triple-404)',
      (tester) async {
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(
          _host(role, _ClientConversationIdProbeDio.conversationId),
        );
        await tester.pumpAndSettle();

        // Resolved to the conversation id (probe fallback), so the thread reads.
        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(
          chatScreen.deliveryId,
          _ClientConversationIdProbeDio.conversationId,
        );

        // THE FIX: no owner-scoped summary read fires — the probe-only row has
        // no correlation_key, so `_resolveSummary` is skipped entirely.
        expect(
          probe.emittedSummaryRead,
          isFalse,
          reason:
              'probe-only resolution must not storm the summary triple-read',
        );
      },
    );
  });

  // Fix 5: a compose-sentinel ('new') or empty route param has NO backend
  // conversation yet. Both the correlationKey lookup and the messages probe are
  // GUARANTEED 404s, so the resolver must skip BOTH and land directly in
  // compose without touching the network.
  group('ChatDetailScreen — compose sentinel skips guaranteed-404 probes', () {
    late _RecordingDio sentinel;

    setUp(() {
      sentinel = _RecordingDio();
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
      sl.registerSingleton<Dio>(sentinel.dio);
      sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
    });

    for (final chatId in <String>[kComposeConversationSentinel, '']) {
      final label = chatId.isEmpty ? 'empty' : "'$chatId'";
      testWidgets(
        'opened with a $label chatId performs ZERO conversation-resolution '
        'network calls and lands in compose',
        (tester) async {
          final role = await _roleCubit(UserRole.client);
          addTearDown(role.close);

          await tester.pumpWidget(_host(role, chatId));
          await tester.pumpAndSettle();

          // THE FIX: neither the correlationKey lookup nor the messages probe
          // fires — the resolver short-circuits on the sentinel/empty param.
          expect(
            sentinel.paths.any((p) => p.startsWith('/v1/conversations')),
            isFalse,
            reason: 'compose sentinel must skip both guaranteed-404 probes',
          );
          // No HTTP at all is issued during resolution.
          expect(
            sentinel.requests,
            isEmpty,
            reason: 'a fresh compose must not touch the network',
          );

          // Still the client compose surface: the gateway holds the sentinel and
          // the first send creates + broadcasts the request.
          final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
          expect(chatScreen.deliveryId, kComposeConversationSentinel);
          expect(chatScreen.onFirstMessageBroadcast, isNotNull);
        },
      );
    }
  });
}

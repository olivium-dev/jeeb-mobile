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
        child: ChatDetailScreen(chatId: chatId),
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
        expect(corr.path, '/v1/conversations',
            reason: 'must query the live correlationKey route');
        expect(corr.queryParameters['correlationKey'], _RecordingDio.requestId);

        // The historical create-only 404 prefix must NEVER be touched.
        expect(
          rec.paths.any((p) => p.startsWith('/v1/chat/jeeb/conversations')),
          isFalse,
          reason: 'the create-only prefix 404s on live; never use it to resolve',
        );
      },
    );

    testWidgets(
      'constructs DioChatGateway with the REAL session id, not '
      'the hardcoded user-client-001 sentinel',
      (tester) async {
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
      },
    );
  });
}

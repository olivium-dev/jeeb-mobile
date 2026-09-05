// A TRANSPORT FAILURE IS NOT A STATEMENT ABOUT THE WORLD.
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
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// THE OFFLINE WIRE. Every request fails with NO response at all — Dio's
/// `connectionError`, which is precisely what an unreachable gateway looks
/// like. `response == null` is the signature that distinguishes it from a 404,
class _OfflineDio {
  _OfflineDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'Network is unreachable',
            ),
          );
        },
      ),
    );
  }

  /// An IN-TRANSIT delivery with an accepted offer — the exact situation the
  /// live report describes. The id is real to the server; only the phone's
  static const inTransitRequestId = '7c1e0d92-3b4a-4f21-9c33-0a55d0f21b7e';

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];
}

/// PRE-ACCEPT — the honest 404 wire. No Jeeber has accepted yet, so no
/// conversation row exists and the chat-service answers BOTH lookups with
/// `404 "Conversation '…' does not exist."` (physical-run8). This is a real
class _PreAcceptDio {
  _PreAcceptDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
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
}

/// Offline until [healed] is flipped, then serves the live accepted-conversation
/// wire. Drives the retry CTA: the SAME route that could not be resolved
/// resolves once connectivity returns, with no app restart.
class _HealingDio {
  _HealingDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (!healed) {
            handler.reject(
              DioException.connectionError(
                requestOptions: options,
                reason: 'Network is unreachable',
              ),
            );
            return;
          }
          final path = options.path;
          Object? body = const <String, dynamic>{};
          if (path == '/v1/conversations') {
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
          } else if (path == '/v1/deliveries/$requestId') {
            body = <String, dynamic>{
              'description': 'Deliver a parcel',
              'status': 'InTransit',
            };
          }
          handler.resolve(
            Response(data: body, statusCode: 200, requestOptions: options),
          );
        },
      ),
    );
  }

  bool healed = false;

  static const conversationId = '2896ca8d-88f8-4bb0-bc4d-be3c1e8fa3d4';
  static const requestId = '92fb0b67-e056-42c8-968d-36b5c6e77f3f';

  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];
}

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

void _register(Dio dio) {
  final sl = GetIt.instance;
  if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
  if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
  sl.registerSingleton<Dio>(dio);
  sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
}

void main() {
  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
  });

  group('ChatDetailScreen — the network is DOWN (we could not find out)', () {
    testWidgets(
      'DoD: cold-entering chat on an in-transit delivery with the network down '
      'shows an error + retry — NOT "Waiting for Jeebers", NOT an empty thread',
      (tester) async {
        final offline = _OfflineDio();
        _register(offline.dio);
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _OfflineDio.inTransitRequestId));
        await tester.pumpAndSettle();

        // 1. The error body is on screen, with a retry.
        expect(
          find.byType(ChatResolutionErrorView),
          findsOneWidget,
          reason: 'a transport failure must surface as an error with retry',
        );
        expect(find.text('Couldn\'t load this chat'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        // By identifier, not by copy: the ids are what Maestro and the
        // screen reader address, and what a copy change must not break.
        expect(
          find.bySemanticsIdentifier('chat_resolution_error'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('chat_detail_resolution_retry'),
          findsOneWidget,
        );

        // 2. THE LAUNDERING IS GONE. Not one word of the broadcasting copy.
        expect(
          find.text('Waiting for Jeebers…'),
          findsNothing,
          reason:
              'this delivery is IN TRANSIT with an accepted offer; claiming '
              'it is still broadcasting is a false statement about the world',
        );
        expect(find.text('No offers yet — sit tight.'), findsNothing);

        // 3. And no empty thread either — the other half of the collapse.
        expect(find.text('No conversation yet'), findsNothing);
        expect(
          find.byType(ChatScreen),
          findsNothing,
          reason:
              'no gateway is constructed when resolution could not find out, '
              'so nothing downstream can invent a phase or an empty thread',
        );
      },
    );

    testWidgets(
      'the retry CTA re-resolves the SAME route once connectivity returns — no '
      'app restart, and the resolved thread renders',
      (tester) async {
        final healing = _HealingDio();
        _register(healing.dio);
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _HealingDio.requestId));
        await tester.pumpAndSettle();
        expect(find.byType(ChatResolutionErrorView), findsOneWidget);

        // Connectivity comes back; the user taps retry.
        healing.healed = true;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(find.byType(ChatResolutionErrorView), findsNothing);
        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(
          chatScreen.deliveryId,
          _HealingDio.conversationId,
          reason: 'the retry resolved the real conversation id',
        );
      },
    );

    testWidgets(
      'a 404 on ONE lookup plus a transport failure on the other is still '
      '"could not find out" — absence requires BOTH lookups to have ANSWERED',
      (tester) async {
        // The correlationKey lookup answers 404 (a request-id param the
        final dio = Dio(BaseOptions(baseUrl: 'http://test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v1/conversations') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      statusCode: 404,
                      requestOptions: options,
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
                return;
              }
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'Network is unreachable',
                ),
              );
            },
          ),
        );
        _register(dio);
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _OfflineDio.inTransitRequestId));
        await tester.pumpAndSettle();

        expect(find.byType(ChatResolutionErrorView), findsOneWidget);
        expect(find.text('Waiting for Jeebers…'), findsNothing);
      },
    );
  });

  group('NEGATIVE TEST — the happy path is unchanged', () {
    testWidgets(
      'a genuinely broadcasting request (BOTH lookups answer 404) still renders '
      'as broadcasting, NOT as an error',
      (tester) async {
        final pre = _PreAcceptDio();
        _register(pre.dio);
        final role = await _roleCubit(UserRole.client);
        addTearDown(role.close);

        await tester.pumpWidget(_host(role, _PreAcceptDio.requestId));
        await tester.pumpAndSettle();

        // NO error body: the server answered, and its answer was "not yet".
        expect(
          find.byType(ChatResolutionErrorView),
          findsNothing,
          reason:
              'a definitive 404 is an ANSWER — turning it into an error would '
              'break every pre-accept order-chat entry',
        );

        // The compose/broadcasting shell, exactly as before the fix.
        final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
        expect(chatScreen.deliveryId, 'new');
        expect(
          chatScreen.onFirstMessageBroadcast,
          isNotNull,
          reason: 'still the client compose surface',
        );
        expect(
          find.text('Waiting for Jeebers…'),
          findsOneWidget,
          reason:
              'the broadcasting copy is CORRECT here — the request really is '
              'still waiting for offers',
        );
      },
    );
  });
}

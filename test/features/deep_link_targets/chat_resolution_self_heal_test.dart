// A FAILED READ MUST HEAL ITSELF WHEN THE NETWORK COMES BACK.
//
// #189 made the third state visible (we-could-not-find-out → error + retry).
// It did not make it RECOVER: the only way out was a tap on "Try again" or
// backing out and re-entering the route. Measured live on the pre-fix build,
// the failed chat screen was byte-identical 45 s later and byte-identical
// 65 s AFTER connectivity was fully restored (ping 0 % loss), because the only
// thing that could have cleared the failure — a successful read — was never
// attempted again: the retained 60 s history poll had been deleted, so ZERO
// reads happened on that screen for 3 m 21 s.
//
// So the screen states, correctly, that it does not know — and then never finds
// out. This suite pins the recovery, and pins its BOUND:
//
//   * DoD          — connectivity returns and the thread renders itself, with
//                    no tap and no re-entry.
//   * NEGATIVE     — while the network stays down, the retry is a BACKOFF and
//                    not a poll: a bounded number of attempts over a minute,
//                    not one every few seconds. (The owner mandate bans a
//                    repeated call at any interval; a terminating retry of a
//                    FAILED read is error recovery, and its terminating
//                    property is what this test asserts.)
//   * CONTROL      — a screen that resolved successfully schedules NO retries
//                    at all, so the mechanism cannot become an ambient poll on
//                    the healthy path.
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

/// Offline until [healed] is flipped, then serves the live accepted-conversation
/// wire. Nobody taps anything: the flip is the only event.
class _HealingDio {
  _HealingDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.path);
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
              'phase': 'accepted',
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
  final List<String> requests = <String>[];

  /// Resolution ATTEMPTS, counted off the wire: the correlation-key lookup is
  /// the first read of every attempt.
  int get resolutionAttempts =>
      requests.where((p) => p == '/v1/conversations').length;
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

  testWidgets(
    'DoD: the resolution error HEALS ITSELF when connectivity returns — no tap, '
    'no re-entry',
    (tester) async {
      final healing = _HealingDio();
      _register(healing.dio);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _HealingDio.requestId));
      await tester.pumpAndSettle();
      expect(
        find.byType(ChatResolutionErrorView),
        findsOneWidget,
        reason: 'network down: the screen says it does not know',
      );

      // Connectivity returns. NOBODY TOUCHES THE SCREEN.
      healing.healed = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(
        find.byType(ChatResolutionErrorView),
        findsNothing,
        reason:
            'the failed read must retry itself once the network is back; the '
            'measured pre-fix screen was byte-identical 65 s after the network '
            'came back because nothing ever re-read',
      );
      final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chatScreen.deliveryId, _HealingDio.conversationId);
    },
  );

  testWidgets(
    'NEGATIVE: while the network stays down the retry is a BACKOFF, not a poll '
    '— a bounded number of attempts across a full minute',
    (tester) async {
      final healing = _HealingDio();
      _register(healing.dio);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _HealingDio.requestId));
      await tester.pumpAndSettle();
      final coldAttempts = healing.resolutionAttempts;
      expect(coldAttempts, 1, reason: 'one cold resolution');

      // A full minute of continuous failure.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      await tester.pumpAndSettle();

      final retries = healing.resolutionAttempts - coldAttempts;
      expect(
        retries,
        greaterThan(0),
        reason: 'it must actually try again — otherwise it cannot heal',
      );
      expect(
        retries,
        lessThanOrEqualTo(6),
        reason:
            'a 5 s cadence would be 12 in this window. This is a terminating '
            'backoff on a FAILED read, not a poll: attempts=$retries',
      );
      expect(find.byType(ChatResolutionErrorView), findsOneWidget);
    },
  );

  testWidgets(
    'CONTROL: a resolution that SUCCEEDS schedules no retries at all',
    (tester) async {
      final healing = _HealingDio()..healed = true;
      _register(healing.dio);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _HealingDio.requestId));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      final afterResolve = healing.resolutionAttempts;

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      await tester.pumpAndSettle();

      expect(
        healing.resolutionAttempts,
        afterResolve,
        reason:
            'the healthy path must not acquire a cadence — the retry exists '
            'only while the screen does not know the answer',
      );
    },
  );
}

// ignore_for_file: avoid_dynamic_calls
// `_ChatDetailScreenState` is private, so `tester.state(...)` can only be typed

// THE RECONNECT MUST BE WHAT HEALS THE SCREEN — not a backoff tick that
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Offline until [healed] is flipped, then serves the live accepted-conversation
/// wire. When [gate] is non-null every conversation lookup is held open, so a
/// second trigger lands while the first attempt is genuinely in flight — the
class _ReconnectDio {
  _ReconnectDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;
          requests.add(path);
          if (path == '/v1/conversations') {
            final held = gate;
            if (held != null) await held.future;
          }
          if (!healed) {
            handler.reject(
              DioException.connectionError(
                requestOptions: options,
                reason: 'Network is unreachable',
              ),
            );
            return;
          }
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
            Response<dynamic>(
              data: body,
              statusCode: 200,
              requestOptions: options,
            ),
          );
        },
      ),
    );
  }

  bool healed = false;

  /// Non-null holds every conversation lookup open until completed.
  Completer<void>? gate;

  static const conversationId = '2896ca8d-88f8-4bb0-bc4d-be3c1e8fa3d4';
  static const requestId = '92fb0b67-e056-42c8-968d-36b5c6e77f3f';

  late final Dio dio;
  final List<String> requests = <String>[];

  /// Resolution ATTEMPTS, counted off the wire: the correlation-key lookup is
  /// the first read of every attempt. Counting on the wire rather than off a
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

dynamic _chatState(WidgetTester tester) =>
    tester.state(find.byType(ChatDetailScreen));

/// The bus clock, driven independently of the widget-test clock.
/// The two must not be the same clock. `NetworkReachabilitySignals` throttles
late DateTime _busNow;

NetworkReachabilitySignals _installBus() {
  _busNow = DateTime(2026, 7, 28, 12);
  final bus = NetworkReachabilitySignals(clock: () => _busNow);
  NetworkReachabilitySignals.instance = bus;
  return bus;
}

/// One offline→online edge, delivered past the bus throttle.
void _reconnect(NetworkReachabilitySignals bus) {
  _busNow = _busNow.add(kNetworkReachabilityMinInterval);
  bus.debugObserve(online: false);
  bus.debugObserve(online: true);
}

/// Pump WITHOUT elapsing the fake clock.
/// `tester.pump()` with no duration flushes microtasks and produces a frame but
late Duration _elapsed;

/// One millisecond per frame.
/// A pump that elapses literally nothing is not usable here, and the reason is
const Duration _kPumpStep = Duration(milliseconds: 1);

/// Pump enough for the async resolution to complete, while keeping total
/// elapsed fake time orders of magnitude below the first backoff step.
Future<void> _settleWellInsideTheFirstBackoffStep(
  WidgetTester tester, {
  int frames = 24,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(_kPumpStep);
    _elapsed += _kPumpStep;
  }
}

/// The assertion that makes every "the event caused this" claim in this file
/// admissible: no backoff step has elapsed, so no backoff timer has fired.
void _expectBackoffCannotHaveFired() {
  expect(
    _elapsed,
    lessThan(kChatResolutionRetryBackoff.first),
    reason:
        'total elapsed fake time is $_elapsed against a first backoff step of '
        '${kChatResolutionRetryBackoff.first}. If this ever fails, every '
        'attribution in this file is void — a backoff tick could be the cause, '
        'which is precisely how the original claim was falsified',
  );
}

void main() {
  setUp(() async {
    _elapsed = Duration.zero;
    await NetworkReachabilitySignals.debugReset();
  });

  tearDown(() async {
    await NetworkReachabilitySignals.debugReset();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
    if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
  });

  testWidgets(
    'THE DISCRIMINATOR: the reconnect EVENT heals the screen while the backoff '
    'timer is still pending and unfired',
    (tester) async {
      final net = _ReconnectDio();
      _register(net.dio);
      final bus = _installBus();
      // The network is already down when the user opens the thread — the exact
      bus.debugObserve(online: false);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _ReconnectDio.requestId));
      await _settleWellInsideTheFirstBackoffStep(tester);

      expect(
        find.byType(ChatResolutionErrorView),
        findsOneWidget,
        reason: 'network down: the screen says it does not know',
      );
      expect(
        net.resolutionAttempts,
        1,
        reason:
            'the COLD attempt and only it. The 2 s backoff step armed at mount '
            'has not fired, because the clock has not moved — which is what '
            'makes the next assertion attributable to the event',
      );

      // The network comes back. Nobody taps anything, nobody re-enters the
      final attemptsBeforeEvent = net.resolutionAttempts;
      net.healed = true;
      _reconnect(bus);
      await _settleWellInsideTheFirstBackoffStep(tester);

      _expectBackoffCannotHaveFired();
      expect(
        _chatState(tester).debugResolutionRetryCount,
        1,
        reason:
            'EXACTLY one silent re-attempt, and the elapsed-budget assertion '
            'above rules the backoff out as its cause. Delete the subscriber '
            'and this is 0',
      );
      expect(
        net.resolutionAttempts,
        greaterThan(attemptsBeforeEvent),
        reason:
            'the re-attempt reached the WIRE. Deliberately `greaterThan` and '
            'not an exact count: once the thread resolves, ChatCubit mounts '
            'its own DioChatGateway, whose phase read is also a '
            '/v1/conversations?correlationKey= call. That extra read is a '
            'CONSEQUENCE of healing, so pinning an exact number here would be '
            'pinning ChatCubit\'s behaviour in a test about reconnects. The '
            'causal claim is carried by debugResolutionRetryCount above and by '
            'the negative control',
      );
      expect(
        find.byType(ChatResolutionErrorView),
        findsNothing,
        reason: 'the thread renders itself with no tap and no re-entry',
      );
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).deliveryId,
        _ReconnectDio.conversationId,
      );
      expect(
        _chatState(tester).debugReconnectPreemptCount,
        0,
        reason:
            'the pre-emption BUDGET is per failure episode, and a success ends '
            'the episode — `_finalize` -> `_cancelResolutionRetry` hands it '
            'back so the next outage starts with a full one. Asserted rather '
            'than dropped, because a budget that did NOT reset would silently '
            'starve the second outage of its immediate retry',
      );
    },
  );

  testWidgets(
    'NEGATIVE CONTROL: same pump budget, network fully restored, but NO '
    'connectivity event — the screen stays dark',
    (tester) async {
      final net = _ReconnectDio();
      _register(net.dio);
      final bus = _installBus();
      bus.debugObserve(online: false);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _ReconnectDio.requestId));
      await _settleWellInsideTheFirstBackoffStep(tester);
      expect(find.byType(ChatResolutionErrorView), findsOneWidget);
      expect(net.resolutionAttempts, 1);

      // Identical to the discriminator EXCEPT that no event is delivered. The
      net.healed = true;
      await _settleWellInsideTheFirstBackoffStep(tester);

      _expectBackoffCannotHaveFired();
      expect(
        net.resolutionAttempts,
        1,
        reason:
            'this is the FALSIFIED behaviour, pinned: a restored network that '
            'nothing reports is invisible to the screen. It is also the proof '
            'that the discriminator above is measuring the event and not the '
            'pump budget — the two cases differ by exactly one thing',
      );
      expect(
        find.byType(ChatResolutionErrorView),
        findsOneWidget,
        reason: 'still dark, because nothing told it the network was back',
      );
    },
  );

  testWidgets(
    'COALESCING: two reconnect events while an attempt is in flight produce ONE '
    'attempt',
    (tester) async {
      final net = _ReconnectDio();
      _register(net.dio);
      final bus = _installBus();
      bus.debugObserve(online: false);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _ReconnectDio.requestId));
      await _settleWellInsideTheFirstBackoffStep(tester);
      expect(net.resolutionAttempts, 1);

      // Hold the next conversation lookup open so the attempt it belongs to is
      final gate = Completer<void>();
      net.gate = gate;

      _reconnect(bus);
      await _settleWellInsideTheFirstBackoffStep(tester);
      expect(
        net.resolutionAttempts,
        2,
        reason: 'the first event started exactly one attempt',
      );

      // Two more genuine offline→online edges, each past the bus throttle, both
      _reconnect(bus);
      await _settleWellInsideTheFirstBackoffStep(tester);
      _reconnect(bus);
      await _settleWellInsideTheFirstBackoffStep(tester);

      _expectBackoffCannotHaveFired();
      expect(
        net.resolutionAttempts,
        2,
        reason:
            'a reconnect must coalesce onto the attempt already in flight, '
            'never start a second one — two concurrent resolutions race to '
            '_finalize and the loser can paint the older answer',
      );
      expect(
        _chatState(tester).debugReconnectCoalescedCount,
        2,
        reason:
            'both events were RECEIVED and deliberately folded. Without this '
            'the assertion above would also pass if the events never arrived',
      );

      net.gate = null;
      gate.complete();
      await _settleWellInsideTheFirstBackoffStep(tester);
    },
  );

  testWidgets(
    'CONTROL: a screen that resolved successfully makes ZERO attempts on a '
    'connectivity event',
    (tester) async {
      final net = _ReconnectDio()..healed = true;
      _register(net.dio);
      final bus = _installBus();
      bus.debugObserve(online: false);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _ReconnectDio.requestId));
      await _settleWellInsideTheFirstBackoffStep(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
      final afterResolve = net.resolutionAttempts;

      // Five genuine reconnects at a screen that already knows its answer.
      for (var i = 0; i < 5; i++) {
        _reconnect(bus);
        await _settleWellInsideTheFirstBackoffStep(tester, frames: 4);
      }

      _expectBackoffCannotHaveFired();
      expect(
        net.resolutionAttempts,
        afterResolve,
        reason:
            'the bus is app-wide, so every mounted chat screen receives every '
            'reconnect. A resolved screen turning that into a read is the poll '
            'the mandate bans wearing a different hat',
      );
      expect(_chatState(tester).debugReconnectPreemptCount, 0);
      expect(bus.emitCount, 5, reason: 'the events really were delivered');
    },
  );

  testWidgets(
    'FALLBACK INTACT: with no connectivity event ever, the bounded backoff '
    'still heals and is still bounded',
    (tester) async {
      final net = _ReconnectDio();
      _register(net.dio);
      _installBus();
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _ReconnectDio.requestId));
      await tester.pumpAndSettle();
      final coldAttempts = net.resolutionAttempts;
      expect(coldAttempts, 1, reason: 'one cold resolution');

      // A full minute of continuous failure, no connectivity event at all —
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      await tester.pumpAndSettle();

      final retries = net.resolutionAttempts - coldAttempts;
      expect(
        retries,
        greaterThan(0),
        reason: 'the backoff must still be the fallback — it was not deleted',
      );
      expect(
        retries,
        lessThanOrEqualTo(6),
        reason:
            'a 5 s cadence would be 12 in this window. Still a terminating '
            'backoff on a FAILED read, not a poll: attempts=$retries',
      );
      expect(find.byType(ChatResolutionErrorView), findsOneWidget);
    },
  );

  testWidgets(
    'NO HOT LOOP: a flapping transport cannot drive an unbounded retry rate',
    (tester) async {
      final net = _ReconnectDio();
      _register(net.dio);
      final bus = _installBus();
      bus.debugObserve(online: false);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _ReconnectDio.requestId));
      await _settleWellInsideTheFirstBackoffStep(tester);
      expect(net.resolutionAttempts, 1);

      // Twenty genuine offline→online edges. The gateway stays down throughout:
      for (var i = 0; i < 20; i++) {
        _reconnect(bus);
        await _settleWellInsideTheFirstBackoffStep(tester, frames: 6);
      }

      _expectBackoffCannotHaveFired();
      expect(bus.emitCount, 20, reason: 'every flap really was delivered');
      expect(
        net.resolutionAttempts,
        1 + kChatResolutionReconnectPreemptLimit,
        reason:
            'the cold attempt plus one pre-emption per backoff step, then the '
            'budget is spent and the bounded backoff owns the episode. Without '
            'the cap, 20 edges would be 20 reads with the clock frozen',
      );
      expect(find.byType(ChatResolutionErrorView), findsOneWidget);
    },
  );

  test(
    'the pre-emption budget is pinned to the backoff schedule, so widening one '
    'cannot silently leave the other behind',
    () {
      expect(
        kChatResolutionReconnectPreemptLimit,
        kChatResolutionRetryBackoff.length,
        reason:
            'the budget is documented as "one per step of '
            'kChatResolutionRetryBackoff"; this is that sentence, executable',
      );
    },
  );
}

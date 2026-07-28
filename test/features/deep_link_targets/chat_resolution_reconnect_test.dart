// THE RECONNECT MUST BE WHAT HEALS THE SCREEN — not a backoff tick that
// happens to land nearby.
//
// ## The falsified claim this suite exists to replace
//
// `chat_resolution_self_heal_test.dart` was merged asserting that the
// network-down chat resolution "SELF-HEALS on reconnect with no tap and no
// re-entry". An independent tester falsified it:
//
//   * SOURCE FACT — there was no connectivity subscriber anywhere in `lib/`.
//     Zero hits for `connectivity_plus`, `onConnectivityChanged`,
//     `ConnectivityResult`, `checkConnectivity`, `InternetAddress.lookup`,
//     `internet_connection_checker`, `network_info_plus`; none in
//     `pubspec.yaml`. Nothing in the app was listening for the network coming
//     back, so nothing could have reacted to it.
//   * TICK-SPACING IDENTITY — the observed 0.46 s heal tracked the BACKOFF
//     TIMER'S PHASE. Re-run with an independently-phased backoff, the heal
//     latency moved with the timer, not with the reconnect instant.
//
// The old suite's own DoD case shows exactly how it passed: it flips the
// network back on and then calls `tester.pump(const Duration(seconds: 3))` —
// three seconds, past the FIRST 2 s step of `kChatResolutionRetryBackoff`. The
// backoff heals it. That case passes identically with every connectivity
// subscriber in the app deleted, which is what makes it no evidence for the
// claim it was filed under.
//
// ## What makes THIS suite different
//
// **The fake clock never reaches the first backoff step.** Every wait below is
// `_settleWellInsideTheFirstBackoffStep`, which elapses 1 ms per frame and
// accumulates the total into `_elapsed`. Each discriminating assertion is
// preceded by `_expectBackoffCannotHaveFired()`, which asserts that total
// against `kChatResolutionRetryBackoff.first` (2 s). Typical totals here are
// tens of milliseconds — three orders of magnitude short. So when an attempt
// happens, a backoff tick provably is not what caused it.
//
// That the elapsed budget is MEASURED rather than asserted by construction
// matters: the first draft of this file used zero-duration pumps, on the
// reasoning that a pump elapsing nothing cannot fire a timer. True, and
// useless — Dio's request pipeline opens with `Future(() => ...)`, which is
// `Timer.run`, a zero-duration TIMER rather than a microtask. Measured: 40
// zero-duration pumps produced `requests=[]` and a screen still on its loading
// spinner. Had the assertions been written the other way round, that suite
// would have "passed" against a screen that never issued a single request.
//
// And it is corroborated by the NEGATIVE CONTROL: the identical pump budget,
// with the network fully restored but NO connectivity event delivered, leaves
// the screen dark and the attempt count unmoved. The event is the only
// difference between the two cases.
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
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

/// Offline until [healed] is flipped, then serves the live accepted-conversation
/// wire. When [gate] is non-null every conversation lookup is held open, so a
/// second trigger lands while the first attempt is genuinely in flight — the
/// only state in which a coalescing guard means anything.
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
  /// debug counter is deliberate — a debug counter is another instrument that
  /// could itself be wrong, and the wire is the thing the claim is about.
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
///
/// The two must not be the same clock. `NetworkReachabilitySignals` throttles
/// to one signal per [kNetworkReachabilityMinInterval]; if its clock were the
/// widget-test clock, the only way to deliver a second event would be to
/// advance fake time past 2 s — which would fire the backoff and destroy the
/// very discrimination these tests exist to make. Driving the bus clock by hand
/// lets a flap be delivered at t=0 on the widget clock.
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
///
/// `tester.pump()` with no duration flushes microtasks and produces a frame but
/// does not advance fake time, so a pending `Timer` cannot fire inside this
/// helper. Every discriminating assertion in this file is taken after this and
/// only this — which is what makes "an attempt happened" mean "the EVENT caused
/// it" rather than "something eventually ticked".
/// Fake time elapsed so far in the current test, accumulated by
/// [_settleWellInsideTheFirstBackoffStep]. Asserted against
/// `kChatResolutionRetryBackoff.first` at every discriminating assertion, so
/// "the backoff cannot have caused this" is MEASURED rather than assumed.
late Duration _elapsed;

/// One millisecond per frame.
///
/// A pump that elapses literally nothing is not usable here, and the reason is
/// worth recording because it is exactly the kind of thing that makes a test
/// silently vacuous: **Dio's request pipeline begins with `Future(() => ...)`,
/// which is `Timer.run` — a ZERO-DURATION TIMER, not a microtask.** `fakeAsync`
/// fires timers only when time is elapsed, so under `tester.pump()` with no
/// duration not one request ever reaches the wire (measured: 40 zero-pumps,
/// `requests=[]`, screen still `_loading`). A test built on that would have
/// asserted against a screen that never even tried.
///
/// One millisecond is the smallest step that lets those zero-duration timers
/// cascade, and it is 2000× smaller than the first backoff step.
const Duration _kPumpStep = Duration(milliseconds: 1);

/// Pump enough for the async resolution to complete, while keeping total
/// elapsed fake time orders of magnitude below the first backoff step.
///
/// The budget is generous rather than tuned (the probe showed ONE frame is
/// enough); what matters is not the frame count but that [_elapsed] stays under
/// `kChatResolutionRetryBackoff.first`, which the tests assert directly.
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
      // scenario the falsified claim was measured in.
      bus.debugObserve(online: false);
      final role = await _roleCubit(UserRole.client);
      addTearDown(role.close);

      await tester.pumpWidget(_host(role, _ReconnectDio.requestId));
      await _settleWellInsideTheFirstBackoffStep(tester);

      expect(
        find.byType(OmdsErrorStatePage),
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
      // route, and the clock stays three orders of magnitude short of the
      // first backoff step.
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
        find.byType(OmdsErrorStatePage),
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
      expect(find.byType(OmdsErrorStatePage), findsOneWidget);
      expect(net.resolutionAttempts, 1);

      // Identical to the discriminator EXCEPT that no event is delivered. The
      // network itself is perfectly healthy.
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
        find.byType(OmdsErrorStatePage),
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
      // genuinely in flight while the next two events arrive.
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
      // landing while attempt #2 is still on the wire.
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
      // the case a connectivity subscriber CANNOT cover (the router is up and
      // the gateway is down, so the OS never reports a change).
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
      expect(find.byType(OmdsErrorStatePage), findsOneWidget);
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
      // "the OS reports a transport" is not "the gateway answers".
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
      expect(find.byType(OmdsErrorStatePage), findsOneWidget);
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

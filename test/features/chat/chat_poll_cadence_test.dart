// ignore_for_file: avoid_dynamic_calls
//
// `ChatDetailScreen`'s State class is PRIVATE (`_ChatDetailScreenState`), so
// `tester.state(find.byType(ChatDetailScreen))` can only be typed as `dynamic`
// from a test. The alternative — widening the State class or adding a public
// accessor to production code purely so a test can name it — is worse than the
// lint. Scoped to this file, and only for that one call.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

const _resolvedConversationId = 'conversation-1';

class _CountingPollingGateway extends ChatGateway {
  int loadHistoryCalls = 0;
  String? lastConversationId;

  @override
  bool get supportsPolling => true;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    loadHistoryCalls++;
    lastConversationId = conversationId;
    return const <DeliveryChatMessage>[];
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async => message;

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

class _SummaryRecordingDio {
  _SummaryRecordingDio() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          totalRequests++;
          final path = options.path;
          Object? body = const <String, dynamic>{};
          if (path == '/v1/conversations') {
            body = <String, dynamic>{
              'id': conversationId,
              'phase': 'accepted',
              'requestId': requestId,
              'winnerJeeberId': 'jeeber-1',
            };
          } else if (path == '/v1/conversations/$conversationId/messages') {
            historyReads++;
            body = const <dynamic>[];
          } else if (path == '/v1/deliveries/$requestId') {
            deliveryReads++;
            body = <String, dynamic>{
              'id': requestId,
              'requestId': requestId,
              'status': 'InTransit',
              'amount': <String, dynamic>{'value': 9, 'currency': 'USD'},
            };
          } else if (path == '/v1/requests/$requestId') {
            requestReads++;
            body = <String, dynamic>{
              'displayId': 'ORD-1',
              'title': 'Deliver a parcel',
            };
          } else if (path == '/v1/offers') {
            offerReads++;
            body = const <String, dynamic>{'items': <dynamic>[]};
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

  static const conversationId = 'conv-summary-1';
  static const requestId = 'req-summary-1';

  late final Dio dio;
  int totalRequests = 0;
  int historyReads = 0;
  int deliveryReads = 0;
  int requestReads = 0;
  int offerReads = 0;

  int get summaryReads => deliveryReads + requestReads + offerReads;
}

ChatCubit _buildCubit(_CountingPollingGateway gateway) => ChatCubit(
  deliveryId: _resolvedConversationId,
  gateway: gateway,
  pickerService: StubPhotoPickerService(),
);

Widget _summaryHost(RoleCubit role, {Stream<void>? refreshSignals}) =>
    MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<RoleCubit>.value(
    value: role,
    child: ChatDetailScreen(
      chatId: _SummaryRecordingDio.requestId,
      refreshSignals: refreshSignals,
    ),
  ),
);

Future<RoleCubit> _clientRole() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

dynamic _summaryState(WidgetTester tester) =>
    tester.state(find.byType(ChatDetailScreen));

void _driveToBackground(WidgetTester tester) {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// Walks the wall clock past the 60s cadence the chat SUMMARY used to run at,
/// [count] times over. The constant is inlined rather than imported because
/// `kChatSummarySafetyNetPollInterval` no longer exists — the whole point of the
/// assertions below is that nothing happens at this interval any more. Keeping
/// the duration is what makes the absence assertion meaningful: a reintroduced
/// 60s summary poll fires [count] times inside this window.
Future<void> _pumpSummaryIntervals(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
  }
}

void main() {
  WidgetsBindingAppLifecycleGate? bindingGate;

  setUp(() {
    AppLifecycleGate.debugReset();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
  });

  tearDown(() {
    bindingGate?.dispose();
    bindingGate = null;
    AppLifecycleGate.debugReset();
    final sl = GetIt.instance;
    if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
  });

  test('AC2 G23 V1 presence control: a supportsPolling gateway DOES arm the '
      'history poller at the 60s constant over a 300s window', () {
    final gate = ManualAppLifecycleGate();
    AppLifecycleGate.install(gate);
    FakeAsync().run((async) {
      final gateway = _CountingPollingGateway();
      final cubit = _buildCubit(gateway);
      var loaded = false;
      cubit.load().then((_) => loaded = true);
      async.flushMicrotasks();

      expect(loaded, isTrue);
      expect(gateway.supportsPolling, isTrue);
      expect(gateway.lastConversationId, _resolvedConversationId);
      expect(gateway.loadHistoryCalls, 1, reason: 'initial read only');
      expect(cubit.debugHistoryTickCount, isZero);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      async.elapse(const Duration(seconds: 59));
      async.flushMicrotasks();
      expect(cubit.debugHistoryTickCount, isZero);
      expect(gateway.loadHistoryCalls, 1);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(cubit.debugHistoryTickCount, 1);
      expect(gateway.loadHistoryCalls, 2);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      for (var index = 0; index < 4; index++) {
        async.elapse(kChatHistorySafetyNetPollInterval);
        async.flushMicrotasks();
      }
      // M7 headroom: reverting 60s to 5s produces 60 ticks here, while the
      // exact threshold is 5 — a separation of 55 ticks.
      expect(cubit.debugHistoryTickCount, 5);
      expect(gateway.loadHistoryCalls, 6);
      expect(gateway.loadHistoryCalls, isNonZero);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      cubit.close();
      expect(cubit.debugHistoryPollerRunning, isFalse);
      async.flushMicrotasks();
      expect(async.periodicTimerCount, isZero);
    });
  });

  // b02 wave B.2 — INVERTED, not deleted. This used to be a PRESENCE control
  // asserting the summary poll armed at the 60s constant and ticked 5 times over
  // 300s. The mandate makes that shape the defect, so the assertion is flipped:
  // an assertion that a cadence is ABSENT is the only thing that can catch its
  // accidental return. The 300s window and the tick arithmetic are kept, only the
  // expected values invert — 5 ticks becomes 0 reads.
  testWidgets(
    'AC2 G23 V2 ABSENCE: the chat summary arms NO cadence — zero repeat reads '
    'over a 300s window, foregrounded, with no push and no user action',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      bindingGate = WidgetsBindingAppLifecycleGate();
      AppLifecycleGate.install(bindingGate!);
      final recorder = _SummaryRecordingDio();
      GetIt.instance.registerSingleton<Dio>(recorder.dio);
      final role = await _clientRole();
      addTearDown(role.close);
      final refresh = StreamController<void>.broadcast();
      addTearDown(refresh.close);

      await tester.pumpWidget(
        _summaryHost(role, refreshSignals: refresh.stream),
      );
      await tester.pumpAndSettle();
      final state = _summaryState(tester);
      final mountSummaryReads = recorder.summaryReads;

      // The refresh IS armed — this is not a dead screen, it is a screen with no
      // clock. The positive control below proves it can still fetch.
      expect(state.debugSummaryRefreshArmed, isTrue);
      expect(state.debugSummaryRefetchCount, isZero);

      // Past the old 60s boundary, then four more windows: 300s total.
      await tester.pump(const Duration(seconds: 59));
      await tester.pump();
      expect(recorder.summaryReads, mountSummaryReads);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        recorder.summaryReads,
        mountSummaryReads,
        reason: 'a 60s summary poll fired — the deleted cadence is back',
      );

      await _pumpSummaryIntervals(tester, 4);
      expect(
        state.debugSummaryRefetchCount,
        isZero,
        reason: 'a repeat summary read happened with no push and no user action',
      );
      expect(recorder.summaryReads, mountSummaryReads);

      // POSITIVE CONTROL, in the same test so a zero can never come from a
      // broken recorder or an unmounted screen: one push event fetches.
      refresh.add(null);
      await tester.pumpAndSettle();
      expect(state.debugSummaryRefetchCount, 1);
      expect(recorder.summaryReads, greaterThan(mountSummaryReads));

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'G23 V3 presence control: registered Dio lets a PUSH-driven summary refetch '
    'reach a non-zero network count',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      bindingGate = WidgetsBindingAppLifecycleGate();
      AppLifecycleGate.install(bindingGate!);
      final recorder = _SummaryRecordingDio();
      GetIt.instance.registerSingleton<Dio>(recorder.dio);
      final role = await _clientRole();
      addTearDown(role.close);
      final refresh = StreamController<void>.broadcast();
      addTearDown(refresh.close);

      await tester.pumpWidget(
        _summaryHost(role, refreshSignals: refresh.stream),
      );
      await tester.pumpAndSettle();
      final state = _summaryState(tester);
      final readsBeforeEvent = recorder.summaryReads;

      expect(GetIt.instance.isRegistered<Dio>(), isTrue);
      expect(state.debugSummaryRefreshArmed, isTrue);
      refresh.add(null);
      await tester.pumpAndSettle();
      expect(state.debugSummaryRefetchCount, 1);
      expect(recorder.summaryReads - readsBeforeEvent, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
    },
  );

  test('G23 V4 presence control: a resolved conversation id issues a non-zero '
      'full-history GET count', () async {
    final recorder = _SummaryRecordingDio();
    final gateway = DioChatGateway(dio: recorder.dio, currentUserId: 'user-1');
    addTearDown(gateway.dispose);

    expect(_SummaryRecordingDio.conversationId, isNot('new'));
    await gateway.loadHistory(_SummaryRecordingDio.conversationId);
    expect(recorder.historyReads, greaterThan(0));
  });

  testWidgets(
    'AC3 a backgrounded arm fires zero ticks and leaves no armed history timer '
    'over a 300s window — and the summary has no timer to leave',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      bindingGate = WidgetsBindingAppLifecycleGate();
      AppLifecycleGate.install(bindingGate!);

      final historyGateway = _CountingPollingGateway();
      final cubit = _buildCubit(historyGateway);
      addTearDown(cubit.close);
      await cubit.load();
      expect(historyGateway.supportsPolling, isTrue);
      expect(historyGateway.lastConversationId, _resolvedConversationId);
      expect(cubit.debugHistoryTickCount, isZero);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      final recorder = _SummaryRecordingDio();
      GetIt.instance.registerSingleton<Dio>(recorder.dio);
      final role = await _clientRole();
      addTearDown(role.close);
      final refresh = StreamController<void>.broadcast();
      addTearDown(refresh.close);
      await tester.pumpWidget(
        _summaryHost(role, refreshSignals: refresh.stream),
      );
      await tester.pumpAndSettle();
      final state = _summaryState(tester);

      expect(GetIt.instance.isRegistered<Dio>(), isTrue);
      expect(state.debugSummaryRefetchCount, isZero);
      expect(state.debugSummaryRefreshArmed, isTrue);

      // NOTE `_driveToBackground` walks resumed -> inactive -> hidden -> paused,
      // and that leading `resumed` legitimately fires the chat's foreground-resume
      // one-shot (a single catch-up read, explicitly allowed by the mandate — it
      // is caused by the app coming forward, not by a clock). So the baseline for
      // the absence assertion is taken AFTER the lifecycle walk settles; snapshot
      // it before and the one-shot reads as a poll.
      _driveToBackground(tester);
      await tester.pumpAndSettle();
      expect(cubit.debugHistoryPollerRunning, isFalse);
      final summaryReadsAtArm = recorder.summaryReads;
      final refetchesAtArm = state.debugSummaryRefetchCount;

      await _pumpSummaryIntervals(tester, 5);
      // Foreground-latch mutations produce 5 ticks in this five-interval
      // window, separated by 5 from the asserted zero threshold.
      expect(historyGateway.loadHistoryCalls, 1, reason: 'initial read only');
      // An inert-tick mutation leaves the read count green; only this explicit
      // timer-state assertion detects that the battery-costing timer survived.
      expect(cubit.debugHistoryPollerRunning, isFalse);
      // The summary needed a lifecycle gate only because it had a clock. With the
      // clock gone there is nothing to gate: a backgrounded chat issues zero
      // summary reads for the same reason a foregrounded one does.
      expect(recorder.summaryReads, summaryReadsAtArm);
      expect(state.debugSummaryRefetchCount, refetchesAtArm);

      await tester.pumpWidget(const SizedBox());
    },
  );
}

// ignore_for_file: avoid_dynamic_calls
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

ChatCubit _buildCubit(
  _CountingPollingGateway gateway, {
  Stream<void>? refreshSignals,
}) => ChatCubit(
  deliveryId: _resolvedConversationId,
  gateway: gateway,
  pickerService: StubPhotoPickerService(),
  refreshSignals: refreshSignals,
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

  // N4 — INVERTED, not deleted, exactly as V2 below was inverted in wave B.2.
  test('AC2 G23 V1 ABSENCE: a supportsPolling gateway arms NO history cadence '
      '— zero reads over a 300s window, and a push still reads', () {
    final gate = ManualAppLifecycleGate();
    AppLifecycleGate.install(gate);
    FakeAsync().run((async) {
      final gateway = _CountingPollingGateway();
      final bus = StreamController<void>.broadcast();
      final cubit = _buildCubit(gateway, refreshSignals: bus.stream);
      var loaded = false;
      cubit.load().then((_) => loaded = true);
      async.flushMicrotasks();

      expect(loaded, isTrue);
      expect(gateway.supportsPolling, isTrue);
      expect(gateway.lastConversationId, _resolvedConversationId);
      expect(gateway.loadHistoryCalls, 1, reason: 'the mount one-shot only');
      expect(
        async.periodicTimerCount,
        isZero,
        reason: 'leg 1: no periodic timer on a rendering thread',
      );

      async.elapse(const Duration(seconds: 59));
      async.flushMicrotasks();
      expect(gateway.loadHistoryCalls, 1);

      // The instant the retired cadence would have fired.
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(
        gateway.loadHistoryCalls,
        1,
        reason: 'the 60s boundary is no longer an event',
      );

      for (var index = 0; index < 4; index++) {
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
      }
      expect(
        gateway.loadHistoryCalls,
        1,
        reason: '300s window: the pre-fix value here was 6',
      );
      expect(async.periodicTimerCount, isZero);

      // POSITIVE CONTROL, same window, same instrument.
      bus.add(null);
      async.flushMicrotasks();
      expect(gateway.loadHistoryCalls, 2, reason: 'push drives one re-pull');

      cubit.close();
      bus.close();
      async.flushMicrotasks();
      expect(async.periodicTimerCount, isZero);
    });
  });

  // b02 wave B.2 — INVERTED, not deleted. This used to be a PRESENCE control
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
      expect(historyGateway.loadHistoryCalls, 1, reason: 'the mount one-shot');

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
      _driveToBackground(tester);
      await tester.pumpAndSettle();
      final summaryReadsAtArm = recorder.summaryReads;
      final refetchesAtArm = state.debugSummaryRefetchCount;

      await _pumpSummaryIntervals(tester, 5);
      // Foreground-latch mutations produce 5 ticks in this five-interval
      expect(historyGateway.loadHistoryCalls, 1, reason: 'mount read only');
      // The summary needed a lifecycle gate only because it had a clock. With the
      expect(recorder.summaryReads, summaryReadsAtArm);
      expect(state.debugSummaryRefetchCount, refetchesAtArm);

      await tester.pumpWidget(const SizedBox());
    },
  );
}

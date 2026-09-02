import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/obs_file_writer.dart';

/// Requires `flutter test --dart-define=JEEB_DEVTOOL_ENABLED=true …` to
/// exercise the `skip:`-guarded groups below — [kObsCompiledIn] is a hard
String get _needsDevtoolDefine =>
    'requires --dart-define=JEEB_DEVTOOL_ENABLED=true';

class _FakeSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];
  final List<bool> flushNowFlags = <bool>[];
  int flushCalls = 0;
  bool throwOnFlush = false;

  @override
  void add(ObsEvent event, {bool flushNow = false}) {
    events.add(event);
    flushNowFlags.add(flushNow);
  }

  @override
  Future<void> flush() async {
    flushCalls++;
    if (throwOnFlush) throw Exception('boom');
  }

  @override
  Future<void> close() async {}

  @override
  String? get sessionFilePath => '/fake/session.jsonl';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBase;

  setUp(() async {
    tempBase = await Directory.systemTemp.createTemp('observability_test');
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    ObsFileWriter.resetGlobalForTest();
  });

  tearDown(() async {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    ObsFileWriter.resetGlobalForTest();
    if (await tempBase.exists()) {
      await tempBase.delete(recursive: true);
    }
  });

  group('compile gate (runs in ANY invocation)', () {
    test('recording is false whenever kObsCompiledIn is false, regardless '
        'of the runtime toggle', () {
      if (kObsCompiledIn) return; // covered by the compiled-in group instead
      ObservabilityConfig.instance.enabled = true;
      expect(Observability.instance.recording, isFalse);
    });

    test('recordScreen/recordNotification/recordInteraction never touch the '
        'sink when not recording', () {
      final fake = _FakeSink();
      Observability.instance.sink = fake;
      // enabled=false alone forces `recording` false regardless of
      ObservabilityConfig.instance.enabled = false;

      Observability.instance.recordScreen(
        action: 'push',
        route: '/x',
        name: 'x',
      );
      Observability.instance.recordNotification(
        channel: 'fcm',
        mode: 'foreground',
        messageId: 'm-1',
        category: 'delivery',
      );
      Observability.instance.recordInteraction(gesture: 'tap');
      Observability.instance.record(
        ObsScreenEvent(
          id: '1-screen',
          sessionId: 's',
          timestampUtc: DateTime.utc(2026, 1, 1),
          seq: 1,
          action: 'push',
          route: '/x',
          name: 'x',
        ),
      );

      expect(fake.events, isEmpty);
    });

    test('install() is a hard no-op when kObsCompiledIn is false', () async {
      if (kObsCompiledIn) return;
      await Observability.instance.install(
        role: 'client',
        baseDirectoryProvider: () async => tempBase,
      );
      expect(Observability.instance.sessionId, isNull);
      expect(Observability.instance.sink, isNull);
      expect(Directory('${tempBase.path}/obs_trace').existsSync(), isFalse);
    });
  });

  group('pure helpers (no gate — always active)', () {
    test('nextSeq() is monotonic starting at 1', () {
      expect(Observability.instance.nextSeq(), 1);
      expect(Observability.instance.nextSeq(), 2);
      expect(Observability.instance.nextSeq(), 3);
    });

    test('newEventId formats <seq>-<type>', () {
      expect(Observability.instance.newEventId(ObsEventType.api, 42), '42-api');
      expect(
        Observability.instance.newEventId(ObsEventType.screen, 1),
        '1-screen',
      );
    });

    test('currentScreen is a plain settable field', () {
      expect(Observability.instance.currentScreen, isNull);
      Observability.instance.currentScreen = '/home';
      expect(Observability.instance.currentScreen, '/home');
    });

    test('flush() is a no-op when no sink is installed', () async {
      await Observability.instance.flush(); // must not throw
    });

    test('resetForTest restores clock/sink/sessionId/seq/currentScreen', () {
      Observability.instance.currentScreen = '/x';
      Observability.instance.sink = _FakeSink();
      Observability.instance.nextSeq();
      Observability.instance.resetForTest();

      expect(Observability.instance.currentScreen, isNull);
      expect(Observability.instance.sink, isNull);
      expect(Observability.instance.sessionId, isNull);
      expect(Observability.instance.nextSeq(), 1);
    });
  });

  group('recording behaviour (compiled-in)', () {
    setUp(() {
      ObservabilityConfig.instance.enabled = true;
    });

    test(
      'recordScreen builds + delivers a fully-stamped ObsScreenEvent',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;
        Observability.instance.clock = () => DateTime.utc(2026, 7, 18, 10, 30);

        Observability.instance.recordScreen(
          action: 'push',
          route: '/orders/:id',
          name: 'order-detail',
          previousRoute: '/home',
          params: const {'id': 'd-1'},
        );

        expect(fake.events, hasLength(1));
        final event = fake.events.single as ObsScreenEvent;
        expect(event.id, '1-screen');
        expect(event.seq, 1);
        expect(event.action, 'push');
        expect(event.route, '/orders/:id');
        expect(event.previousRoute, '/home');
        expect(event.timestampUtc, DateTime.utc(2026, 7, 18, 10, 30));
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'recordNotification and recordInteraction deliver their subtype',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        Observability.instance.recordNotification(
          channel: 'fcm',
          mode: 'opened',
          messageId: 'm-1',
          category: 'delivery',
          deepLink: '/orders/d-1',
        );
        Observability.instance.recordInteraction(
          gesture: 'tap',
          targetId: 'submit',
          screen: '/checkout',
        );

        expect(fake.events, hasLength(2));
        expect(fake.events[0], isA<ObsNotificationEvent>());
        expect(fake.events[1], isA<ObsInteractionEvent>());
        final notification = fake.events[0] as ObsNotificationEvent;
        expect(notification.deepLink, '/orders/d-1');
        final interaction = fake.events[1] as ObsInteractionEvent;
        expect(interaction.targetId, 'submit');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'seq is one shared monotonic counter across all signal types',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;

        Observability.instance.recordScreen(
          action: 'push',
          route: '/a',
          name: 'a',
        );
        Observability.instance.recordInteraction(gesture: 'tap');
        Observability.instance.recordNotification(
          channel: 'fcm',
          mode: 'opened',
          messageId: 'm',
          category: 'c',
        );

        expect(fake.events.map((e) => e.seq), [1, 2, 3]);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'a per-signal toggle OFF suppresses only that signal',
      () {
        final fake = _FakeSink();
        Observability.instance.sink = fake;
        ObservabilityConfig.instance.captureScreens = false;

        Observability.instance.recordScreen(
          action: 'push',
          route: '/a',
          name: 'a',
        );
        Observability.instance.recordInteraction(gesture: 'tap');

        expect(fake.events, hasLength(1));
        expect(fake.events.single, isA<ObsInteractionEvent>());
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test('record() flags flushNow for a failed/transport-error api event, not '
        'for a 2xx one', () {
      final fake = _FakeSink();
      Observability.instance.sink = fake;
      final ok = ObsApiEvent(
        id: '1-api',
        sessionId: 's',
        timestampUtc: DateTime.utc(2026, 1, 1),
        seq: 1,
        method: 'GET',
        path: '/x',
        statusCode: 200,
        durationMs: 1,
      );
      final serverError = ObsApiEvent(
        id: '2-api',
        sessionId: 's',
        timestampUtc: DateTime.utc(2026, 1, 1),
        seq: 2,
        method: 'GET',
        path: '/x',
        statusCode: 500,
        durationMs: 1,
      );
      final transportFailure = ObsApiEvent(
        id: '3-api',
        sessionId: 's',
        timestampUtc: DateTime.utc(2026, 1, 1),
        seq: 3,
        method: 'GET',
        path: '/x',
        statusCode: null,
        durationMs: 1,
      );

      Observability.instance.record(ok);
      Observability.instance.record(serverError);
      Observability.instance.record(transportFailure);

      expect(fake.flushNowFlags, [false, true, true]);
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test('events recorded before install() resolves fall back to the '
        'unknown-session id rather than crashing', () {
      final fake = _FakeSink();
      Observability.instance.sink = fake;
      Observability.instance.recordScreen(
        action: 'push',
        route: '/a',
        name: 'a',
      );

      expect(fake.events.single.sessionId, 'unknown-session');
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test(
      'flush() delegates to the sink and is fail-soft on a throwing sink',
      () async {
        final fake = _FakeSink()..throwOnFlush = true;
        Observability.instance.sink = fake;

        await Observability.instance.flush(); // must not throw
        expect(fake.flushCalls, 1);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test('install() mints a stamp-role session id and wires a real '
        'ObsFileWriter as the sink', () async {
      Observability.instance.clock = () =>
          DateTime.utc(2026, 7, 18, 10, 30, 15, 123);

      await Observability.instance.install(
        role: 'client',
        baseDirectoryProvider: () async => tempBase,
      );

      expect(
        Observability.instance.sessionId,
        '2026-07-18T10-30-15-123Z-client',
      );
      expect(Observability.instance.sink, isA<ObsFileWriter>());
      await Observability.instance.flush();
      expect(
        File(
          '${tempBase.path}/obs_trace/'
          '2026-07-18T10-30-15-123Z-client.jsonl',
        ).existsSync(),
        isTrue,
      );
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test(
      'install failure returns false without latching, then a retry succeeds',
      () async {
        final failed = await Observability.instance.install(
          role: 'client',
          baseDirectoryProvider: () async =>
              throw const FileSystemException('disk unavailable'),
        );
        expect(failed, isFalse);
        expect(Observability.instance.sessionId, isNull);
        expect(Observability.instance.sink, isNull);

        final retry = await Observability.instance.install(
          role: 'client',
          baseDirectoryProvider: () async => tempBase,
        );
        expect(retry, isTrue);
        expect(Observability.instance.sessionId, isNotNull);
        expect(Observability.instance.sink?.sessionFilePath, isNotNull);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'install() is idempotent — a second call keeps the first session id',
      () async {
        await Observability.instance.install(
          role: 'client',
          baseDirectoryProvider: () async => tempBase,
        );
        final firstId = Observability.instance.sessionId;
        await Observability.instance.install(
          role: 'jeeber',
          baseDirectoryProvider: () async => tempBase,
        );
        expect(Observability.instance.sessionId, firstId);
        // Settle async IO before tearDown wipes tempBase.
        await Observability.instance.flush();
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/obs_export_bundle.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/obs_overlay_controller.dart';
import 'package:share_plus/share_plus.dart';

String get _needsDevtoolDefines =>
    'requires JEEB_DEVTOOL_ENABLED=true and JEEB_OBS_OVERLAY=true';

final class _FakeSink implements ObservabilitySink {
  _FakeSink({this.flushGate, this.path = '/tmp/jeeb-session.jsonl'});

  final List<ObsEvent> events = <ObsEvent>[];
  final Completer<void>? flushGate;
  final String? path;
  int flushCalls = 0;

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> flush() async {
    flushCalls++;
    await flushGate?.future;
  }

  @override
  Future<void> close() => flush();

  @override
  String? get sessionFilePath => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  test('a compiled-in recorder still defaults stopped', () {
    expect(ObservabilityConfig.instance.enabled, isFalse);
    expect(Observability.instance.recording, isFalse);
  });

  test('the legacy redaction toggle cannot turn redaction off', () {
    // ignore: deprecated_member_use_from_same_package
    ObservabilityConfig.instance.redactionEnabled = false;
    // ignore: deprecated_member_use_from_same_package
    expect(ObservabilityConfig.instance.redactionEnabled, isTrue);
  });

  test(
    'Start records; Stop disables immediately, flushes, and blocks later events',
    () async {
      final flushGate = Completer<void>();
      final sink = _FakeSink(flushGate: flushGate);
      Observability.instance.sink = sink;
      final controller = ObsOverlayController(install: () async => true)
        ..attach();
      addTearDown(controller.dispose);

      await controller.start();
      expect(controller.recording, isTrue);
      Observability.instance.recordScreen(
        action: 'push',
        route: '/home',
        name: 'home',
      );

      final stopping = controller.stop();
      expect(controller.recording, isFalse);
      Observability.instance.recordScreen(
        action: 'push',
        route: '/should-not-append',
        name: 'blocked',
      );
      expect(sink.events, hasLength(1));
      expect(controller.totalBuffered, 1);

      flushGate.complete();
      await stopping;
      expect(sink.flushCalls, 1);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Stop during a pending Start prevents the stale Start from re-enabling',
    () async {
      final installGate = Completer<bool>();
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      final controller = ObsOverlayController(
        install: () => installGate.future,
      );
      addTearDown(controller.dispose);

      final starting = controller.start();
      await controller.stop();
      installGate.complete(true);
      await starting;

      expect(controller.recording, isFalse);
      expect(ObservabilityConfig.instance.enabled, isFalse);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Start failure stays stopped, surfaces an error, and a retry can succeed',
    () async {
      var attempt = 0;
      Observability.instance.sink = _FakeSink(path: null);
      final controller = ObsOverlayController(
        install: () async {
          attempt++;
          if (attempt == 1) throw StateError('disk unavailable');
          Observability.instance.sink = _FakeSink();
          return true;
        },
      );
      addTearDown(controller.dispose);

      await controller.start();
      expect(controller.recording, isFalse);
      expect(controller.lastErrorMessage, contains('storage is unavailable'));

      await controller.start();
      expect(controller.recording, isTrue);
      expect(controller.lastErrorMessage, isNull);
      expect(attempt, 2);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Start rejects an empty storage path',
    () async {
      Observability.instance.sink = _FakeSink(path: '');
      final controller = ObsOverlayController(install: () async => true);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.recording, isFalse);
      expect(controller.lastErrorMessage, contains('storage is unavailable'));
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Start emits one snapshot event for the route tracked while stopped',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      Observability.instance.currentScreen = '/orders/:id';
      final controller = ObsOverlayController(install: () async => true)
        ..attach();
      addTearDown(controller.dispose);

      await controller.start();

      final event = sink.events.single as ObsScreenEvent;
      expect(event.action, 'snapshot');
      expect(event.route, '/orders/:id');
      expect(controller.totalBuffered, 1);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Stop drains a marked request before its final flush',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      Observability.instance.setSessionForTest('drain-session');
      final controller = ObsOverlayController(install: () async => true)
        ..attach();
      addTearDown(controller.dispose);
      await controller.start();
      final capture = Observability.instance.beginApiCapture()!;

      final stopping = controller.stop();
      expect(controller.recording, isFalse);
      expect(sink.flushCalls, 0);

      Observability.instance.completeApiCapture(
        capture,
        ObsApiEvent(
          id: '${capture.seq}-api',
          sessionId: capture.sessionId,
          timestampUtc: DateTime.utc(2026, 8, 29),
          seq: capture.seq,
          method: 'GET',
          path: '/v1/in-flight',
          statusCode: 200,
          durationMs: 12,
        ),
      );
      await stopping;

      expect(sink.events.single, isA<ObsApiEvent>());
      expect(sink.flushCalls, 1);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Stop abandons a hung marked request after its bounded timeout',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      Observability.instance.setSessionForTest('timeout-session');
      final controller = ObsOverlayController(
        install: () async => true,
        stopDrainTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(Observability.instance.beginApiCapture(), isNotNull);

      await controller.stop();

      expect(Observability.instance.outstandingApiCount, 0);
      expect(sink.flushCalls, 1);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'repeated Start/Stop intervals reach the two-file export and actual share '
    'result',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      var now = DateTime.utc(2026, 8, 29, 10);
      List<ObsRecordingInterval>? exportedIntervals;
      List<XFile>? sharedFiles;
      final controller = ObsOverlayController(
        install: () async => true,
        clock: () => now,
        buildExportBundle: (sourcePath, intervals) async {
          expect(sourcePath, sink.sessionFilePath);
          exportedIntervals = intervals;
          return const ObsExportBundle(
            obsPath: '/tmp/frozen-obs.jsonl',
            diagPath: '/tmp/frozen-diag.jsonl',
          );
        },
        share: (files, subject) async {
          sharedFiles = files;
          expect(subject, 'frozen-obs.jsonl');
          return const ShareResult('shared', ShareResultStatus.success);
        },
      );
      addTearDown(controller.dispose);

      await controller.start();
      now = DateTime.utc(2026, 8, 29, 10, 1);
      await controller.stop();
      now = DateTime.utc(2026, 8, 29, 10, 2);
      await controller.start();
      now = DateTime.utc(2026, 8, 29, 10, 3);
      await controller.stop();
      await controller.exportAndShare();

      expect(exportedIntervals, hasLength(2));
      expect(exportedIntervals![0].startUtc, DateTime.utc(2026, 8, 29, 10));
      expect(exportedIntervals![0].endUtc, DateTime.utc(2026, 8, 29, 10, 1));
      expect(exportedIntervals![1].startUtc, DateTime.utc(2026, 8, 29, 10, 2));
      expect(exportedIntervals![1].endUtc, DateTime.utc(2026, 8, 29, 10, 3));
      expect(sharedFiles, hasLength(2));
      expect(controller.lastExportSucceeded, isTrue);
      expect(controller.lastExportMessage, contains('2 local trace'));
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Export stops an active recording before building the frozen snapshots',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      var builtWhileRecording = true;
      late final ObsOverlayController controller;
      controller = ObsOverlayController(
        install: () async => true,
        buildExportBundle: (_, _) async {
          builtWhileRecording = controller.recording;
          return const ObsExportBundle(obsPath: '/tmp/frozen-obs.jsonl');
        },
        share: (_, _) async =>
            const ShareResult('shared', ShareResultStatus.success),
      );
      addTearDown(controller.dispose);
      await controller.start();

      await controller.exportAndShare();

      expect(builtWhileRecording, isFalse);
      expect(controller.recording, isFalse);
      expect(sink.flushCalls, greaterThanOrEqualTo(2));
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Start queued during Stop drain also waits for a later Export snapshot',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      Observability.instance.setSessionForTest('drain-export-session');
      var installCalls = 0;
      var buildCalls = 0;
      final controller = ObsOverlayController(
        install: () async {
          installCalls++;
          return true;
        },
        buildExportBundle: (_, _) async {
          buildCalls++;
          return const ObsExportBundle(obsPath: '/tmp/frozen-obs.jsonl');
        },
        share: (_, _) async =>
            const ShareResult('shared', ShareResultStatus.success),
      );
      addTearDown(controller.dispose);
      await controller.start();
      final capture = Observability.instance.beginApiCapture()!;

      final stopping = controller.stop();
      var queuedStartCompleted = false;
      final queuedStart = controller.start().whenComplete(
        () => queuedStartCompleted = true,
      );
      final exporting = controller.exportAndShare();
      await pumpEventQueue();

      expect(controller.recording, isFalse);
      expect(queuedStartCompleted, isFalse);
      expect(installCalls, 1);
      expect(buildCalls, 0);

      Observability.instance.completeApiCapture(
        capture,
        ObsApiEvent(
          id: '${capture.seq}-api',
          sessionId: capture.sessionId,
          timestampUtc: DateTime.utc(2026, 8, 29),
          seq: capture.seq,
          method: 'GET',
          path: '/v1/requests/:value',
          statusCode: 200,
          durationMs: 1,
        ),
      );
      await stopping;
      await queuedStart;
      await exporting;

      expect(buildCalls, 1);
      expect(installCalls, 2);
      expect(controller.recording, isTrue);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Start requested inside bundle creation waits for the build gate',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      var installCalls = 0;
      final buildEntered = Completer<void>();
      final buildGate = Completer<ObsExportBundle?>();
      final controller = ObsOverlayController(
        install: () async {
          installCalls++;
          return true;
        },
        buildExportBundle: (_, _) {
          buildEntered.complete();
          return buildGate.future;
        },
        share: (_, _) async =>
            const ShareResult('shared', ShareResultStatus.success),
      );
      addTearDown(controller.dispose);
      await controller.start();

      final exporting = controller.exportAndShare();
      await buildEntered.future;
      var queuedStartCompleted = false;
      final queuedStart = controller.start().whenComplete(
        () => queuedStartCompleted = true,
      );
      await pumpEventQueue();

      expect(controller.recording, isFalse);
      expect(queuedStartCompleted, isFalse);
      expect(installCalls, 1);

      buildGate.complete(
        const ObsExportBundle(obsPath: '/tmp/frozen-obs.jsonl'),
      );
      await queuedStart;
      await exporting;

      expect(installCalls, 2);
      expect(controller.recording, isTrue);
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );

  test(
    'Export surfaces snapshot failures without opening the share sheet',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      var shareCalls = 0;
      final controller = ObsOverlayController(
        install: () async => true,
        buildExportBundle: (_, _) async => throw StateError('disk full'),
        share: (_, _) async {
          shareCalls++;
          return const ShareResult('shared', ShareResultStatus.success);
        },
      );
      addTearDown(controller.dispose);
      await controller.start();
      await controller.stop();

      await controller.exportAndShare();

      expect(shareCalls, 0);
      expect(controller.lastExportSucceeded, isFalse);
      expect(controller.lastExportedPath, isNull);
      expect(controller.lastExportMessage, contains('Export failed'));
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );
}

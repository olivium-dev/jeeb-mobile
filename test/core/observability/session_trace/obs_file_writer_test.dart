import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/obs_file_writer.dart';

const String _fakeJwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEiLCJleHAiOjk5OTk5OTk5OTl9.S3cReTtOkEnLeAk';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBase;

  ObsFileWriter makeWriter({
    String sessionId = '2026-07-18T10-30-15-123Z-client',
    String role = 'client',
    Map<String, Object?> sessionMeta = const {'model': 'testbox'},
    int maxSessions = 5,
    int maxTotalBytes = 20 * 1024 * 1024,
    int maxSessionBytes = 10 * 1024 * 1024,
    int flushThresholdLines = 32,
    int maxPendingLines = 512,
    DateTime Function()? clock,
    Future<Directory> Function()? baseDirectoryProvider,
  }) {
    return ObsFileWriter(
      baseDirectoryProvider: baseDirectoryProvider ?? () async => tempBase,
      sessionId: sessionId,
      role: role,
      sessionMeta: sessionMeta,
      maxSessions: maxSessions,
      maxTotalBytes: maxTotalBytes,
      maxSessionBytes: maxSessionBytes,
      flushThresholdLines: flushThresholdLines,
      maxPendingLines: maxPendingLines,
      clock: clock,
    );
  }

  Directory obsDir() => Directory('${tempBase.path}/obs_trace');

  ObsApiEvent apiEvent({
    int seq = 1,
    int? status = 200,
    Map<String, Object?> requestHeaders = const {},
    Object? responseBody,
    String? errorMessage,
  }) {
    return ObsApiEvent(
      id: '$seq-api',
      sessionId: 'sess-1',
      timestampUtc: DateTime.utc(2026, 7, 18, 10, 30, 16),
      seq: seq,
      method: 'GET',
      path: '/v1/x',
      statusCode: status,
      durationMs: 12,
      requestHeaders: requestHeaders,
      responseBody: responseBody,
      errorMessage: errorMessage,
    );
  }

  ObsScreenEvent screenEvent({int seq = 1}) => ObsScreenEvent(
        id: '$seq-screen',
        sessionId: 'sess-1',
        timestampUtc: DateTime.utc(2026, 7, 18, 10, 30, 16),
        seq: seq,
        action: 'push',
        route: '/orders/:id',
        name: 'order-detail',
      );

  Future<List<Map<String, dynamic>>> readSession(ObsFileWriter writer) async {
    final path = writer.sessionFilePath;
    expect(path, isNotNull, reason: 'session file should exist');
    final raw = await File(path!).readAsString();
    return raw
        .trim()
        .split('\n')
        .where((l) => l.isNotEmpty)
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .toList();
  }

  setUp(() async {
    tempBase = await Directory.systemTemp.createTemp('obs_writer_test');
  });

  tearDown(() async {
    ObsFileWriter.resetGlobalForTest();
    if (await tempBase.exists()) {
      await tempBase.delete(recursive: true);
    }
  });

  group('session file + header shape', () {
    test('creates obs_trace/<sessionId>.jsonl under the base dir', () async {
      final writer = makeWriter(sessionId: 'stamp-client');
      await writer.start();
      await writer.flush();

      expect(writer.directoryPath, '${tempBase.path}/obs_trace');
      expect(
        writer.sessionFilePath,
        '${tempBase.path}/obs_trace/stamp-client.jsonl',
      );
      expect(File(writer.sessionFilePath!).existsSync(), isTrue);
    });

    test('line 1 is the session header: version, device meta, role, '
        'sessionId, ts', () async {
      final writer = makeWriter(
        sessionMeta: const {'model': 'Pixel 8', 'os': 'android'},
        clock: () => DateTime.utc(2026, 7, 18, 10, 30, 15),
      );
      await writer.start();
      await writer.flush();

      final records = await readSession(writer);
      final header = records.first;
      expect(header['type'], 'session');
      expect(header['v'], ObsEvent.schemaVersion);
      expect(header['appVersion'], ObsFileWriter.appVersion);
      expect(header['model'], 'Pixel 8');
      expect(header['os'], 'android');
      expect(header['role'], 'client');
      expect(header['sessionId'], writer.sessionId);
      expect(header['file'], writer.sessionFilePath);
      expect(header['ts'], '2026-07-18T10:30:15.000Z');
      expect(header.containsKey('buildSha'), isFalse);
    });

    test('the file is pure JSONL — every line decodes as JSON', () async {
      final writer = makeWriter();
      await writer.start();
      writer.add(screenEvent());
      await writer.flush();

      final records = await readSession(writer);
      expect(records, hasLength(2)); // header + 1 event
      expect(records[1]['type'], 'screen');
    });
  });

  group('buffering + flush behaviour (never block, never lose the tail)', () {
    test('events added BEFORE start() land in the file AFTER the header',
        () async {
      final writer = makeWriter();
      writer.add(screenEvent(seq: 1));
      writer.add(screenEvent(seq: 2));
      await writer.start();
      await writer.flush();

      final records = await readSession(writer);
      expect(records.first['type'], 'session');
      expect(records[1]['seq'], 1);
      expect(records[2]['seq'], 2);
    });

    test('below the flush threshold, lines stay buffered until flush()',
        () async {
      final writer = makeWriter(flushThresholdLines: 1000);
      await writer.start();
      await writer.flush(); // header on disk
      writer.add(screenEvent(seq: 9));
      await pumpEventQueue();

      var raw = await File(writer.sessionFilePath!).readAsString();
      expect(raw, isNot(contains('"seq":9')));

      await writer.flush();
      raw = await File(writer.sessionFilePath!).readAsString();
      expect(raw, contains('"seq":9'));
    });

    test('reaching the line threshold flushes WITHOUT an explicit flush()',
        () async {
      final writer = makeWriter(flushThresholdLines: 3);
      await writer.start();
      await writer.flush(); // drain header → buffer empty
      writer.add(screenEvent(seq: 1));
      writer.add(screenEvent(seq: 2));
      writer.add(screenEvent(seq: 3)); // hits threshold
      await pumpEventQueue();

      final raw = await File(writer.sessionFilePath!).readAsString();
      expect(raw, contains('"seq":1'));
      expect(raw, contains('"seq":2'));
      expect(raw, contains('"seq":3'));
    });

    test('a FAILURE api event (flushNow) force-flushes so a crash cannot '
        'lose it', () async {
      final writer = makeWriter(flushThresholdLines: 1000);
      await writer.start();
      writer.add(apiEvent(status: 500), flushNow: true);
      await writer.pendingIo;

      final raw = await File(writer.sessionFilePath!).readAsString();
      expect(raw, contains('"status":500'));
    });

    test('maxPendingLines overflow drops the newest lines with a drop marker',
        () async {
      final writer = makeWriter(maxPendingLines: 2, flushThresholdLines: 100);
      // Not started yet, so nothing drains — the 3rd add overflows.
      writer.add(screenEvent(seq: 1));
      writer.add(screenEvent(seq: 2));
      writer.add(screenEvent(seq: 3));
      await writer.start();
      await writer.flush();

      final raw = await File(writer.sessionFilePath!).readAsString();
      expect(raw, contains('obs_lines_dropped'));
    });
  });

  group('rotation (size-capped, oldest-first)', () {
    Future<File> plantSession(String stamp, {int bytes = 100}) async {
      final dir = obsDir();
      await dir.create(recursive: true);
      final file = File('${dir.path}/$stamp.jsonl');
      await file.writeAsString('x' * bytes);
      return file;
    }

    test('keeps at most maxSessions files including the new session',
        () async {
      for (var i = 1; i <= 5; i++) {
        await plantSession('2020-01-0$i-old');
      }
      final writer = makeWriter(maxSessions: 3, sessionId: 'current');
      await writer.start();
      await writer.flush();

      final names = obsDir()
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .toList()
        ..sort();
      expect(names, hasLength(3));
      expect(names[0], startsWith('2020-01-04'));
      expect(names[1], startsWith('2020-01-05'));
      expect(names[2], 'current.jsonl');
    });

    test('prunes oldest-first until the total size cap is met', () async {
      await plantSession('2020-01-01-a', bytes: 6 * 1024);
      await plantSession('2020-01-02-b', bytes: 6 * 1024);
      await plantSession('2020-01-03-c', bytes: 6 * 1024);
      final writer = makeWriter(
        maxTotalBytes: 10 * 1024,
        maxSessions: 10,
        sessionId: 'current',
      );
      await writer.start();
      await writer.flush();

      final names = obsDir().listSync().whereType<File>().map(
            (f) => f.path.split('/').last,
          );
      expect(names.where((n) => n.startsWith('2020-01-01')), isEmpty);
      expect(names.where((n) => n.startsWith('2020-01-02')), isEmpty);
      expect(names.where((n) => n.startsWith('2020-01-03')), hasLength(1));
    });

    test('a session stops at maxSessionBytes with a single capped marker',
        () async {
      final writer =
          makeWriter(maxSessionBytes: 600, flushThresholdLines: 1);
      await writer.start();
      for (var i = 0; i < 50; i++) {
        writer.add(apiEvent(seq: i, responseBody: {'pad': 'x' * 40}));
      }
      await writer.flush();
      writer.add(screenEvent(seq: 999));
      await writer.flush();

      final raw = await File(writer.sessionFilePath!).readAsString();
      expect(
        RegExp('obs_session_capped').allMatches(raw).length,
        1,
        reason: 'exactly one cap marker',
      );
      expect(raw, isNot(contains('"seq":999')));
      expect(File(writer.sessionFilePath!).lengthSync(), lessThan(6000));
    });
  });

  group('fail-soft IO (must never crash the app)', () {
    test('a throwing directory provider breaks the sink silently', () async {
      final writer = makeWriter(
        baseDirectoryProvider: () async =>
            throw const FileSystemException('disk full'),
      );
      await writer.start(); // must not throw
      expect(writer.isBroken, isTrue);
      writer.add(screenEvent()); // must not throw either
      await writer.flush();
      expect(writer.sessionFilePath, isNull);
    });

    test('an append failure after start trips the breaker, no exception',
        () async {
      final writer = makeWriter(flushThresholdLines: 1);
      await writer.start();
      await writer.flush();
      await obsDir().delete(recursive: true);

      writer.add(screenEvent());
      await writer.flush(); // swallows the IO error
      expect(writer.isBroken, isTrue);

      writer.add(screenEvent(seq: 2));
      await writer.flush(); // still must not throw
    });
  });

  group('redaction end-to-end (defensive second scrub)', () {
    test('a raw secret smuggled into an event never reaches disk', () async {
      final writer = makeWriter();
      await writer.start();
      // Simulates a capturer MISTAKE: a raw Authorization header handed to
      // the model directly instead of through SecretRedactor first.
      writer.add(apiEvent(
        requestHeaders: {'authorization': 'Bearer $_fakeJwt'},
        responseBody: {'fcmToken': _fakeJwt},
        errorMessage: 'failed for Bearer $_fakeJwt',
      ));
      await writer.flush();

      final raw = await File(writer.sessionFilePath!).readAsString();
      expect(raw, isNot(contains(_fakeJwt)));
      expect(raw, isNot(contains('Bearer ')));
      // Still observable: the call itself is not swallowed.
      expect(raw, contains('/v1/x'));
    });
  });

  group('installAsGlobal — release gate (runs in ANY invocation)', () {
    test('kObsCompiledIn false ⇒ hard no-op: no writer, no dir, no file',
        () async {
      final result = await ObsFileWriter.installAsGlobal(
        sessionId: 'x',
        role: 'client',
        baseDirectoryProvider: () async => tempBase,
      );
      if (!kObsCompiledIn) {
        expect(result, isNull);
        expect(ObsFileWriter.active, isNull);
        expect(obsDir().existsSync(), isFalse);
      } else {
        // This test invocation was run WITH the devtool define — the
        // "compiled in" group below covers that path instead. Settle the
        // writer's async IO chain before tearDown tears down tempBase, or
        // the recursive delete can race the in-flight header write.
        expect(result, isNotNull);
        await result!.flush();
      }
    });
  });

  group('installAsGlobal — compiled-in behaviour', () {
    test(
      'installs, starts the session, emits the sub PREFIX only',
      () async {
        final writer = await ObsFileWriter.installAsGlobal(
          sessionId: 'jeeber-session',
          role: 'jeeber',
          baseDirectoryProvider: () async => tempBase,
          subLookup: () async => 'a1b2c3d4-e5f6-7890-abcd-ef0123456789',
        );
        expect(writer, isNotNull);
        expect(ObsFileWriter.active, same(writer));
        await writer!.flush();

        final records = await readSession(writer);
        expect(records.first['type'], 'session');
        expect(records.first['role'], 'jeeber');
        final meta = records.singleWhere((r) => r['name'] == 'session_meta');
        expect((meta['data'] as Map)['subPrefix'], 'a1b2c3d4');
        final raw = await File(writer.sessionFilePath!).readAsString();
        expect(raw, isNot(contains('ef0123456789')));
      },
      skip: kObsCompiledIn
          ? false
          : 'requires --dart-define=JEEB_DEVTOOL_ENABLED=true',
    );

    test(
      'is idempotent — a second install keeps the first writer',
      () async {
        final first = await ObsFileWriter.installAsGlobal(
          sessionId: 'a',
          role: 'client',
          baseDirectoryProvider: () async => tempBase,
        );
        final second = await ObsFileWriter.installAsGlobal(
          sessionId: 'b',
          role: 'jeeber',
          baseDirectoryProvider: () async => tempBase,
        );
        expect(second, same(first));
        await first?.flush(); // settle async IO before tearDown wipes tempBase
      },
      skip: kObsCompiledIn
          ? false
          : 'requires --dart-define=JEEB_DEVTOOL_ENABLED=true',
    );

    test(
      'a failing sub lookup is best-effort — session still records',
      () async {
        final writer = await ObsFileWriter.installAsGlobal(
          sessionId: 'x',
          role: 'client',
          baseDirectoryProvider: () async => tempBase,
          subLookup: () async => throw Exception('keystore locked'),
        );
        writer!.add(screenEvent());
        await writer.flush();
        final raw = await File(writer.sessionFilePath!).readAsString();
        expect(raw, contains('"type":"screen"'));
      },
      skip: kObsCompiledIn
          ? false
          : 'requires --dart-define=JEEB_DEVTOOL_ENABLED=true',
    );
  });
}

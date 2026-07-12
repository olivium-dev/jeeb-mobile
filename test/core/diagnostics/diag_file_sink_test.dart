import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_dio_interceptor.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_file_sink.dart';

/// The exact leak signature the docs' run-mission gate greps for: a raw
/// `Bearer ` header value or a JWT-shaped `eyJ…` token.
final RegExp kSecretPattern = RegExp(r'Bearer |eyJ[A-Za-z0-9_-]{10,}\.');

const String _fakeJwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEiLCJleHAiOjk5OTk5OTk5OTl9.S3cReTtOkEnLeAk';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.status = 200});
  final int status;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBase;
  late List<String> logcat;

  /// Builds a sink over the test temp dir and installs it as the Diag tee
  /// (exactly what installAsGlobal does in production).
  DiagFileSink makeSink({
    String role = 'client',
    Map<String, Object?> sessionMeta = const {'model': 'testbox'},
    int maxSessions = 5,
    int maxTotalBytes = 20 * 1024 * 1024,
    int maxSessionBytes = 10 * 1024 * 1024,
    int flushThresholdLines = 32,
    DateTime Function()? clock,
    Future<Directory> Function()? baseDirectoryProvider,
  }) {
    final sink = DiagFileSink(
      baseDirectoryProvider: baseDirectoryProvider ?? () async => tempBase,
      role: role,
      sessionMeta: sessionMeta,
      maxSessions: maxSessions,
      maxTotalBytes: maxTotalBytes,
      maxSessionBytes: maxSessionBytes,
      flushThresholdLines: flushThresholdLines,
      clock: clock,
    );
    Diag.persistentSink = sink;
    return sink;
  }

  Directory diagDir() => Directory('${tempBase.path}/diag');

  Future<List<Map<String, dynamic>>> readSession(DiagFileSink sink) async {
    final path = sink.sessionFilePath;
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
    tempBase = await Directory.systemTemp.createTemp('diag_sink_test');
    logcat = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = logcat.add;
  });

  tearDown(() async {
    Diag.resetForTest();
    DiagFileSink.resetGlobalForTest();
    if (await tempBase.exists()) {
      await tempBase.delete(recursive: true);
    }
  });

  group('session file + header shape', () {
    test('creates diag/<isoStamp>-<role>.jsonl under the base dir', () async {
      final sink = makeSink(
        role: 'client',
        clock: () => DateTime.utc(2026, 7, 3, 10, 30, 15, 123),
      );
      await sink.start();
      await sink.flush();

      expect(sink.directoryPath, '${tempBase.path}/diag');
      expect(
        sink.sessionFilePath,
        '${tempBase.path}/diag/2026-07-03T10-30-15-123Z-client.jsonl',
      );
      expect(File(sink.sessionFilePath!).existsSync(), isTrue);
    });

    test('line 1 is the session header: version, device meta, role, ts',
        () async {
      final sink = makeSink(
        sessionMeta: const {'model': 'Pixel 8', 'os': 'android'},
        clock: () => DateTime.utc(2026, 7, 3, 10, 30, 15),
      );
      await sink.start();
      await sink.flush();

      final records = await readSession(sink);
      final header = records.first;
      expect(header['t'], 'session');
      expect(header['v'], 1);
      expect(header['appVersion'], DiagFileSink.appVersion);
      expect(header['model'], 'Pixel 8');
      expect(header['os'], 'android');
      expect(header['role'], 'client');
      expect(header['file'], sink.sessionFilePath);
      expect(header['ts'], '2026-07-03T10:30:15.000Z');
      // No build sha define in the test env → the key is omitted, not empty.
      expect(header.containsKey('buildSha'), isFalse);
    });

    test('the file is PURE JSONL — no [jeeb-diag] logcat prefix inside',
        () async {
      final sink = makeSink();
      await sink.start();
      Diag.event('offer_submitted', {'requestId': 'r-1'});
      await sink.flush();

      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, isNot(contains(Diag.prefix)));
      // And every line decodes.
      final records = await readSession(sink);
      expect(records, isNotEmpty);
    });

    test('exportinfo is emitted at session start with the on-device path',
        () async {
      final sink = makeSink();
      await sink.start();
      await sink.flush();

      // In logcat (the "any log grab reveals the path" contract)…
      final exportLine = logcat.singleWhere((l) => l.contains('exportinfo'));
      expect(exportLine, contains(sink.sessionFilePath!));
      // …and in the file itself.
      final records = await readSession(sink);
      final evt = records.singleWhere((r) => r['name'] == 'exportinfo');
      expect((evt['data'] as Map)['file'], sink.sessionFilePath);
      expect((evt['data'] as Map)['dir'], sink.directoryPath);
    });
  });

  group('buffering + flush behaviour (never block, never lose the tail)', () {
    test('events emitted BEFORE start() land in the file AFTER the header',
        () async {
      final sink = makeSink();
      Diag.event('cold_start_evt', {'n': 1});
      Diag.event('cold_start_evt', {'n': 2});
      await sink.start();
      await sink.flush();

      final records = await readSession(sink);
      expect(records.first['t'], 'session');
      expect(records[1]['name'], 'cold_start_evt');
      expect((records[1]['data'] as Map)['n'], 1);
      expect((records[2]['data'] as Map)['n'], 2);
    });

    test('below the flush threshold, lines stay buffered until flush()',
        () async {
      final sink = makeSink(flushThresholdLines: 1000);
      await sink.start();
      await sink.flush(); // header on disk
      Diag.event('buffered_evt');
      await pumpEventQueue();

      var raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, isNot(contains('buffered_evt')));

      await sink.flush();
      raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, contains('buffered_evt'));
    });

    test('reaching the line threshold flushes WITHOUT an explicit flush()',
        () async {
      final sink = makeSink(flushThresholdLines: 3);
      await sink.start();
      await sink.flush(); // drain header + exportinfo → buffer empty
      Diag.event('e1');
      Diag.event('e2');
      Diag.event('e3'); // hits threshold → async write scheduled
      await pumpEventQueue();

      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, contains('e1'));
      expect(raw, contains('e2'));
      expect(raw, contains('e3'));
    });

    test('a FAILURE api record (5xx) force-flushes so a crash cannot lose it',
        () async {
      final sink = makeSink(flushThresholdLines: 1000);
      await sink.start();
      Diag.api(method: 'GET', path: '/v1/x', status: 500, ms: 10);
      await sink.pendingIo;

      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, contains('"status":500'));
    });

    test('an error-named evt force-flushes too', () async {
      final sink = makeSink(flushThresholdLines: 1000);
      await sink.start();
      Diag.event('offer_accept_error', {'code': 'timeout'});
      await sink.pendingIo;

      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, contains('offer_accept_error'));
    });
  });

  group('rotation (size-capped, oldest-first)', () {
    Future<File> plantSession(String stamp, {int bytes = 100}) async {
      final dir = diagDir();
      await dir.create(recursive: true);
      final file = File('${dir.path}/$stamp-client.jsonl');
      await file.writeAsString('x' * bytes);
      return file;
    }

    test('keeps at most maxSessions files including the new session',
        () async {
      // Past-dated fixtures so the CURRENT session always sorts newest.
      for (var i = 1; i <= 5; i++) {
        await plantSession('2020-01-0${i}T00-00-00-000Z');
      }
      final sink = makeSink(maxSessions: 3);
      await sink.start();
      await sink.flush();

      final names = diagDir()
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .toList()
        ..sort();
      expect(names, hasLength(3)); // 2 newest old sessions + current
      // The 3 oldest were pruned, oldest-first.
      expect(names[0], startsWith('2020-01-04'));
      expect(names[1], startsWith('2020-01-05'));
      expect(names[2], sink.sessionFilePath!.split('/').last);
    });

    test('prunes oldest-first until the total size cap is met', () async {
      await plantSession('2020-01-01T00-00-00-000Z', bytes: 6 * 1024);
      await plantSession('2020-01-02T00-00-00-000Z', bytes: 6 * 1024);
      await plantSession('2020-01-03T00-00-00-000Z', bytes: 6 * 1024);
      final sink = makeSink(maxTotalBytes: 10 * 1024, maxSessions: 10);
      await sink.start();
      await sink.flush();

      final names = diagDir()
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .toList()
        ..sort();
      // 18KB > 10KB → drop 01-01 (12KB left) → still >10KB → drop 01-02.
      expect(names.where((n) => n.startsWith('2020-01-01')), isEmpty);
      expect(names.where((n) => n.startsWith('2020-01-02')), isEmpty);
      expect(names.where((n) => n.startsWith('2020-01-03')), hasLength(1));
    });

    test('a session stops at maxSessionBytes with a single capped marker',
        () async {
      final sink = makeSink(maxSessionBytes: 600, flushThresholdLines: 1);
      await sink.start();
      for (var i = 0; i < 50; i++) {
        Diag.event('spam', {'i': i, 'pad': 'x' * 40});
      }
      await sink.flush();
      Diag.event('after_the_cap');
      await sink.flush();

      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(
        RegExp('diag_session_capped').allMatches(raw).length,
        1,
        reason: 'exactly one cap marker',
      );
      expect(raw, isNot(contains('after_the_cap')));
      // Well under 10x the cap — the cap actually bounded the file.
      expect(File(sink.sessionFilePath!).lengthSync(), lessThan(6000));
    });
  });

  group('fail-soft IO (must never crash the app)', () {
    test('a throwing directory provider breaks the sink silently', () async {
      final sink = makeSink(
        baseDirectoryProvider: () async => throw const FileSystemException(
          'disk full',
        ),
      );
      await sink.start(); // must not throw
      expect(sink.isBroken, isTrue);
      // Emitting afterwards is safe and logcat keeps flowing.
      Diag.event('still_alive');
      await sink.flush(); // must not throw
      expect(logcat.any((l) => l.contains('still_alive')), isTrue);
    });

    test('an append failure after start trips the breaker, no exception',
        () async {
      final sink = makeSink(flushThresholdLines: 1);
      await sink.start();
      await sink.flush();
      // Nuke the directory out from under the sink.
      await diagDir().delete(recursive: true);

      Diag.event('write_should_fail');
      await sink.flush(); // swallows the IO error
      expect(sink.isBroken, isTrue);

      // Subsequent emits are no-ops on the file path but never throw.
      Diag.event('after_breaker');
      await sink.flush();
      expect(logcat.any((l) => l.contains('after_breaker')), isTrue);
    });

    test('a broken persistent sink never breaks the logcat stream', () async {
      final sink = makeSink(
        baseDirectoryProvider: () async => throw Exception('boom'),
      );
      await sink.start();
      Diag.nav(evt: 'push', route: '/x', name: 'x');
      Diag.api(method: 'GET', path: '/v1/y', status: 200, ms: 1);
      Diag.event('evt_z');
      expect(logcat, hasLength(3));
    });
  });

  group('redaction end-to-end THROUGH the file path', () {
    test('a token in an evt payload reaches the file only as a handle',
        () async {
      final sink = makeSink();
      await sink.start();
      Diag.event('session_auth', {
        'status': 'authenticated',
        'accessToken': _fakeJwt,
      });
      await sink.flush();

      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, isNot(contains(_fakeJwt)));
      final records = await readSession(sink);
      final auth = records.singleWhere((r) => r['name'] == 'session_auth');
      expect((auth['data'] as Map)['accessToken'], startsWith('tok:'));
    });

    test(
        'CONSTRAINT GATE: a full simulated authenticated run leaves NO '
        'Bearer/eyJ pattern in the session file', () async {
      final sink = makeSink();
      await sink.start();

      // Authenticated API calls through the REAL interceptor pipeline.
      final dio = Dio(BaseOptions(baseUrl: 'https://gw'))
        ..httpClientAdapter = _StubAdapter(status: 200)
        ..interceptors.add(const DiagDioInterceptor());
      final auth = Options(headers: <String, dynamic>{
        'Authorization': 'Bearer $_fakeJwt',
        'x-correlation-id': 'corr-9',
      });
      Diag.currentScreen = '/login';
      await dio.post<dynamic>('/v1/auth/login', options: auth);
      Diag.currentScreen = '/home';
      await dio.get<dynamic>('/v1/users/me?access_token=$_fakeJwt',
          options: auth);

      // Domain events that (wrongly) carry secrets — the defensive scrub.
      Diag.event('push_received', {'fcmToken': _fakeJwt, 'id': 'm-1'});
      Diag.event('session_auth', {'refreshToken': _fakeJwt});
      await sink.flush();

      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(kSecretPattern.hasMatch(raw), isFalse,
          reason: 'no Bearer/JWT pattern may ever land on disk:\n$raw');
      // The run is still fully observable: paths, statuses, screens.
      expect(raw, contains('/v1/auth/login'));
      expect(raw, contains('/v1/users/me'));
      expect(raw, contains('"screen":"/home"'));
    });
  });

  group('installAsGlobal (production wiring)', () {
    test('installs the tee, starts the session, emits the sub PREFIX only',
        () async {
      await DiagFileSink.installAsGlobal(
        role: 'jeeber',
        baseDirectoryProvider: () async => tempBase,
        subLookup: () async => 'a1b2c3d4-e5f6-7890-abcd-ef0123456789',
      );
      final sink = DiagFileSink.active;
      expect(sink, isNotNull);
      expect(Diag.persistentSink, same(sink));
      await sink!.flush();

      final records = await readSession(sink);
      expect(records.first['t'], 'session');
      expect(records.first['role'], 'jeeber');
      final meta = records.singleWhere((r) => r['name'] == 'session_meta');
      expect((meta['data'] as Map)['subPrefix'], 'a1b2c3d4');
      // NEVER the full sub.
      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, isNot(contains('ef0123456789')));
    });

    test('is idempotent — a second install keeps the first sink', () async {
      await DiagFileSink.installAsGlobal(
        role: 'client',
        baseDirectoryProvider: () async => tempBase,
      );
      final first = DiagFileSink.active;
      await DiagFileSink.installAsGlobal(
        role: 'jeeber',
        baseDirectoryProvider: () async => tempBase,
      );
      expect(DiagFileSink.active, same(first));
    });

    test('a failing sub lookup is best-effort — session still records',
        () async {
      await DiagFileSink.installAsGlobal(
        role: 'client',
        baseDirectoryProvider: () async => tempBase,
        subLookup: () async => throw Exception('keystore locked'),
      );
      final sink = DiagFileSink.active!;
      Diag.event('still_recording');
      await sink.flush();
      final raw = await File(sink.sessionFilePath!).readAsString();
      expect(raw, contains('still_recording'));
    });
  });

  group('RELEASE GATE: a disabled build writes NOTHING', () {
    setUp(() {
      Diag.enabledOverride = false; // simulate release (kDebugMode false)
    });

    test('installAsGlobal is a hard no-op: no sink, no dir, no file',
        () async {
      await DiagFileSink.installAsGlobal(
        role: 'client',
        baseDirectoryProvider: () async => tempBase,
      );
      expect(DiagFileSink.active, isNull);
      expect(Diag.persistentSink, isNull);
      expect(diagDir().existsSync(), isFalse);
    });

    test('even a directly-started sink creates nothing when disabled',
        () async {
      final sink = makeSink();
      await sink.start(); // internal Diag.enabled guard
      Diag.event('never_stored');
      Diag.api(method: 'GET', path: '/v1/x', status: 200, ms: 1);
      Diag.nav(evt: 'push', route: '/x', name: 'x');
      await sink.flush();

      expect(sink.sessionFilePath, isNull);
      expect(diagDir().existsSync(), isFalse);
      expect(logcat, isEmpty, reason: 'the whole stream is off in release');
    });

    test('add() straight onto the sink is dropped when disabled', () async {
      final sink = makeSink();
      sink.add('{"t":"evt","name":"smuggled"}');
      await sink.flush();
      expect(diagDir().existsSync(), isFalse);
    });
  });
}

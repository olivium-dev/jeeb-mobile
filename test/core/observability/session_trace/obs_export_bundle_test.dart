import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/obs_export_bundle.dart';
import 'package:jeeb_mobile/core/observability/session_trace/obs_file_writer.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';

void main() {
  test('export snapshots use the cross-platform no-backup temp directory', () {
    final source = File(
      'lib/core/observability/session_trace/obs_export_bundle.dart',
    ).readAsStringSync();

    expect(source, contains('getTemporaryDirectory'));
    expect(source, isNot(contains('getApplicationDocumentsDirectory')));
  });

  late Directory temp;
  late File obsSource;
  late File diagSource;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('obs_export_bundle_test');
    obsSource = File('${temp.path}/active-obs.jsonl');
    diagSource = File('${temp.path}/active-diag.jsonl');
    await obsSource.writeAsString('{"type":"session"}\n{"type":"api"}\n');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('creates frozen Obs and strict event-only Diag snapshots for repeated '
      'recording intervals', () async {
    final rows = <Map<String, Object?>>[
      _event('before_start', '2026-08-29T09:59:59Z'),
      _event('otp_482913', '2026-08-29T10:00:20Z'),
      <String, Object?>{'t': 'session', 'ts': '2026-08-29T10:00:01Z'},
      <String, Object?>{
        't': 'api',
        'path': '/v1/private',
        'ts': '2026-08-29T10:00:01Z',
      },
      <String, Object?>{
        't': 'nav',
        'route': '/private',
        'ts': '2026-08-29T10:00:01Z',
      },
      <String, Object?>{
        't': 'gesture',
        'text': 'private text',
        'ts': '2026-08-29T10:00:01Z',
      },
      _event(
        'first_interval',
        '2026-08-29T10:00:30Z',
        data: <String, Object?>{
          'status': 'accepted',
          'count': 3,
          'firstName': 'Leila',
          'lastName': 'PrivateLast',
          'fullName': 'Leila PrivateLast',
          'customerName': 'Private Customer',
          'address': '221B Private Street',
          'misc': 'generic private address and prose',
        },
      ),
      _event('between_intervals', '2026-08-29T10:01:30Z'),
      _event(
        'second_interval',
        '2026-08-29T10:02:30Z',
        data: <String, Object?>{
          'outcome': 'completed',
          'code': 'delivery_ready',
          'note': 'private delivery note',
        },
      ),
      _event('after_stop', '2026-08-29T10:03:01Z'),
    ];
    await diagSource.writeAsString(
      '${rows.map(jsonEncode).join('\n')}\nnot-json\n',
    );

    final bundle = await ObsExportBundleBuilder.create(
      obsSourcePath: obsSource.path,
      diagSourcePath: diagSource.path,
      exportDirectoryProvider: () async => temp,
      clock: () => DateTime.utc(2026, 8, 29, 11),
      intervals: <ObsRecordingInterval>[
        ObsRecordingInterval(
          startUtc: DateTime.utc(2026, 8, 29, 10),
          endUtc: DateTime.utc(2026, 8, 29, 10, 1),
        ),
        ObsRecordingInterval(
          startUtc: DateTime.utc(2026, 8, 29, 10, 2),
          endUtc: DateTime.utc(2026, 8, 29, 10, 3),
        ),
      ],
    );

    expect(bundle, isNotNull);
    expect(bundle!.paths, hasLength(2));
    expect(bundle.obsPath, isNot(obsSource.path));
    expect(bundle.diagPath, isNot(diagSource.path));
    final diagLines = await File(bundle.diagPath!).readAsLines();
    expect(diagLines, hasLength(2));
    final exported = diagLines
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
    expect(exported.map((row) => row['name']), <String>[
      'first_interval',
      'second_interval',
    ]);
    final firstData = exported.first['data'] as Map<String, dynamic>;
    expect(firstData['status'], 'accepted');
    expect(firstData['count'], 3);
    for (final key in <String>[
      'firstName',
      'lastName',
      'fullName',
      'customerName',
      'address',
      'misc',
    ]) {
      expect(firstData[key], SecretRedactor.redacted, reason: key);
    }
    final raw = await File(bundle.diagPath!).readAsString();
    expect(
      (exported.last['data'] as Map<String, dynamic>)['code'],
      SecretRedactor.redacted,
    );
    for (final canary in <String>[
      'Leila',
      'PrivateLast',
      'Private Customer',
      '221B Private Street',
      'generic private address and prose',
      'private delivery note',
      '482913',
    ]) {
      expect(raw, isNot(contains(canary)), reason: canary);
    }

    final frozenObs = await File(bundle.obsPath).readAsString();
    await obsSource.writeAsString('{"type":"late"}\n', mode: FileMode.append);
    await diagSource.writeAsString(
      '${jsonEncode(_event('late_event', '2026-08-29T10:02:40Z'))}\n',
      mode: FileMode.append,
    );
    expect(await File(bundle.obsPath).readAsString(), frozenObs);
    expect(await File(bundle.diagPath!).readAsLines(), diagLines);
  });

  test(
    'missing Diag source degrades to a one-file frozen Obs bundle',
    () async {
      final bundle = await ObsExportBundleBuilder.create(
        obsSourcePath: obsSource.path,
        diagSourcePath: '${temp.path}/missing-diag.jsonl',
        exportDirectoryProvider: () async => temp,
        intervals: <ObsRecordingInterval>[
          ObsRecordingInterval(
            startUtc: DateTime.utc(2026, 8, 29),
            endUtc: DateTime.utc(2026, 8, 30),
          ),
        ],
      );

      expect(bundle, isNotNull);
      expect(bundle!.paths, hasLength(1));
      expect(bundle.diagPath, isNull);
    },
  );

  test(
    'dynamic interaction IDs are fixed-redacted on disk and in export',
    () async {
      const reviewId = 'review_rev-secret_report_cta';
      const requestId = 'jeeber_feed_request_offer_request-secret';
      final writer = ObsFileWriter(
        baseDirectoryProvider: () async => temp,
        sessionId: 'dynamic-id-test',
        role: 'test',
        flushThresholdLines: 1,
      );
      await writer.start();
      writer.add(
        ObsInteractionEvent(
          id: '1-interaction',
          sessionId: 'dynamic-id-test',
          timestampUtc: DateTime.utc(2026, 8, 30, 10),
          seq: 1,
          gesture: 'tap',
          targetId: reviewId,
        ),
      );
      writer.add(
        ObsInteractionEvent(
          id: '2-interaction',
          sessionId: 'dynamic-id-test',
          timestampUtc: DateTime.utc(2026, 8, 30, 10, 0, 1),
          seq: 2,
          gesture: 'tap',
          targetId: requestId,
        ),
      );
      await writer.flush();

      final sourcePath = writer.sessionFilePath;
      final bundle = await ObsExportBundleBuilder.create(
        obsSourcePath: sourcePath,
        intervals: const <ObsRecordingInterval>[],
        exportDirectoryProvider: () async => temp,
        clock: () => DateTime.utc(2026, 8, 30, 11),
      );

      expect(sourcePath, isNotNull);
      expect(bundle, isNotNull);
      for (final path in <String>[sourcePath!, bundle!.obsPath]) {
        final raw = await File(path).readAsString();
        expect(raw, isNot(contains(reviewId)), reason: path);
        expect(raw, isNot(contains(requestId)), reason: path);
        expect(raw, isNot(contains('"dx"')), reason: path);
        expect(raw, isNot(contains('"dy"')), reason: path);
        final rows = await File(path).readAsLines();
        final interactions = rows
            .map((line) => jsonDecode(line) as Map<String, dynamic>)
            .where((row) => row['type'] == 'interaction')
            .toList();
        expect(interactions, hasLength(2));
        for (final event in interactions) {
          final payload = event['payload']! as Map<String, dynamic>;
          expect(payload['targetId'], SecretRedactor.redacted);
        }
      }
    },
  );

  test('export cache retains only the ten newest JSONL snapshots', () async {
    await diagSource.writeAsString(
      '${jsonEncode(_event('bounded_cache', '2026-08-29T10:00:30Z'))}\n',
    );
    final paths = <String>[];
    for (var i = 0; i < 12; i++) {
      final path = await ObsExportBundleBuilder.createSanitizedDiagSnapshot(
        diagSourcePath: diagSource.path,
        exportDirectoryProvider: () async => temp,
        clock: () => DateTime.utc(2026, 8, 29, 11, 0, i),
      );
      paths.add(path!);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final exportDirectory = Directory('${temp.path}/jeeb_trace_exports');
    final retained = await exportDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
        .length;
    expect(retained, 10);
    expect(await File(paths.first).exists(), isFalse);
    expect(await File(paths.last).exists(), isTrue);
  });
}

Map<String, Object?> _event(
  String name,
  String timestamp, {
  Map<String, Object?> data = const <String, Object?>{},
}) => <String, Object?>{
  't': 'evt',
  'name': name,
  'data': data,
  'ts': timestamp,
};

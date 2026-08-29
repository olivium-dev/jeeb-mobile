import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diagnostics_screen.dart';
import 'package:jeeb_mobile/core/observability/session_trace/obs_export_bundle.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';

/// Widget tests for the dev-only Settings → Diagnostics export screen.
/// Every side-effecting seam (file listing, share sheet, clipboard) is
void main() {
  final sessions = <DiagSessionFileInfo>[
    DiagSessionFileInfo(
      path:
          '/data/user/0/app.jeeb.mobile.dev/files/diag/'
          '2026-07-03T10-30-15-123Z-client.jsonl',
      name: '2026-07-03T10-30-15-123Z-client.jsonl',
      sizeBytes: 12 * 1024 + 410,
      modified: DateTime(2026, 7, 3, 12, 30),
      isCurrent: true,
    ),
    DiagSessionFileInfo(
      path:
          '/data/user/0/app.jeeb.mobile.dev/files/diag/'
          '2026-07-02T08-00-00-000Z-jeeber.jsonl',
      name: '2026-07-02T08-00-00-000Z-jeeber.jsonl',
      sizeBytes: 532,
      modified: DateTime(2026, 7, 2, 9, 0),
    ),
  ];

  late List<DiagSessionFileInfo> shared;
  late List<String> copied;

  setUp(() {
    shared = <DiagSessionFileInfo>[];
    copied = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = (_) {};
  });

  tearDown(Diag.resetForTest);

  // MIDNIGHT M3-38: the empty/loading/disabled frames are `JeebEmptyState`,
  // whose illustrations loop forever by design — `pumpAndSettle` can only
  // settle under reduce motion (02-STUDY-NOTES, wave-B regression attribution).
  Widget host({List<DiagSessionFileInfo>? files}) => MaterialApp(
    theme: AppTheme.midnight(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: DiagnosticsScreen(
      sessionsLoader: () async => files ?? sessions,
      shareLauncher: (file) async => shared.add(file),
      clipboardWriter: (text) async => copied.add(text),
    ),
  );

  testWidgets('lists the persisted sessions newest-first with size + current '
      'marker', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diag-session-row-0')), findsOneWidget);
    expect(find.byKey(const Key('diag-session-row-1')), findsOneWidget);
    expect(
      find.text('2026-07-03T10-30-15-123Z-client.jsonl (current)'),
      findsOneWidget,
    );
    expect(find.text('2026-07-02T08-00-00-000Z-jeeber.jsonl'), findsOneWidget);
    expect(find.textContaining('12.4 KB'), findsOneWidget);
    expect(find.textContaining('532 B'), findsOneWidget);
  });

  testWidgets('tapping the share action hands the FILE to the share seam', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diag-share-1')));
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(
      shared.single.path,
      endsWith('2026-07-02T08-00-00-000Z-jeeber.jsonl'),
    );
  });

  testWidgets('tapping a session ROW also shares (primary action)', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diag-session-row-0')));
    await tester.pumpAndSettle();

    expect(shared.single.isCurrent, isTrue);
  });

  testWidgets('copy-path fallback puts the on-device path on the clipboard '
      'seam and confirms via snackbar', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diag-copy-0')));
    await tester.pumpAndSettle();

    expect(
      copied.single,
      '/data/user/0/app.jeeb.mobile.dev/files/diag/'
      '2026-07-03T10-30-15-123Z-client.jsonl',
    );
    expect(find.text('File path copied'), findsOneWidget);
  });

  testWidgets('the adb one-liner row copies the run-as command', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diag-row-adb')));
    await tester.pumpAndSettle();

    expect(
      copied.single,
      startsWith('adb exec-out run-as app.jeeb.mobile.dev'),
    );
    expect(copied.single, contains('2026-07-03T10-30-15-123Z-client.jsonl'));
  });

  testWidgets('an empty session list shows the empty state (no crash)', (
    tester,
  ) async {
    await tester.pumpWidget(host(files: const <DiagSessionFileInfo>[]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diag-row-empty')), findsOneWidget);
    expect(find.byKey(const Key('diag-session-row-0')), findsNothing);
  });

  testWidgets('RELEASE-LIKE build (Diag disabled): screen renders the '
      'dev-only notice and lists nothing', (tester) async {
    Diag.enabledOverride = false;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diag-disabled-message')), findsOneWidget);
    expect(find.byKey(const Key('diagnostics-session-list')), findsNothing);
  });

  testWidgets('refresh action re-queries the loader', (tester) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: DiagnosticsScreen(
          sessionsLoader: () async {
            loads++;
            return sessions;
          },
          shareLauncher: (_) async {},
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);

    // Re-homed from `Key('diag-refresh')`: the top bar's action is a data
    // class, so the id it can carry is the semantics one.
    await tester.tap(
      find.bySemanticsIdentifier(DiagnosticsScreen.refreshIdentifier),
    );
    await tester.pumpAndSettle();
    expect(loads, 2);
  });

  test(
    'default share creates and shares only a strict immutable snapshot',
    () async {
      final temp = await Directory.systemTemp.createTemp('diag_screen_share');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      const gpsCanary = 52.3676001;
      const textCanary = 'Private delivery address and chat message';
      final source = File('${temp.path}/raw-diag.jsonl');
      await source.writeAsString(
        '${jsonEncode(<String, Object?>{
          't': 'evt',
          'name': 'tracking_update',
          'data': <String, Object?>{'latitude': gpsCanary, 'longitude': 4.9041002, 'message': textCanary, 'unknown': textCanary, 'status': 'accepted'},
          'ts': '2026-08-29T10:00:00Z',
        })}\n'
        '${jsonEncode(<String, Object?>{'t': 'api', 'path': '/raw-private-api', 'ts': '2026-08-29T10:00:01Z'})}\n',
      );
      final file = DiagSessionFileInfo(
        path: source.path,
        name: 'raw-diag.jsonl',
        sizeBytes: await source.length(),
        modified: DateTime.utc(2026, 8, 29),
      );
      List<XFile>? shared;

      await DiagnosticsScreen.defaultShareLauncher(
        file,
        snapshotBuilder: (sourcePath) =>
            ObsExportBundleBuilder.createSanitizedDiagSnapshot(
              diagSourcePath: sourcePath,
              exportDirectoryProvider: () async => temp,
            ),
        share: (files, subject) async {
          shared = files;
          expect(subject, 'sanitized-diagnostics.jsonl');
          return const ShareResult('shared', ShareResultStatus.success);
        },
      );

      expect(shared, hasLength(1));
      expect(shared!.single.path, isNot(source.path));
      final exported = await File(shared!.single.path).readAsString();
      expect(exported, isNot(contains(gpsCanary.toString())));
      expect(exported, isNot(contains(textCanary)));
      expect(exported, isNot(contains('/raw-private-api')));
      expect(exported, contains(SecretRedactor.redacted));
      expect(exported, contains('accepted'));
    },
  );
}

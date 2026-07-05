// Isolated native UI test — DiagnosticsScreen (settings-diagnostics, dev-only
// JSONL export). Every side-effecting seam (session listing, share, clipboard)
// is constructor-injectable, and `Diag.enabledOverride = true` unlocks the
// enabled body (mirrors the widget test). Covers the populated sessions list,
// the empty state, and Arabic. Strings on this dev surface are literal English
// by design (never localized), so the AR shot just proves RTL layout.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diagnostics_screen.dart';

import '../support/screen_harness.dart';

final _sessions = <DiagSessionFileInfo>[
  DiagSessionFileInfo(
    path: '/data/user/0/app.jeeb.mobile.dev/files/diag/'
        '2026-07-03T10-30-15-123Z-client.jsonl',
    name: '2026-07-03T10-30-15-123Z-client.jsonl',
    sizeBytes: 12 * 1024 + 410,
    modified: DateTime(2026, 7, 3, 12, 30),
    isCurrent: true,
  ),
  DiagSessionFileInfo(
    path: '/data/user/0/app.jeeb.mobile.dev/files/diag/'
        '2026-07-02T08-00-00-000Z-jeeber.jsonl',
    name: '2026-07-02T08-00-00-000Z-jeeber.jsonl',
    sizeBytes: 532,
    modified: DateTime(2026, 7, 2, 9, 0),
  ),
];

DiagnosticsScreen _screen(List<DiagSessionFileInfo> sessions) =>
    DiagnosticsScreen(
      sessionsLoader: () async => sessions,
      shareLauncher: (_) async {},
      clipboardWriter: (_) async {},
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Diag.enabledOverride = true;
    Diag.sink = (_) {};
  });

  tearDown(Diag.resetForTest);

  testWidgets('settings-diagnostics: persisted sessions list (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_sessions),
      'settings-diagnostics__populated',
    );
  });

  testWidgets('settings-diagnostics: empty session list (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(const []),
      'settings-diagnostics__empty',
    );
  });

  testWidgets('settings-diagnostics: persisted sessions (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_sessions),
      'settings-diagnostics__ar',
      locale: const Locale('ar'),
    );
  });
}

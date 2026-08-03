// Shared dev-only fixtures for `DiagnosticsScreen`.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diagnostics_screen.dart';

/// Forces [Diag.enabled] for the subtree below it.
/// `DiagnosticsScreen.build` branches on the static `Diag.enabled`, which is
/// `kDebugMode` in a preview canvas and in `flutter test` — i.e. TRUE — so the
class DiagnosticsScreenEnabledScope extends StatelessWidget {
  /// Pins [Diag.enabled] to [enabled] while [child] builds.
  const DiagnosticsScreenEnabledScope({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// The value [Diag.enabled] reports to [child].
  final bool enabled;

  /// The subtree that reads the gate — in practice a [DiagnosticsScreen].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ignore: invalid_use_of_visible_for_testing_member
    // The gate is a `@visibleForTesting` seam and this is dev-only code that
    Diag.enabledOverride = enabled;
    return child;
  }
}

/// The designed states of [DiagnosticsScreen]: canned session listings plus the
/// four shapes its `sessionsLoader` seam can take (rows, none, stalled, thrown)
/// and inert stand-ins for the share and clipboard seams.
class DiagnosticsScreenPreviewFixtures {
  const DiagnosticsScreenPreviewFixtures._();

  // ───────────────────────────── canned data ──────────────────────────────

  /// Where `DiagFileSink` writes on an Android dev build. The screen derives
  /// the "On-device folder" row from the newest file's parent when no live sink
  static const String androidDiagDir =
      '/data/user/0/app.jeeb.mobile.dev/files/diag';

  /// Name of the session the LIVE sink is appending to — the row that carries
  /// the `(current)` marker.
  static const String currentSessionName =
      '2026-07-03T10-30-15-123Z-client.jsonl';

  /// A closed session from the Jeeber leg of the same run.
  static const String previousSessionName =
      '2026-07-02T08-00-00-000Z-jeeber.jsonl';

  /// The single file the compact 320 pt state lists. Distinct from the phone
  /// state's names on purpose: a preview quietly rewired to the wrong fixture
  static const String compactSessionName =
      '2026-06-30T07-14-52-000Z-jeeber.jsonl';

  /// Longest plausible session name: a role suffix plus the run label a tester
  /// types when they capture a full two-sided journey.
  static const String longestSessionName =
      '2026-07-31T23-59-59-999Z-jeeber-regression-run-full-journey.jsonl';

  /// Deepest plausible directory: an iOS Simulator data container. It is also
  /// NOT an Android app-data path, so `DiagExport.adbPullCommand` falls back to
  static const String simulatorDiagDir =
      '/Users/qa/Library/Developer/CoreSimulator/Devices/'
      '8C3F1A6D-2B44-4E19-9F0C-77A1D5E3B240/data/Containers/Data/Application/'
      '2A1B9C77-5D3E-4F62-8A10-6E4B0C9D1F58/Library/Application Support/diag';

  /// Fixed timestamps — a session list whose subtitles moved with the clock
  /// would make every render test date-dependent.
  static final DateTime _currentModified = DateTime(2026, 7, 3, 12, 30);
  static final DateTime _previousModified = DateTime(2026, 7, 2, 9);
  static final DateTime _compactModified = DateTime(2026, 6, 30, 7, 20);
  static final DateTime _longestModified = DateTime(2026, 7, 31, 23, 59, 59);

  // ──────────────────────────── session lists ─────────────────────────────

  /// The reference listing: the live session (12.4 KB, `(current)`) above a
  /// closed one from the other role (532 B), newest first.
  static List<DiagSessionFileInfo> twoSessions() => <DiagSessionFileInfo>[
        DiagSessionFileInfo(
          path: '$androidDiagDir/$currentSessionName',
          name: currentSessionName,
          sizeBytes: 12 * 1024 + 410,
          modified: _currentModified,
          isCurrent: true,
        ),
        DiagSessionFileInfo(
          path: '$androidDiagDir/$previousSessionName',
          name: previousSessionName,
          sizeBytes: 532,
          modified: _previousModified,
        ),
      ];

  /// One session, for the 320 pt floor — the width where the row's leading
  /// icon, its two-line label and the share/copy action pair contest the same
  static List<DiagSessionFileInfo> oneSession() => <DiagSessionFileInfo>[
        DiagSessionFileInfo(
          path: '$androidDiagDir/$compactSessionName',
          name: compactSessionName,
          sizeBytes: 3 * 1024 * 1024 + 512 * 1024,
          modified: _compactModified,
        ),
      ];

  /// The layout ceiling: the longest name this screen can be handed, inside the
  /// deepest directory, so BOTH export-row subtitles and the session title are
  static List<DiagSessionFileInfo> longestNames() => <DiagSessionFileInfo>[
        DiagSessionFileInfo(
          path: '$simulatorDiagDir/$longestSessionName',
          name: longestSessionName,
          sizeBytes: 9 * 1024 * 1024 + 800 * 1024,
          modified: _longestModified,
          isCurrent: true,
        ),
      ];

  // ─────────────────────────── the loader seams ───────────────────────────

  /// Lists [twoSessions] with no latency.
  static Future<List<DiagSessionFileInfo>> listing() async => twoSessions();

  /// Lists [oneSession].
  static Future<List<DiagSessionFileInfo>> compactListing() async =>
      oneSession();

  /// Lists [longestNames].
  static Future<List<DiagSessionFileInfo>> longestListing() async =>
      longestNames();

  /// A successful listing that found nothing — the directory exists (or does
  /// not) and holds no `*.jsonl` yet. The honest empty state.
  static Future<List<DiagSessionFileInfo>> empty() async =>
      const <DiagSessionFileInfo>[];

  /// A listing that never resolves, holding the screen on its spinner for as
  /// long as the surface is open.
  static Future<List<DiagSessionFileInfo>> stalled() =>
      Completer<List<DiagSessionFileInfo>>().future;

  /// A listing that THROWS — the state `DiagnosticsScreen.defaultSessionsLoader`
  /// swallows in production (its `catch (_)` returns an empty list) and that an
  static Future<List<DiagSessionFileInfo>> failing() async {
    throw StateError('fixture: EACCES listing $androidDiagDir');
  }

  // ───────────────────────── the side-effect seams ────────────────────────

  /// Share seam that does nothing — the production one calls
  /// `Share.shareXFiles`, a platform channel with no implementation behind a
  static Future<void> inertShare(DiagSessionFileInfo file) async {}

  /// Clipboard seam that does nothing, for the same reason.
  static Future<void> inertClipboard(String text) async {}
}

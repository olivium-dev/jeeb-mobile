import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'diag.dart';
import 'diag_export.dart';
import 'diag_file_sink.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../devtool/catalog/fixtures/diagnostics_screen_fixtures.dart';
import '../previews/jeeb_preview.dart';

/// One row of the sessions list — a persisted diag JSONL session file.
class DiagSessionFileInfo {
  const DiagSessionFileInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
    this.isCurrent = false,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  /// True for the session file the LIVE sink is currently appending to.
  final bool isCurrent;
}

/// Dev-only "Diagnostics" screen (Settings → Diagnostics, debug/dev builds
/// only — the Settings row and this body are gated on [Diag.enabled]).
///
/// A deliberately minimal DEV TOOL, not a product surface: lists the persisted
/// `[jeeb-diag]` JSONL session files (see `DiagFileSink`) and lets a tester
/// export one through the platform share sheet or copy its on-device path /
/// `adb` pull one-liner as the no-share-target fallback. Strings are literal
/// English by design — this surface never ships to release users, so it stays
/// out of the ARB catalogs.
///
/// All side-effecting seams (file listing, share sheet, clipboard) are
/// constructor-injectable so widget tests run without platform channels.
// ORPHAN (JEBV4-227, verified 2026-07-12): dead chain via orphaned /settings; dev-gated — see docs/project-understanding/reconciliation/orphans.md
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    Future<List<DiagSessionFileInfo>> Function()? sessionsLoader,
    Future<void> Function(DiagSessionFileInfo file)? shareLauncher,
    Future<void> Function(String text)? clipboardWriter,
  })  : _sessionsLoader = sessionsLoader,
        _shareLauncher = shareLauncher,
        _clipboardWriter = clipboardWriter;

  final Future<List<DiagSessionFileInfo>> Function()? _sessionsLoader;
  final Future<void> Function(DiagSessionFileInfo file)? _shareLauncher;
  final Future<void> Function(String text)? _clipboardWriter;

  /// Production loader: lists `*.jsonl` under the diag directory (the live
  /// sink's dir when installed, else the default app-support location),
  /// newest first. Total: IO failures degrade to an empty list.
  static Future<List<DiagSessionFileInfo>> defaultSessionsLoader() async {
    try {
      final active = DiagFileSink.active;
      final dirPath = active?.directoryPath ??
          '${(await getApplicationSupportDirectory()).path}'
              '/${DiagFileSink.dirName}';
      final dir = Directory(dirPath);
      if (!await dir.exists()) return const <DiagSessionFileInfo>[];
      final files = <DiagSessionFileInfo>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
        final stat = await entity.stat();
        files.add(DiagSessionFileInfo(
          path: entity.path,
          name: entity.path.split('/').last,
          sizeBytes: stat.size,
          modified: stat.modified,
          isCurrent: entity.path == active?.sessionFilePath,
        ));
      }
      // ISO-stamped names sort chronologically; show newest first.
      files.sort((a, b) => b.name.compareTo(a.name));
      return files;
    } catch (_) {
      return const <DiagSessionFileInfo>[];
    }
  }

  /// Production share: flush the live sink first so the exported file carries
  /// the whole session so far, then hand it to the platform share sheet.
  static Future<void> defaultShareLauncher(DiagSessionFileInfo file) async {
    await Diag.flushPersistent();
    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'text/plain')],
      subject: file.name,
    );
  }

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late Future<List<DiagSessionFileInfo>> _sessions = _load();

  Future<List<DiagSessionFileInfo>> _load() async {
    // Flush before listing so the current session's size/content is fresh.
    await Diag.flushPersistent();
    return (widget._sessionsLoader ??
        DiagnosticsScreen.defaultSessionsLoader)();
  }

  void _refresh() {
    // Kick the load OUTSIDE setState — the callback must stay synchronous
    // (and must not RETURN the future, which an arrow closure would).
    final next = _load();
    setState(() {
      _sessions = next;
    });
  }

  Future<void> _share(DiagSessionFileInfo file) async {
    try {
      await (widget._shareLauncher ??
          DiagnosticsScreen.defaultShareLauncher)(file);
    } catch (_) {
      _snack('Share failed — use "copy path" + adb instead.');
    }
  }

  Future<void> _copy(String text, String message) async {
    try {
      await (widget._clipboardWriter ?? _defaultClipboardWriter)(text);
      _snack(message);
    } catch (_) {
      _snack('Copy failed.');
    }
  }

  static Future<void> _defaultClipboardWriter(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OMDSAppBar(
        title: 'Diagnostics',
        showBackButton: true,
        actions: [
          IconButton(
            key: const Key('diag-refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: !Diag.enabled ? const _DisabledBody() : _enabledBody(),
    );
  }

  Widget _enabledBody() {
    return FutureBuilder<List<DiagSessionFileInfo>>(
      future: _sessions,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data ?? const <DiagSessionFileInfo>[];
        return Semantics(
          identifier: 'diagnostics_screen_root',
          container: true,
          child: ListView(
            key: const Key('diagnostics-session-list'),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
            children: [
              _ExportSection(sessions: sessions, onCopy: _copy),
              _SessionsSection(
                sessions: sessions,
                onShare: _share,
                onCopyPath: (file) => _copy(file.path, 'File path copied'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Body for release-like builds (belt and braces: the Settings row that routes
/// here is itself hidden when [Diag.enabled] is false).
class _DisabledBody extends StatelessWidget {
  const _DisabledBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Text(
          'Diagnostics is only available in dev builds.',
          key: const Key('diag-disabled-message'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ExportSection extends StatelessWidget {
  const _ExportSection({required this.sessions, required this.onCopy});

  final List<DiagSessionFileInfo> sessions;
  final Future<void> Function(String text, String message) onCopy;

  static String? _parentDir(String? path) {
    if (path == null) return null;
    final cut = path.lastIndexOf('/');
    return cut <= 0 ? null : path.substring(0, cut);
  }

  @override
  Widget build(BuildContext context) {
    final newest = sessions.isEmpty ? null : sessions.first;
    final dirPath =
        DiagFileSink.active?.directoryPath ?? _parentDir(newest?.path);
    return OmdsSettingsSection(
      title: 'Export',
      children: [
        OmdsSettingsRow(
          key: const Key('diag-row-dir-path'),
          title: 'On-device folder',
          subtitle: dirPath ?? 'No session directory yet',
          leadingIcon: Icons.folder_outlined,
          icon: Icons.copy_outlined,
          enabled: dirPath != null,
          onTap: dirPath == null
              ? null
              : () => onCopy(dirPath, 'Folder path copied'),
        ),
        OmdsSettingsRow(
          key: const Key('diag-row-adb'),
          title: 'adb pull one-liner',
          subtitle: newest == null
              ? 'Appears once a session file exists'
              : DiagExport.adbPullCommand(newest.path),
          leadingIcon: Icons.terminal_outlined,
          icon: Icons.copy_outlined,
          enabled: newest != null,
          onTap: newest == null
              ? null
              : () => onCopy(
                    DiagExport.adbPullCommand(newest.path),
                    'adb command copied',
                  ),
        ),
      ],
    );
  }
}

class _SessionsSection extends StatelessWidget {
  const _SessionsSection({
    required this.sessions,
    required this.onShare,
    required this.onCopyPath,
  });

  final List<DiagSessionFileInfo> sessions;
  final Future<void> Function(DiagSessionFileInfo file) onShare;
  final Future<void> Function(DiagSessionFileInfo file) onCopyPath;

  @override
  Widget build(BuildContext context) {
    return OmdsSettingsSection(
      title: 'Sessions (newest first)',
      children: [
        if (sessions.isEmpty)
          const OmdsSettingsRow(
            key: Key('diag-row-empty'),
            title: 'No session files yet',
            subtitle: 'Files appear here once the diag stream persists a '
                'session (debug/dev builds).',
            leadingIcon: Icons.hourglass_empty,
            icon: Icons.hourglass_empty,
          ),
        for (var i = 0; i < sessions.length; i++)
          _SessionRow(
            index: i,
            file: sessions[i],
            onShare: onShare,
            onCopyPath: onCopyPath,
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.index,
    required this.file,
    required this.onShare,
    required this.onCopyPath,
  });

  final int index;
  final DiagSessionFileInfo file;
  final Future<void> Function(DiagSessionFileInfo file) onShare;
  final Future<void> Function(DiagSessionFileInfo file) onCopyPath;

  @override
  Widget build(BuildContext context) {
    final modified = file.modified.toLocal().toString().split('.').first;
    return Semantics(
      identifier: 'diag_session_row_$index',
      button: true,
      child: OmdsSettingsRow(
        key: Key('diag-session-row-$index'),
        title: file.isCurrent ? '${file.name} (current)' : file.name,
        subtitle: '${DiagExport.formatBytes(file.sizeBytes)} · $modified',
        leadingIcon: Icons.description_outlined,
        onTap: () => onShare(file),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('diag-share-$index'),
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: 'Share',
              onPressed: () => onShare(file),
            ),
            IconButton(
              key: Key('diag-copy-$index'),
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy path',
              onPressed: () => onCopyPath(file),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/core/diagnostics_screen_preview_test.dart
// ===========================================================================
//
// [DiagnosticsScreen] is the dev-only export surface: an app bar with a refresh
// action, an "Export" section (on-device folder + `adb pull` one-liner) and the
// list of persisted `[jeeb-diag]` JSONL sessions. It takes no cubit and no
// repository — its whole state is what one injected `sessionsLoader` answers —
// so every preview below hands it a local loader and lets the real
// `FutureBuilder` path run exactly as production does.
//
// The loaders and their canned listings are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/diagnostics_screen_fixtures.dart` so that the
// day this screen gains a Screen Catalog entry, the designer's in-app browser
// and this canvas cannot drift into showing two different "designed states".
// Nothing in that file can reach the network, the clipboard channel or the
// platform share sheet: all three seams are constructor-injected and every
// preview passes an inert stand-in. The guard in [jeebPreviewHost] is the net
// here, not the plan.
//
// Four things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + OMDSAppBar` paints inside it. Harmless, and the
//    same nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.** The `size:` on
//    [JeebPreview] boxes the canvas; [_diagnosticsScreenHosted] pins the same
//    width in the widget tree, so the render tests measure the same phone
//    rather than the harness's 800 pt surface. Height is pinned too, but the
//    render surface is 800x600 — a `SizedBox` asking for 844 is enforced down
//    to what the host has, which is why nothing below the fold is asserted.
//  * **`Diag.enabled` is a STATIC gate, not a parameter.** It is `kDebugMode`
//    in the canvas and under `flutter test`, so the release-like body is
//    unreachable without driving `Diag.enabledOverride`.
//    [DiagnosticsScreenEnabledScope] does that for every state, in both
//    directions, so no card inherits the previous card's gate.
//  * **Tapping is mostly inert, deliberately.** Share and copy go to the
//    fixtures' no-ops; only "refresh" does real work, and it re-runs the same
//    loader — which means the stalled fixture stays stalled and the throwing
//    one keeps throwing.
//
// The states below are the ones that break:
//
//   * **Empty vs loader-failed.** These two are the reason this section
//     exists. `_enabledBody` reads `snapshot.data ?? const []` and never looks
//     at `snapshot.hasError`, so a listing that THREW paints the same "No
//     session files yet" row a genuinely empty directory paints. They are
//     previewed adjacently so that identity is visible rather than inferred;
//     the render test pins it. In production the defect is masked by
//     `defaultSessionsLoader` swallowing its own IO errors — which is the same
//     bug one layer down, and the reason a tester who cannot see their session
//     files has nothing to go on.
//   * **Loading.** The listing in flight — a bare centred spinner, with no app
//     bar hint and no way to tell it from a hung flush.
//   * **Longest content.** Neither `OmdsSettingsRow` label carries `maxLines`
//     or an overflow policy, and both subtitles here are unbroken machine
//     strings: a 58-character session name, a simulator container path, and the
//     `adb pull "<path>"` fallback built from them. This is the state the 200%
//     column of the matrix is for.
//   * **Compact 320 pt.** The narrowest supported phone, where the row's
//     leading icon, its two-line label and the share/copy action pair contest
//     one line.
//   * **Release-like build.** `Diag.enabled == false` — the notice, and no
//     list at all.

/// The phone this dev tool is read on.
const Size _diagnosticsScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _diagnosticsScreenCompactBox = Size(320, 568);

/// Pins the screen to a device-sized frame inside whatever box the host gives
/// it, with all three side-effecting seams inert and the build gate driven.
Widget _diagnosticsScreenHosted(
  Future<List<DiagSessionFileInfo>> Function() loader, {
  bool enabled = true,
  Size box = _diagnosticsScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: box.width,
      height: box.height,
      child: DiagnosticsScreenEnabledScope(
        enabled: enabled,
        child: DiagnosticsScreen(
          sessionsLoader: loader,
          shareLauncher: DiagnosticsScreenPreviewFixtures.inertShare,
          clipboardWriter: DiagnosticsScreenPreviewFixtures.inertClipboard,
        ),
      ),
    ),
  );
}

/// The reference reading: the live session above a closed one from the other
/// role, with the export rows resolved from the newest file's parent.
///
/// The matrix is on here because this is the state whose chrome is directional
/// — a leading icon, a two-line label and a trailing share/copy pair per row —
/// while every string on the surface is literal English by design (this screen
/// never ships to release users, so it stays out of the ARB catalogs). The AR
/// column is therefore about the MIRRORING, and the 200% column about whether
/// the action pair still leaves the label room.
@JeebPreview(
  group: 'core',
  name: 'Sessions · newest first',
  size: _diagnosticsScreenPhoneBox,
  matrix: true,
)
Widget diagnosticsScreenSessions() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.listing);

/// A listing that came back with nothing: no `*.jsonl` written yet, so both
/// export rows are disabled and the sessions section is one placeholder row.
///
/// This is what a fresh install shows, and — see the next preview — also what a
/// failed listing shows.
@JeebPreview(
  group: 'core',
  name: 'Empty · no session files',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenEmpty() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.empty);

/// The listing THREW — and the screen says so nowhere.
///
/// `_enabledBody` takes `snapshot.data ?? const []` and never inspects
/// `snapshot.hasError`, so this card is pixel-identical to the empty one above
/// it. Keep them adjacent: the identity is the finding, and it is only obvious
/// when the two are side by side.
@JeebPreview(
  group: 'core',
  name: 'Loader failed · degrades to empty',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenLoadFailed() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.failing);

/// The listing in flight: a bare centred `CircularProgressIndicator` under the
/// app bar, with nothing naming what is being awaited.
///
/// Worth looking at because the wait is not free — `_load` flushes the
/// persistent sink before it lists — so on a large session this spinner is what
/// a tester stares at, and it is indistinguishable from a hung flush.
@JeebPreview(
  group: 'core',
  name: 'Loading · listing files',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenLoading() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.stalled);

/// The layout ceiling: the longest session name inside the deepest directory.
///
/// Every string on this card is an unbroken machine token — a 58-character
/// file name, an iOS Simulator container path, and (because that path is not
/// Android app-data) the `adb pull "<path>"` fallback built from both. None of
/// the three has a `maxLines` or an overflow policy anywhere in
/// `OmdsSettingsRow`, so the 200% column of this matrix is where the row
/// budget is actually decided.
@JeebPreview(
  group: 'core',
  name: 'Longest content · long name, deep path',
  size: _diagnosticsScreenPhoneBox,
  matrix: true,
)
Widget diagnosticsScreenLongestContent() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.longestListing);

/// The 320 x 568 floor with one 3.5 MB session listed — the width where the
/// leading icon, the two-line label and the trailing share/copy pair have to
/// share a line.
@JeebPreview(
  group: 'core',
  name: 'Compact 320 pt · one session',
  size: _diagnosticsScreenCompactBox,
)
Widget diagnosticsScreenCompact() => _diagnosticsScreenHosted(
      DiagnosticsScreenPreviewFixtures.compactListing,
      box: _diagnosticsScreenCompactBox,
    );

/// Release-like build: `Diag.enabled` is false, so the body is the dev-only
/// notice and no listing happens at all.
///
/// Belt and braces in production — the Settings row that routes here is hidden
/// on the same gate — but the screen is reachable by deep link, so this is the
/// state a release user would land on.
@JeebPreview(
  group: 'core',
  name: 'Release-like build · diag disabled',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenDisabled() => _diagnosticsScreenHosted(
      DiagnosticsScreenPreviewFixtures.listing,
      enabled: false,
    );

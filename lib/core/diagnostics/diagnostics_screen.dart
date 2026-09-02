import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../layout/bottom_inset.dart';
import '../observability/session_trace/obs_export_bundle.dart';
import '../theme/jeeb_semantic_colors.dart';
import '../widgets/jeeb/jeeb_cta_button.dart';
import '../widgets/jeeb/jeeb_empty_state.dart';
import '../widgets/jeeb/jeeb_list_row.dart';
import '../widgets/jeeb/jeeb_midnight_field.dart';
import '../widgets/jeeb/jeeb_outlined_card.dart';
import '../widgets/jeeb/jeeb_section_label.dart';
import '../widgets/jeeb/jeeb_surface_tone.dart';
import '../widgets/jeeb/jeeb_top_bar.dart';
import 'diag.dart';
import 'diag_export.dart';
import 'diag_file_sink.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../devtool/catalog/fixtures/diagnostics_screen_fixtures.dart';
import '../previews/jeeb_preview.dart';

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

  final bool isCurrent;
}

/// The dev-only session-export screen (MIDNIGHT M3-38, ORPHAN ruling
/// KEEP+restyle).
///
/// Tile-less, derived from **R22 settings** — the screen it is pushed from and
/// the only board frame that draws this shape: `content` field with the single
/// orange glow top-end, an in-body [JeebTopBar], and labelled bands of
/// [JeebListRow]s inside grouped glass cards. R22 is board-still, so nothing
/// here animates beyond what the kit brings.
///
/// It is a developer surface, so it stays deliberately cheap: no orange
/// anywhere except the field's own glow and the kit's empty-state art. The
/// values on it are unbroken machine strings (an on-device path, an `adb pull`
/// one-liner, `*.jsonl` session names), which is why the rows carry them as
/// subtitles rather than trying to fit them into a chip.
///
/// Copy is literal English by design — a tool that never ships, deliberately
/// kept out of the ARB catalogs (same standing decision as the Settings row
/// that leads here).
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    Future<List<DiagSessionFileInfo>> Function()? sessionsLoader,
    Future<void> Function(DiagSessionFileInfo file)? shareLauncher,
    Future<void> Function(String text)? clipboardWriter,
  }) : _sessionsLoader = sessionsLoader,
       _shareLauncher = shareLauncher,
       _clipboardWriter = clipboardWriter;

  final Future<List<DiagSessionFileInfo>> Function()? _sessionsLoader;
  final Future<void> Function(DiagSessionFileInfo file)? _shareLauncher;
  final Future<void> Function(String text)? _clipboardWriter;

  static Future<List<DiagSessionFileInfo>> defaultSessionsLoader() async {
    try {
      final active = DiagFileSink.active;
      final dirPath =
          active?.directoryPath ??
          '${(await getApplicationSupportDirectory()).path}'
              '/${DiagFileSink.dirName}';
      final dir = Directory(dirPath);
      if (!await dir.exists()) return const <DiagSessionFileInfo>[];
      final files = <DiagSessionFileInfo>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
        final stat = await entity.stat();
        files.add(
          DiagSessionFileInfo(
            path: entity.path,
            name: entity.path.split('/').last,
            sizeBytes: stat.size,
            modified: stat.modified,
            isCurrent: entity.path == active?.sessionFilePath,
          ),
        );
      }
      files.sort((a, b) => b.name.compareTo(a.name));
      return files;
    } catch (_) {
      return const <DiagSessionFileInfo>[];
    }
  }

  /// Frozen identifiers. `diag_refresh` re-homes the old `Key('diag-refresh')`,
  /// which [JeebTopBarAction] cannot carry — it is a data class, not a widget.
  static const String backIdentifier = 'diagnostics_back';
  static const String refreshIdentifier = 'diag_refresh';
  static const String rootIdentifier = 'diagnostics_screen_root';
  static const String loadingIdentifier = 'diagnostics_loading';
  static const String errorIdentifier = 'diagnostics_error';
  static const String retryIdentifier = 'diagnostics_retry';
  static const String disabledIdentifier = 'diagnostics_disabled';
  static const String sessionsEmptyIdentifier = 'diagnostics_sessions_empty';

  static Future<void> defaultShareLauncher(
    DiagSessionFileInfo file, {
    Future<String?> Function(String sourcePath)? snapshotBuilder,
    Future<ShareResult> Function(List<XFile> files, String subject)? share,
  }) async {
    await Diag.flushPersistent();
    final snapshotPath =
        await (snapshotBuilder ??
            (sourcePath) => ObsExportBundleBuilder.createSanitizedDiagSnapshot(
              diagSourcePath: sourcePath,
            ))(file.path);
    if (snapshotPath == null) {
      throw const FileSystemException('No diagnostics snapshot was created.');
    }
    await (share ?? _shareSanitizedSnapshot)(<XFile>[
      XFile(snapshotPath, mimeType: 'application/x-ndjson'),
    ], 'sanitized-diagnostics.jsonl');
  }

  static Future<ShareResult> _shareSanitizedSnapshot(
    List<XFile> files,
    String subject,
  ) => Share.shareXFiles(files, subject: subject);

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late Future<List<DiagSessionFileInfo>> _sessions = _load();

  Future<List<DiagSessionFileInfo>> _load() async {
    await Diag.flushPersistent();
    return (widget._sessionsLoader ??
        DiagnosticsScreen.defaultSessionsLoader)();
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _sessions = next;
    });
  }

  Future<void> _share(DiagSessionFileInfo file) async {
    try {
      await (widget._shareLauncher ?? DiagnosticsScreen.defaultShareLauncher)(
        file,
      );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = Diag.enabled;
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      glowPlacement: JeebFieldGlowPlacement.topEnd,
      // R22 is board-still; a dev tool has even less claim to motion.
      animateDecor: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          // The list reserves the nav-bar inset itself (R22's rule).
          bottom: false,
          child: Column(
            children: [
              JeebTopBar.back(
                title: 'Diagnostics',
                identifier: DiagnosticsScreen.backIdentifier,
                // The action dies with the body it refreshes: in a release-like
                // build it used to survive the gate and run a directory listing
                // no body would ever render (SCREENS_WAVE03_FINDINGS).
                trailing: enabled
                    ? JeebTopBarAction(
                        icon: Icons.refresh,
                        onPressed: _refresh,
                        identifier: DiagnosticsScreen.refreshIdentifier,
                        semanticLabel: 'Refresh',
                      )
                    : null,
              ),
              Expanded(child: enabled ? _enabledBody() : const _DisabledBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enabledBody() {
    return FutureBuilder<List<DiagSessionFileInfo>>(
      future: _sessions,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingBody();
        }
        // The listing used to degrade to the empty state character for
        // character, so a thrown loader read as "no files written yet".
        if (snapshot.hasError) return _ErrorBody(onRetry: _refresh);
        final sessions = snapshot.data ?? const <DiagSessionFileInfo>[];
        return Semantics(
          identifier: DiagnosticsScreen.rootIdentifier,
          container: true,
          child: ListView(
            key: const Key('diagnostics-session-list'),
            padding: EdgeInsetsDirectional.only(
              start: Spacing.xLarge,
              end: Spacing.xLarge,
              bottom: context.scrollBodyBottomInset,
            ),
            children: [
              const SizedBox(height: Spacing.medium),
              _ExportSection(sessions: sessions, onCopy: _copy),
              const SizedBox(height: Spacing.large),
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

/// Centres a full-screen frame and lets it scroll instead of overflowing.
///
/// The illustration is a fixed 300; stacked with a headline, a body and a CTA
/// it overflows a 390x844 phone, and this screen also pins a 320x568 floor.
class _CentredFrame extends StatelessWidget {
  const _CentredFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The listing in flight. `radar` for the same reason M3-37 picked it two rows
/// up the same chain: a surface listening for a signal, with no second party to
/// name, so the identity discs are dropped.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const _CentredFrame(
      child: JeebEmptyState(
        variant: JeebEmptyStateVariant.radar,
        status: JeebEmptyStateStatus.loading,
        medallions: <JeebEmptyMedallion>[],
        identifier: DiagnosticsScreen.loadingIdentifier,
        headline: 'Reading session files…',
      ),
    );
  }
}

/// The listing threw. Same illustration, danger-tinted centre (kit ruling 1),
/// and the retry is the glass pill — never an orange act R22 does not draw.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CentredFrame(
      child: JeebEmptyState(
        key: const Key('diag-listing-error'),
        variant: JeebEmptyStateVariant.radar,
        status: JeebEmptyStateStatus.error,
        medallions: const <JeebEmptyMedallion>[],
        identifier: DiagnosticsScreen.errorIdentifier,
        headline: 'Could not read the session folder',
        body: 'Retry, or pull the folder off the device with adb.',
        action: JeebCtaButton.outline(
          label: 'Try again',
          expand: false,
          onTap: onRetry,
          identifier: DiagnosticsScreen.retryIdentifier,
        ),
      ),
    );
  }
}

/// The build gate is off. Nothing was read, so this is an empty rather than an
/// error — the state is correct in a release build, not a failure.
class _DisabledBody extends StatelessWidget {
  const _DisabledBody();

  @override
  Widget build(BuildContext context) {
    return const _CentredFrame(
      child: JeebEmptyState(
        key: Key('diag-disabled-message'),
        variant: JeebEmptyStateVariant.radar,
        medallions: <JeebEmptyMedallion>[],
        // The stream is off, so the kit's lit broadcast core would be a lie —
        // same reason E2's failure form overrides it (wave-B ruling).
        center: _GatedDisc(),
        identifier: DiagnosticsScreen.disabledIdentifier,
        headline: 'Diagnostics is off',
        body: 'Diagnostics is only available in dev builds.',
      ),
    );
  }
}

/// The gated centre: rest glass, periwinkle padlock. A build gate is a fact,
/// not a control — R22 draws its always-on line the same way.
class _GatedDisc extends StatelessWidget {
  const _GatedDisc();

  @override
  Widget build(BuildContext context) {
    final semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: semantics.glassFill,
        border: Border.all(color: semantics.glassBorder),
      ),
      child: Center(
        child: Icon(Icons.lock_outline, size: 26, color: semantics.mutedText),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JeebSectionLabel('Export'),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            JeebListRow(
              key: const Key('diag-row-dir-path'),
              icon: Icons.folder_outlined,
              title: 'On-device folder',
              subtitle: dirPath ?? 'No session directory yet',
              trailing: const _CopyGlyph(),
              isEnabled: dirPath != null,
              onTap: dirPath == null
                  ? null
                  : () => onCopy(dirPath, 'Folder path copied'),
            ),
            JeebListRow(
              key: const Key('diag-row-adb'),
              icon: Icons.terminal_outlined,
              title: 'adb pull one-liner',
              subtitle: newest == null
                  ? 'Appears once a session file exists'
                  : DiagExport.adbPullCommand(newest.path),
              trailing: const _CopyGlyph(),
              isEnabled: newest != null,
              onTap: newest == null
                  ? null
                  : () => onCopy(
                      DiagExport.adbPullCommand(newest.path),
                      'adb command copied',
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The trailing affordance on a row that copies instead of navigating — same
/// size and muted ink as the chevron it replaces.
class _CopyGlyph extends StatelessWidget {
  const _CopyGlyph();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.copy_outlined,
      size: 16,
      color: JeebSurfaceTone.of(context).mutedInk,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JeebSectionLabel('Sessions', hint: '· newest first'),
        const SizedBox(height: Spacing.xSmall),
        if (sessions.isEmpty)
          const JeebEmptyState.compact(
            key: Key('diag-row-empty'),
            variant: JeebEmptyStateVariant.radar,
            medallions: <JeebEmptyMedallion>[],
            identifier: DiagnosticsScreen.sessionsEmptyIdentifier,
            headline: 'No session files yet',
            body:
                'Files appear here once the diag stream persists a '
                'session (debug/dev builds).',
          )
        else
          JeebOutlinedCard.grouped(
            children: [
              for (var i = 0; i < sessions.length; i++)
                _SessionRow(
                  index: i,
                  file: sessions[i],
                  onShare: onShare,
                  onCopyPath: onCopyPath,
                ),
            ],
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
    final muted = JeebSurfaceTone.of(context).mutedInk;
    return Semantics(
      identifier: 'diag_session_row_$index',
      button: true,
      // The row owns two more actions of its own, so the outer node stays the
      // consumer's (kit contract) and the row adds none.
      child: JeebListRow(
        key: Key('diag-session-row-$index'),
        icon: Icons.description_outlined,
        title: file.isCurrent ? '${file.name} (current)' : file.name,
        subtitle: '${DiagExport.formatBytes(file.sizeBytes)} · $modified',
        onTap: () => onShare(file),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('diag-share-$index'),
              icon: const Icon(Icons.ios_share_outlined, size: 18),
              color: muted,
              visualDensity: VisualDensity.compact,
              tooltip: 'Share',
              onPressed: () => onShare(file),
            ),
            IconButton(
              key: Key('diag-copy-$index'),
              icon: const Icon(Icons.copy_outlined, size: 18),
              color: muted,
              visualDensity: VisualDensity.compact,
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
@JeebPreview(
  group: 'core',
  name: 'Empty · no session files',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenEmpty() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.empty);

/// The listing THREW: its own frame, danger-tinted, with a retry — no longer
/// the empty state character for character.
@JeebPreview(
  group: 'core',
  name: 'Loader failed · error frame',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenLoadFailed() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.failing);

/// The listing in flight: the breathing skeleton, headlined with what is being
/// awaited.
@JeebPreview(
  group: 'core',
  name: 'Loading · listing files',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenLoading() =>
    _diagnosticsScreenHosted(DiagnosticsScreenPreviewFixtures.stalled);

/// The layout ceiling: the longest session name inside the deepest directory.
/// Every string on this card is an unbroken machine token — a 58-character
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
@JeebPreview(
  group: 'core',
  name: 'Release-like build · diag disabled',
  size: _diagnosticsScreenPhoneBox,
)
Widget diagnosticsScreenDisabled() => _diagnosticsScreenHosted(
  DiagnosticsScreenPreviewFixtures.listing,
  enabled: false,
);

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'diag.dart';
import 'diag_export.dart';
import 'diag_file_sink.dart';

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
      files.sort((a, b) => b.name.compareTo(a.name));
      return files;
    } catch (_) {
      return const <DiagSessionFileInfo>[];
    }
  }

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

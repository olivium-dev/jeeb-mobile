import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'diag.dart';

/// On-device persistence for the `[jeeb-diag]` stream (diag-persistence lane).
///
/// Tees every diagnostic line into a per-session JSONL file so a device run can
/// be exported AFTER the fact — via `adb` (see `docs/diagnostics.md`) or the
/// dev-only Settings → Diagnostics screen — instead of requiring a live logcat
/// tail during the run.
///
/// ## File layout
///
/// ```
/// <application support dir>/diag/<sessionStart>-<role>.jsonl
///   e.g. Android: /data/user/0/app.jeeb.mobile.dev/files/diag/
///                   2026-07-03T10-30-15-123Z-client.jsonl
/// ```
///
/// One line per event, identical to the logcat payload minus the `[jeeb-diag] `
/// prefix — i.e. pure JSONL, directly `jq`-able. Line 1 is always the session
/// header (`{"t":"session",...}`: app version, build sha when available, device
/// model/OS, role at start, schema version). The user `sub` prefix (first 8
/// chars ONLY — never the full sub, never a token) follows as a `session_meta`
/// event once the keystore read resolves.
///
/// ## Rotation policy (size-capped, oldest-first)
///
/// * at most [maxSessions] session files are kept (current included) — older
///   ones are pruned oldest-first at session start;
/// * total on-disk size is pruned to [maxTotalBytes] (default 20 MB),
///   oldest-first, at session start;
/// * a single session stops recording at [maxSessionBytes] (default 10 MB):
///   one `diag_session_capped` marker is written and further lines are dropped
///   (the logcat stream keeps flowing — only persistence stops).
///
/// ## Safety contract
///
/// * NEVER blocks the UI thread: [add] only appends to an in-memory buffer;
///   file IO runs asynchronously on a serialized chain, flushed when the buffer
///   reaches [flushThresholdLines] lines, when a failure record passes
///   (`flushNow`), and on app lifecycle pause (`Diag.flushPersistent`).
/// * NEVER crashes the app: every IO path is try/caught; the first hard IO
///   failure marks the sink broken and persistence silently stops for the
///   session while the logcat stream continues untouched.
/// * NEVER active in release: gated on [Diag.enabled] at install time AND
///   inside [start]/[add] (belt and braces) — a release build creates no
///   directory and writes no bytes.
/// * NEVER stores secrets: lines arrive AFTER [Diag]'s redaction pipeline, so
///   the file inherits the exact logcat redaction guarantees
///   (`tok:<fnv8>~<last4>` handles, query-stripped paths, no bodies/headers).
class DiagFileSink implements DiagPersistentSink {
  DiagFileSink({
    required Future<Directory> Function() baseDirectoryProvider,
    DateTime Function()? clock,
    this.role = 'unknown',
    Map<String, Object?> sessionMeta = const <String, Object?>{},
    this.maxSessions = 5,
    this.maxTotalBytes = 20 * 1024 * 1024,
    this.maxSessionBytes = 10 * 1024 * 1024,
    this.flushThresholdLines = 32,
    this.maxPendingLines = 512,
  })  : _baseDirectoryProvider = baseDirectoryProvider,
        _clock = clock ?? DateTime.now,
        _sessionMeta = Map<String, Object?>.unmodifiable(sessionMeta);

  /// Subdirectory (under the app support dir) holding the session files.
  static const String dirName = 'diag';

  /// App version stamped into the session header. Build lanes may override via
  /// `--dart-define=JEEB_APP_VERSION=1.2.3+45`; defaults to the pubspec value.
  static const String appVersion = String.fromEnvironment(
    'JEEB_APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  /// Git sha stamped into the session header when the build provides it via
  /// `--dart-define=JEEB_BUILD_SHA=<sha>`. Empty → omitted from the header.
  static const String buildSha = String.fromEnvironment('JEEB_BUILD_SHA');

  /// The app-global instance installed by [installAsGlobal]; null in release
  /// builds, in tests (unless a test installs one), and before bootstrap.
  static DiagFileSink? active;

  final Future<Directory> Function() _baseDirectoryProvider;
  final DateTime Function() _clock;
  final Map<String, Object?> _sessionMeta;

  /// Role at session start (`client` / `jeeber` / `unknown`) — becomes part of
  /// the file name. Mid-session switches show up as `role_switch` events.
  final String role;

  /// Keep at most this many session files (current one included).
  final int maxSessions;

  /// Prune (oldest-first) until the diag dir totals at most this many bytes.
  final int maxTotalBytes;

  /// Stop persisting the CURRENT session beyond this many bytes.
  final int maxSessionBytes;

  /// Buffered lines that trigger an async flush.
  final int flushThresholdLines;

  /// Bound on lines buffered before [start] completes (cold-start burst) or
  /// between flushes. Overflow drops the NEWEST lines (the earliest events of
  /// a session are the ones that explain it) and records a drop marker.
  final int maxPendingLines;

  final List<String> _buffer = <String>[];
  Future<void> _ioChain = Future<void>.value();
  File? _file;
  bool _started = false;
  bool _broken = false;
  bool _capped = false;
  bool _cappedMarkerWritten = false;
  int _bytesWritten = 0;
  int _droppedLines = 0;

  /// Absolute path of this session's JSONL file (null until [start] resolves).
  String? get sessionFilePath => _file?.path;

  /// Absolute path of the diag directory (null until [start] resolves).
  String? get directoryPath => _file?.parent.path;

  /// True when a hard IO failure disabled persistence for this session.
  @visibleForTesting
  bool get isBroken => _broken;

  /// Test-only handle on the in-flight IO chain. `await sink.pendingIo`
  /// deterministically joins the real append a force-flush already scheduled,
  /// so coverage runs don't race a bare `pumpEventQueue()` (JEBV4-255).
  @visibleForTesting
  Future<void> get pendingIo => _ioChain;

  /// Builds the production sink, installs it as [Diag.persistentSink], starts
  /// the session file, and (best-effort) enriches the stream with the device
  /// model and the user-sub prefix. Debug/dev builds only — a release build
  /// ([Diag.enabled] false) returns immediately having touched NOTHING.
  ///
  /// Fire-and-forget from bootstrap: total (never throws), and the sink is
  /// installed BEFORE any await so cold-start events are buffered, not lost.
  static Future<void> installAsGlobal({
    required String role,
    Future<String?> Function()? subLookup,
    Future<Directory> Function()? baseDirectoryProvider,
  }) async {
    if (!Diag.enabled || active != null) return;
    try {
      final sink = DiagFileSink(
        baseDirectoryProvider:
            baseDirectoryProvider ?? getApplicationSupportDirectory,
        role: role,
        sessionMeta: <String, Object?>{
          'os': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'model': await _deviceModel(),
        },
      );
      active = sink;
      Diag.persistentSink = sink;
      await sink.start();
      await _emitSubPrefix(subLookup);
    } catch (_) {
      // Fail-soft by contract: persistence must never break bootstrap.
    }
  }

  /// Best-effort device model for the session header. Never throws — a missing
  /// platform channel (unit tests) degrades to 'unknown'.
  static Future<String> _deviceModel() async {
    try {
      final info = (await DeviceInfoPlugin().deviceInfo).data;
      final model = info['model'] ?? info['name'] ?? info['machine'];
      final str = model?.toString().trim();
      return (str == null || str.isEmpty) ? 'unknown' : str;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Emits the session-sub PREFIX (first 8 chars only) as a `session_meta`
  /// event once the keystore read resolves. NEVER the full sub, NEVER a token.
  static Future<void> _emitSubPrefix(
    Future<String?> Function()? subLookup,
  ) async {
    if (subLookup == null) return;
    try {
      final sub = await subLookup();
      if (sub == null || sub.isEmpty) return;
      Diag.event('session_meta', <String, Object?>{
        'subPrefix': sub.length <= 8 ? sub : sub.substring(0, 8),
      });
    } catch (_) {
      // Best-effort enrichment only.
    }
  }

  /// Test hook: resets the global installation. Production never calls this.
  @visibleForTesting
  static void resetGlobalForTest() {
    active = null;
  }

  /// Creates the diag directory, prunes old sessions (count + total-size caps,
  /// oldest-first), opens this session's file, writes the header line, drains
  /// anything buffered during cold start, and emits the `exportinfo` event
  /// (through [Diag], so the on-device path lands in logcat AND in the file).
  ///
  /// Total: any failure marks the sink broken and returns normally.
  Future<void> start() async {
    if (_started || _broken || !Diag.enabled) return;
    try {
      final base = await _baseDirectoryProvider();
      final dir = Directory('${base.path}/$dirName');
      await dir.create(recursive: true);
      await _prune(dir);
      final startedAt = _clock().toUtc();
      _file = File('${dir.path}/${_fileNameFor(startedAt, role)}');
      _started = true;
      _headerLine(startedAt); // enqueued ahead of any buffered lines
      _scheduleFlush();
      // Printed via Diag so ANY log grab (adb logcat) reveals where the
      // session files live on this device — the "exportinfo" contract.
      Diag.event('exportinfo', <String, Object?>{
        'file': _file!.path,
        'dir': dir.path,
      });
    } catch (_) {
      _broken = true;
      _buffer.clear();
    }
  }

  @override
  void add(String line, {bool flushNow = false}) {
    if (_broken || _capped || !Diag.enabled) return;
    if (_buffer.length >= maxPendingLines) {
      _droppedLines++;
      return;
    }
    _buffer.add(_stripPrefix(line));
    if (!_started) return; // start() drains the buffer once the file exists.
    if (flushNow || _buffer.length >= flushThresholdLines) {
      _scheduleFlush();
    }
  }

  /// Drains the buffer to disk and awaits the whole serialized IO chain, so a
  /// caller (lifecycle pause, tests) observes everything durably written.
  @override
  Future<void> flush() {
    _scheduleFlush();
    return _ioChain;
  }

  /// Final flush; the sink stays usable (files are append-only per session).
  Future<void> close() => flush();

  // ── internals ────────────────────────────────────────────────────────────

  /// `2026-07-03T10-30-15-123Z-client.jsonl` — ISO-8601-style UTC stamp with
  /// `:`/`.` replaced by `-` so the name is filesystem-safe on every platform,
  /// millisecond precision so rapid restarts never collide, and lexicographic
  /// order == chronological order (what rotation sorts on).
  static String _fileNameFor(DateTime startedAtUtc, String role) {
    final t = startedAtUtc;
    String p2(int n) => n.toString().padLeft(2, '0');
    String p3(int n) => n.toString().padLeft(3, '0');
    final stamp = '${t.year}-${p2(t.month)}-${p2(t.day)}'
        'T${p2(t.hour)}-${p2(t.minute)}-${p2(t.second)}-${p3(t.millisecond)}Z';
    final safeRole = role.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$stamp-$safeRole.jsonl';
  }

  /// Line 1 of every session file. Same JSON-per-line format; `t: "session"`.
  void _headerLine(DateTime startedAtUtc) {
    final header = <String, Object?>{
      't': 'session',
      'v': 1,
      'appVersion': appVersion,
      if (buildSha.isNotEmpty) 'buildSha': buildSha,
      ..._sessionMeta,
      'role': role,
      'file': _file?.path,
      'ts': startedAtUtc.toIso8601String(),
    };
    _buffer.insert(0, jsonEncode(header));
  }

  /// Drops the `[jeeb-diag] ` logcat prefix so the file is pure JSONL.
  static String _stripPrefix(String line) {
    const marker = '${Diag.prefix} ';
    return line.startsWith(marker) ? line.substring(marker.length) : line;
  }

  /// Oldest-first pruning: keep at most [maxSessions]-1 previous files (the
  /// current session is about to be created) and at most [maxTotalBytes].
  Future<void> _prune(Directory dir) async {
    final entries = <MapEntry<File, int>>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
      int size;
      try {
        size = await entity.length();
      } catch (_) {
        size = 0;
      }
      entries.add(MapEntry(entity, size));
    }
    // Lexicographic == chronological for our ISO-stamped names.
    entries.sort((a, b) => a.key.path.compareTo(b.key.path));
    var total = entries.fold<int>(0, (sum, e) => sum + e.value);
    var index = 0;
    bool overCount() => entries.length - index > maxSessions - 1;
    bool overSize() => total > maxTotalBytes;
    while (index < entries.length && (overCount() || overSize())) {
      final entry = entries[index];
      try {
        await entry.key.delete();
      } catch (_) {
        // A file we cannot delete is skipped; pruning stays best-effort.
      }
      total -= entry.value;
      index++;
    }
  }

  void _scheduleFlush() {
    if (_broken || !_started || _buffer.isEmpty) return;
    final file = _file;
    if (file == null) return;
    final lines = List<String>.of(_buffer);
    _buffer.clear();
    if (_droppedLines > 0) {
      lines.add(jsonEncode(<String, Object?>{
        't': 'evt',
        'name': 'diag_lines_dropped',
        'data': <String, Object?>{'count': _droppedLines},
        'ts': _clock().toUtc().toIso8601String(),
      }));
      _droppedLines = 0;
    }
    final payload = '${lines.join('\n')}\n';
    // Serialized append chain: writes never interleave, and IO errors flip the
    // fail-soft breaker instead of surfacing into the emitter's hot path.
    _ioChain = _ioChain.then((_) async {
      if (_broken) return;
      try {
        if (_capped) {
          await _writeCappedMarkerOnce(file);
          return;
        }
        await file.writeAsString(payload, mode: FileMode.append, flush: true);
        _bytesWritten += utf8.encode(payload).length;
        if (_bytesWritten >= maxSessionBytes) {
          // Session cap reached: write the marker immediately so the file's
          // tail explains itself, then drop everything after it.
          _capped = true;
          await _writeCappedMarkerOnce(file);
        }
      } catch (_) {
        _broken = true;
        _buffer.clear();
      }
    });
  }

  Future<void> _writeCappedMarkerOnce(File file) async {
    if (_cappedMarkerWritten) return;
    _cappedMarkerWritten = true;
    await file.writeAsString(
      '${jsonEncode(<String, Object?>{
        't': 'evt',
        'name': 'diag_session_capped',
        'data': <String, Object?>{'maxSessionBytes': maxSessionBytes},
        'ts': _clock().toUtc().toIso8601String(),
      })}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

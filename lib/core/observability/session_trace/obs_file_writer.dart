import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'model/obs_event.dart';
import 'observability.dart';
import 'observability_config.dart';
import 'secret_redactor.dart';

/// On-device JSONL persistence for the session-trace tool — the CORE writer
/// every capturer's events eventually land in via [Observability.record].
///
/// Mirrors `DiagFileSink` almost line-for-line (the proven pattern this
/// contract mandates paralleling), differing only in: the directory
/// (`obs_trace/` under the app DOCUMENTS dir, not `diag/` under app support),
/// the input type ([ObsEvent] instead of a pre-formatted logcat line), and a
/// defensive second redaction pass on every payload before it touches disk.
///
/// ## File layout
///
/// ```
/// <app documents dir>/obs_trace/<sessionId>.jsonl
///   e.g. Android: /data/user/0/app.jeeb.mobile.dev/app_flutter/obs_trace/
///                   2026-07-18T10-30-15-123Z-client.jsonl
/// ```
///
/// [sessionId] already embeds the role (minted by
/// `Observability._mintSessionId` as `<isoStamp>-<role>`), so the filename
/// is simply `<sessionId>.jsonl` — no separate role suffix is appended.
/// Line 1 is always the session header (`{"type":"session",...}`: app
/// version, build sha when available, device model/OS, role, sessionId,
/// schema version). One line per event after that, pure JSONL (no logcat
/// prefix, no logcat mirroring — unlike `Diag`, this tool has no live-tail
/// stream, only the exported file).
///
/// ## Rotation policy (size-capped, oldest-first) — identical to DiagFileSink
///
/// * at most [maxSessions] session files are kept (current included);
/// * total on-disk size is pruned to [maxTotalBytes], oldest-first;
/// * a single session stops recording at [maxSessionBytes]: one
///   `obs_session_capped` marker is written and further lines are dropped.
///
/// ## Safety contract
///
/// * NEVER blocks the UI thread: [add] only appends to an in-memory buffer;
///   file IO runs asynchronously on a serialized chain, flushed at the
///   [flushThresholdLines] threshold, on `flushNow`, and on app pause
///   (`Observability.flush`).
/// * NEVER crashes the app: every IO path is try/caught; the first hard IO
///   failure marks the sink broken and persistence silently stops.
/// * NEVER active in release: [installAsGlobal] — the only production entry
///   point that ever constructs a writer — is gated on [kObsCompiledIn], as
///   is every caller of [Observability.record] upstream of [add]. [start]
///   and [add] themselves stay unconditional (no internal compile-flag
///   check) so this class remains directly unit-testable in a plain
///   `flutter test` run without a `--dart-define`; the compile-time
///   guarantee is enforced above this class (`Observability` + the Phase-2
///   wiring sites), not duplicated inside it.
/// * NEVER stores a raw secret: capturers redact at capture time (see
///   `SecretRedactor`), and [add] applies a DEFENSIVE SECOND SCRUB over the
///   payload (`SecretRedactor.redactBody(full: true)`) before `jsonEncode`,
///   so a capturer mistake still cannot leak a secret to disk.
final class ObsFileWriter implements ObservabilitySink {
  ObsFileWriter({
    required Future<Directory> Function() baseDirectoryProvider,
    required this.sessionId,
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

  /// Subdirectory under the app DOCUMENTS dir holding the session files.
  static const String dirName = 'obs_trace';

  /// App version stamped into the session header. Build lanes may override
  /// via `--dart-define=JEEB_APP_VERSION=1.2.3+45`.
  static const String appVersion = String.fromEnvironment(
    'JEEB_APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  /// Git sha stamped into the session header when provided via
  /// `--dart-define=JEEB_BUILD_SHA=<sha>`. Empty → omitted from the header.
  static const String buildSha = String.fromEnvironment('JEEB_BUILD_SHA');

  /// The app-global instance installed by [installAsGlobal]; null in
  /// release, in tests (unless a test installs one), and before bootstrap.
  static ObsFileWriter? active;

  final Future<Directory> Function() _baseDirectoryProvider;
  final DateTime Function() _clock;
  final Map<String, Object?> _sessionMeta;

  /// Session id this file belongs to — already role-suffixed (see the class
  /// doc); becomes the file name verbatim (`<sessionId>.jsonl`).
  final String sessionId;

  /// Role at session start (`client` / `jeeber` / `unknown`) — stamped into
  /// the session header.
  final String role;

  /// Keep at most this many session files (current one included).
  final int maxSessions;

  /// Prune (oldest-first) until the obs_trace dir totals at most this many
  /// bytes.
  final int maxTotalBytes;

  /// Stop persisting the CURRENT session beyond this many bytes.
  final int maxSessionBytes;

  /// Buffered lines that trigger an async flush.
  final int flushThresholdLines;

  /// Bound on lines buffered before [start] completes or between flushes.
  /// Overflow drops the NEWEST lines and records a drop marker.
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

  /// Absolute path of this session's JSONL file (null until [start]
  /// resolves).
  @override
  String? get sessionFilePath => _file?.path;

  /// Absolute path of the obs_trace directory (null until [start] resolves).
  String? get directoryPath => _file?.parent.path;

  /// True when a hard IO failure disabled persistence for this session.
  @visibleForTesting
  bool get isBroken => _broken;

  /// Test-only handle on the in-flight IO chain so coverage runs can
  /// deterministically join a force-flush instead of racing a bare
  /// `pumpEventQueue()`.
  @visibleForTesting
  Future<void> get pendingIo => _ioChain;

  /// Builds the writer, starts the session file, and (best-effort) enriches
  /// it with the device model + the user-sub prefix. Debug/devtool only — a
  /// build with [kObsCompiledIn] false returns `null` having touched
  /// NOTHING. Idempotent: a second call returns the already-[active] writer
  /// instead of starting a competing session file. Total: never throws.
  static Future<ObsFileWriter?> installAsGlobal({
    required String sessionId,
    required String role,
    Future<String?> Function()? subLookup,
    Future<Directory> Function()? baseDirectoryProvider,
  }) async {
    if (!kObsCompiledIn) return null;
    if (active != null) return active;
    try {
      final writer = ObsFileWriter(
        baseDirectoryProvider:
            baseDirectoryProvider ?? getApplicationDocumentsDirectory,
        sessionId: sessionId,
        role: role,
        sessionMeta: <String, Object?>{
          'os': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'model': await _deviceModel(),
        },
      );
      active = writer;
      await writer.start();
      await _emitSubPrefix(writer, subLookup);
      return writer;
    } catch (_) {
      // Fail-soft by contract — persistence must never break bootstrap.
      return null;
    }
  }

  /// Best-effort device model for the session header. Never throws — a
  /// missing platform channel (unit tests) degrades to 'unknown'.
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
  /// line once the keystore read resolves. NEVER the full sub, NEVER a
  /// token.
  static Future<void> _emitSubPrefix(
    ObsFileWriter writer,
    Future<String?> Function()? subLookup,
  ) async {
    if (subLookup == null) return;
    try {
      final sub = await subLookup();
      if (sub == null || sub.isEmpty) return;
      writer._addMetaLine('session_meta', <String, Object?>{
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

  /// Creates the obs_trace directory, prunes old sessions (count + total-size
  /// caps, oldest-first), opens this session's file, writes the header line,
  /// and drains anything buffered during cold start.
  ///
  /// Total: any failure marks the sink broken and returns normally.
  Future<void> start() async {
    if (_started || _broken) return;
    try {
      final base = await _baseDirectoryProvider();
      final dir = Directory('${base.path}/$dirName');
      await dir.create(recursive: true);
      await _prune(dir);
      _file = File('${dir.path}/$sessionId.jsonl');
      _started = true;
      _headerLine();
      _scheduleFlush();
    } catch (_) {
      _broken = true;
      _buffer.clear();
    }
  }

  @override
  void add(ObsEvent event, {bool flushNow = false}) {
    if (_broken || _capped) return;
    if (_buffer.length >= maxPendingLines) {
      _droppedLines++;
      return;
    }
    _buffer.add(_encodeEvent(event));
    if (!_started) return; // start() drains the buffer once the file exists.
    if (flushNow || _buffer.length >= flushThresholdLines) {
      _scheduleFlush();
    }
  }

  /// Drains the buffer to disk and awaits the whole serialized IO chain, so
  /// a caller (lifecycle pause, tests) observes everything durably written.
  @override
  Future<void> flush() {
    _scheduleFlush();
    return _ioChain;
  }

  /// Final flush; the sink stays usable (files are append-only per session).
  @override
  Future<void> close() => flush();

  // ── internals ────────────────────────────────────────────────────────────

  /// Encodes one event line: the common envelope verbatim, but with
  /// `payload` re-scrubbed via [SecretRedactor.redactBody] as a DEFENSIVE
  /// SECOND PASS — belt-and-braces against a capturer mistake. Total: an
  /// encode failure degrades to a marker line rather than throwing.
  String _encodeEvent(ObsEvent event) {
    try {
      final json = event.toJson();
      json['payload'] = SecretRedactor.redactBody(
        json['payload'],
        full: true,
      );
      return jsonEncode(json);
    } catch (_) {
      return jsonEncode(<String, Object?>{
        'v': ObsEvent.schemaVersion,
        'type': event.type.name,
        'err': 'encode_failed',
      });
    }
  }

  void _addMetaLine(String name, Map<String, Object?> data) {
    if (_broken) return;
    _buffer.add(jsonEncode(<String, Object?>{
      'type': 'meta',
      'name': name,
      'data': SecretRedactor.redactBody(data, full: true),
      'ts': _clock().toUtc().toIso8601String(),
    }));
    if (_started) _scheduleFlush();
  }

  /// Line 1 of every session file.
  void _headerLine() {
    final header = <String, Object?>{
      'type': 'session',
      'v': ObsEvent.schemaVersion,
      'appVersion': appVersion,
      if (buildSha.isNotEmpty) 'buildSha': buildSha,
      ..._sessionMeta,
      'role': role,
      'sessionId': sessionId,
      'file': _file?.path,
      'ts': _clock().toUtc().toIso8601String(),
    };
    _buffer.insert(0, jsonEncode(header));
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
        'type': 'meta',
        'name': 'obs_lines_dropped',
        'data': <String, Object?>{'count': _droppedLines},
        'ts': _clock().toUtc().toIso8601String(),
      }));
      _droppedLines = 0;
    }
    final payload = '${lines.join('\n')}\n';
    // Serialized append chain: writes never interleave, and IO errors flip
    // the fail-soft breaker instead of surfacing into the emitter's hot path.
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
        'type': 'meta',
        'name': 'obs_session_capped',
        'data': <String, Object?>{'maxSessionBytes': maxSessionBytes},
        'ts': _clock().toUtc().toIso8601String(),
      })}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

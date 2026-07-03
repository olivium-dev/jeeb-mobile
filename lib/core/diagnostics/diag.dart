import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'diag_redaction.dart';

/// Contract for the OPTIONAL on-device persistence tee ([Diag.persistentSink]).
///
/// Every line the diagnostic stream emits to logcat is ALSO handed here (when a
/// sink is installed) so a device run can be exported after the fact — see
/// `DiagFileSink` for the JSONL session-file implementation and
/// `docs/diagnostics.md` §Persistence for the file layout / rotation policy.
///
/// Implementations MUST be fail-soft and non-blocking: [add] is called on the
/// UI thread inside hot paths (nav transitions, every API round-trip) and must
/// only buffer in memory; real IO happens later, asynchronously.
abstract interface class DiagPersistentSink {
  /// Buffers [line] for persistence. [flushNow] hints that the line records a
  /// failure (non-2xx API, error event) and the buffer should hit disk soon so
  /// a subsequent crash cannot lose it. Must never throw and never block.
  void add(String line, {bool flushNow = false});

  /// Forces the buffer to disk (e.g. on app pause). Must never throw.
  Future<void> flush();
}

/// Jeeb diagnostic event stream.
///
/// Purpose (owner mandate): emit ONE structured JSON line per interesting event
/// — a screen opening, an API call, a domain event — under a single stable
/// logcat prefix so agents / Codex can `adb logcat | grep '\[jeeb-diag\]'` and
/// assert on exactly what happened during a device run.
///
/// Wire format is one line per event:
///
///   [jeeb-diag] {"t":"nav","evt":"push","route":"/orders/:id",...}
///   [jeeb-diag] {"t":"api","m":"GET","path":"/v1/requests","status":201,...}
///   [jeeb-diag] {"t":"evt","name":"offer_submitted","data":{...},"ts":"..."}
///
/// The `t` discriminator is `nav` | `api` | `evt` (plus the `session` header
/// record written by the file sink). Every record carries an ISO-8601 `ts`.
/// Redaction is by DESIGN — see [DiagRedaction]; no token, body, Authorization
/// header, or query string ever reaches a line.
///
/// Persistence (diag-persistence lane): when [persistentSink] is installed
/// (debug/dev builds only — see `DiagFileSink.installAsGlobal`), every emitted
/// line is ALSO buffered to an on-device JSONL session file so a run can be
/// exported via `adb` or the dev-only Settings → Diagnostics screen.
///
/// ACTIVE ONLY in debug/dev builds: [enabled] is `kDebugMode` OR the
/// `JEEB_DIAG` dart-define. In a release build with no define, every public
/// method is an early-return no-op and the `jsonEncode` cost is never paid.
abstract final class Diag {
  /// The stable, greppable logcat prefix. Do NOT change — run missions and
  /// tooling match on this literal.
  static const String prefix = '[jeeb-diag]';

  /// Dev-flavor gate. A build can force the stream on in profile for a device
  /// run with `--dart-define=JEEB_DIAG=true` without shipping it to release.
  static const bool _diagDefine = bool.fromEnvironment('JEEB_DIAG');

  /// Test-only override for [enabled]. Null means "use the build gate".
  @visibleForTesting
  static bool? enabledOverride;

  /// True when the diagnostic stream is active for this build.
  static bool get enabled => enabledOverride ?? (kDebugMode || _diagDefine);

  /// The line sink. Defaults to [_defaultSink] (dart:developer + debugPrint).
  /// Tests swap this to capture emitted lines.
  @visibleForTesting
  static void Function(String line) sink = _defaultSink;

  /// Optional persistence tee. Installed at bootstrap in debug/dev builds by
  /// `DiagFileSink.installAsGlobal`; null in release (and by default), so the
  /// stream stays logcat-only. Every emitted line is handed here fail-soft — a
  /// sink failure can never break the logcat stream or the caller.
  static DiagPersistentSink? persistentSink;

  /// Clock for the `ts` field, overridable in tests for deterministic output.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// The route path of the screen currently on top of the navigator, kept
  /// current by `DiagNavObserver`. Stamped onto `api` records (`screen`) so an
  /// exported session answers "which screen fired this call" without having to
  /// re-derive it from interleaved nav lines. Null before the first transition.
  static String? currentScreen;

  static int _apiSeq = 0;

  /// Next monotonic API sequence number (1, 2, 3…). Assigned by
  /// `DiagDioInterceptor` at REQUEST time so concurrent calls keep distinct,
  /// ordered ids even when their responses complete out of order.
  static int nextApiSeq() => ++_apiSeq;

  /// Flushes the persistent sink (no-op when none installed). Called on app
  /// lifecycle pause so a backgrounded/killed session's tail reaches disk.
  /// Fail-soft: a broken sink can never surface into the lifecycle handler.
  static Future<void> flushPersistent() async {
    final persistent = persistentSink;
    if (persistent == null) return;
    try {
      await persistent.flush();
    } catch (_) {
      // Fail-soft by contract — persistence must never break the app.
    }
  }

  /// Restores production defaults. Call from a test `tearDown`.
  @visibleForTesting
  static void resetForTest() {
    enabledOverride = null;
    sink = _defaultSink;
    clock = DateTime.now;
    persistentSink = null;
    currentScreen = null;
    _apiSeq = 0;
  }

  /// Emits a NAVIGATION record. Query tokens are never included — only the
  /// route path pattern, its name, its path params, and (when known) the
  /// previous route [prev] the user came from.
  static void nav({
    required String evt,
    required String? route,
    required String? name,
    Map<String, Object?> params = const <String, Object?>{},
    String? prev,
  }) {
    if (!enabled) return;
    _write(<String, Object?>{
      't': 'nav',
      'evt': evt,
      'route': route,
      'name': name,
      'params': params,
      'prev': ?prev,
    });
  }

  /// Emits an API record: method + path + status + duration (+ correlation id,
  /// monotonic [seq], and the active [screen] route at call time). NEVER the
  /// Authorization header, request/response body, or query string.
  static void api({
    required String method,
    required String path,
    required int? status,
    required int ms,
    String? reqId,
    int? seq,
    String? screen,
  }) {
    if (!enabled) return;
    _write(<String, Object?>{
      't': 'api',
      'm': method.toUpperCase(),
      'path': DiagRedaction.scrubPath(path),
      'status': status,
      'ms': ms,
      'reqId': reqId,
      'seq': ?seq,
      'screen': ?screen,
    });
  }

  /// Emits a DOMAIN event: a named seam ([name]) with a structured [data]
  /// payload. The payload is defensively scrubbed ([DiagRedaction.scrubMap]) so
  /// a token accidentally handed in by a caller is reduced to a handle.
  static void event(String name, [Map<String, Object?> data = const {}]) {
    if (!enabled) return;
    _write(<String, Object?>{
      't': 'evt',
      'name': name,
      'data': DiagRedaction.scrubMap(data),
    });
  }

  /// Stamps [record] with `ts`, encodes it, prefixes it, and hands it to the
  /// sink(s). Total: a serialization failure degrades to a marker line rather
  /// than throwing into a caller's hot path.
  static void _write(Map<String, Object?> record) {
    record['ts'] = clock().toUtc().toIso8601String();
    String line;
    try {
      line = '$prefix ${jsonEncode(record)}';
    } catch (_) {
      line = '$prefix {"t":"${record['t']}","err":"encode_failed"}';
    }
    sink(line);
    final persistent = persistentSink;
    if (persistent != null) {
      try {
        persistent.add(line, flushNow: _isFailureRecord(record));
      } catch (_) {
        // Fail-soft by contract: the persistence tee can never break the
        // logcat stream or throw into the emitting hot path.
      }
    }
  }

  /// True for records that describe a failure — the persistence buffer is
  /// flushed promptly on these so a crash right after cannot lose the evidence.
  static bool _isFailureRecord(Map<String, Object?> record) {
    final t = record['t'];
    if (t == 'api') {
      final status = record['status'];
      return status == null || (status is int && status >= 400);
    }
    if (t == 'evt') {
      final name = record['name'];
      if (name is! String) return false;
      final lower = name.toLowerCase();
      return lower.contains('error') || lower.contains('fail');
    }
    return false;
  }

  static void _defaultSink(String line) {
    // dart:developer log is the primary channel (structured, survives release
    // stripping of print); debugPrint mirrors it to stdout/logcat so a plain
    // `flutter logs` / `adb logcat` grep sees it too.
    developer.log(line, name: 'jeeb-diag');
    debugPrint(line);
  }
}

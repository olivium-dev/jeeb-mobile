import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'diag_redaction.dart';

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
/// The `t` discriminator is `nav` | `api` | `evt`. Every record carries an
/// ISO-8601 `ts`. Redaction is by DESIGN — see [DiagRedaction]; no token, body,
/// Authorization header, or query string ever reaches a line.
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

  /// Clock for the `ts` field, overridable in tests for deterministic output.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Restores production defaults. Call from a test `tearDown`.
  @visibleForTesting
  static void resetForTest() {
    enabledOverride = null;
    sink = _defaultSink;
    clock = DateTime.now;
  }

  /// Emits a NAVIGATION record. Query tokens are never included — only the
  /// route path pattern, its name, and its path params.
  static void nav({
    required String evt,
    required String? route,
    required String? name,
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    if (!enabled) return;
    _write(<String, Object?>{
      't': 'nav',
      'evt': evt,
      'route': route,
      'name': name,
      'params': params,
    });
  }

  /// Emits an API record: method + path + status + duration only. NEVER the
  /// Authorization header, request/response body, or query string.
  static void api({
    required String method,
    required String path,
    required int? status,
    required int ms,
    String? reqId,
  }) {
    if (!enabled) return;
    _write(<String, Object?>{
      't': 'api',
      'm': method.toUpperCase(),
      'path': DiagRedaction.scrubPath(path),
      'status': status,
      'ms': ms,
      'reqId': reqId,
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
  /// sink. Total: a serialization failure degrades to a marker line rather than
  /// throwing into a caller's hot path.
  static void _write(Map<String, Object?> record) {
    record['ts'] = clock().toUtc().toIso8601String();
    String line;
    try {
      line = '$prefix ${jsonEncode(record)}';
    } catch (_) {
      line = '$prefix {"t":"${record['t']}","err":"encode_failed"}';
    }
    sink(line);
  }

  static void _defaultSink(String line) {
    // dart:developer log is the primary channel (structured, survives release
    // stripping of print); debugPrint mirrors it to stdout/logcat so a plain
    // `flutter logs` / `adb logcat` grep sees it too.
    developer.log(line, name: 'jeeb-diag');
    debugPrint(line);
  }
}

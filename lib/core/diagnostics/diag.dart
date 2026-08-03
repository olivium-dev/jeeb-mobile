import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'diag_redaction.dart';

abstract interface class DiagPersistentSink {
  void add(String line, {bool flushNow = false});

  Future<void> flush();
}

abstract final class Diag {
  /// Stable, greppable logcat prefix; do NOT change — external tooling matches this.
  static const String prefix = '[jeeb-diag]';

  static const bool _diagDefine = bool.fromEnvironment('JEEB_DIAG');

  @visibleForTesting
  static bool? enabledOverride;

  static bool get enabled => enabledOverride ?? (kDebugMode || _diagDefine);

  @visibleForTesting
  static void Function(String line) sink = _defaultSink;

  static DiagPersistentSink? persistentSink;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static String? currentScreen;

  static int _apiSeq = 0;

  static int nextApiSeq() => ++_apiSeq;

  static Future<void> flushPersistent() async {
    final persistent = persistentSink;
    if (persistent == null) return;
    try {
      await persistent.flush();
    } catch (_) {
    }
  }

  @visibleForTesting
  static void resetForTest() {
    enabledOverride = null;
    sink = _defaultSink;
    clock = DateTime.now;
    persistentSink = null;
    currentScreen = null;
    _apiSeq = 0;
  }

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

  static void event(String name, [Map<String, Object?> data = const {}]) {
    if (!enabled) return;
    _write(<String, Object?>{
      't': 'evt',
      'name': name,
      'data': DiagRedaction.scrubMap(data),
    });
  }

  /// GESTURE record: Flutter engine interaction including Maestro-injected taps.
  /// [id]=Semantics.identifier at tap point (Maestro matches this),
  static void gesture({
    required String type,
    required int x,
    required int y,
    String? screen,
    String? id,
    String? text,
    String? target,
    String? key,
    String? idInner,
  }) {
    if (!enabled) return;
    _write(<String, Object?>{
      't': 'gesture',
      'type': type,
      'x': x,
      'y': y,
      'screen': screen,
      'id': id,
      'text': text,
      'target': target,
      'key': key,
      'idInner': ?idInner,
    });
  }

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
      }
    }
  }

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
    developer.log(line, name: 'jeeb-diag');
    debugPrint(line);
  }
}

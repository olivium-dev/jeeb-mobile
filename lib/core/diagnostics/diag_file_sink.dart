import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'diag.dart';

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

  static const String dirName = 'diag';

  static const String appVersion = String.fromEnvironment(
    'JEEB_APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  static const String buildSha = String.fromEnvironment('JEEB_BUILD_SHA');

  static DiagFileSink? active;

  final Future<Directory> Function() _baseDirectoryProvider;
  final DateTime Function() _clock;
  final Map<String, Object?> _sessionMeta;

  final String role;

  final int maxSessions;

  final int maxTotalBytes;

  final int maxSessionBytes;

  final int flushThresholdLines;

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

  String? get sessionFilePath => _file?.path;

  String? get directoryPath => _file?.parent.path;

  @visibleForTesting
  bool get isBroken => _broken;

  @visibleForTesting
  Future<void> get pendingIo => _ioChain;

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
    }
  }

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
    }
  }

  @visibleForTesting
  static void resetGlobalForTest() {
    active = null;
  }

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

  @override
  Future<void> flush() {
    _scheduleFlush();
    return _ioChain;
  }

  Future<void> close() => flush();

  static String _fileNameFor(DateTime startedAtUtc, String role) {
    final t = startedAtUtc;
    String p2(int n) => n.toString().padLeft(2, '0');
    String p3(int n) => n.toString().padLeft(3, '0');
    final stamp = '${t.year}-${p2(t.month)}-${p2(t.day)}'
        'T${p2(t.hour)}-${p2(t.minute)}-${p2(t.second)}-${p3(t.millisecond)}Z';
    final safeRole = role.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$stamp-$safeRole.jsonl';
  }

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

  static String _stripPrefix(String line) {
    const marker = '${Diag.prefix} ';
    return line.startsWith(marker) ? line.substring(marker.length) : line;
  }

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

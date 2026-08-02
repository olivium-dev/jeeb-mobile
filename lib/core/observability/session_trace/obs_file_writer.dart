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

  static const String dirName = 'obs_trace';

  static const String appVersion = String.fromEnvironment(
    'JEEB_APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  static const String buildSha = String.fromEnvironment('JEEB_BUILD_SHA');

  static ObsFileWriter? active;

  final Future<Directory> Function() _baseDirectoryProvider;
  final DateTime Function() _clock;
  final Map<String, Object?> _sessionMeta;

  final String sessionId;

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

  @override
  String? get sessionFilePath => _file?.path;

  String? get directoryPath => _file?.parent.path;

  @visibleForTesting
  bool get isBroken => _broken;

  @visibleForTesting
  Future<void> get pendingIo => _ioChain;

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
        flushThresholdLines: 1,
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
      return null;
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
    }
  }

  @visibleForTesting
  static void resetGlobalForTest() {
    active = null;
  }

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

  @override
  Future<void> flush() {
    _scheduleFlush();
    return _ioChain;
  }

  @override
  Future<void> close() => flush();


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
        'type': 'meta',
        'name': 'obs_lines_dropped',
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

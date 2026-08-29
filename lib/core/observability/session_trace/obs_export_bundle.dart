import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../diagnostics/diag_file_sink.dart';
import 'secret_redactor.dart';

final class ObsRecordingInterval {
  const ObsRecordingInterval({required this.startUtc, required this.endUtc});

  final DateTime startUtc;
  final DateTime endUtc;

  bool contains(DateTime timestampUtc) =>
      !timestampUtc.isBefore(startUtc) && !timestampUtc.isAfter(endUtc);
}

final class ObsExportBundle {
  const ObsExportBundle({required this.obsPath, this.diagPath});

  final String obsPath;
  final String? diagPath;

  List<String> get paths => <String>[obsPath, ?diagPath];
}

abstract final class ObsExportBundleBuilder {
  static int _sequence = 0;

  static Future<String?> createSanitizedDiagSnapshot({
    required String diagSourcePath,
    List<ObsRecordingInterval>? intervals,
    Future<Directory> Function()? exportDirectoryProvider,
    DateTime Function()? clock,
  }) async {
    final now = (clock ?? DateTime.now)().toUtc();
    final directory = await _exportDirectory(exportDirectoryProvider);
    final stem = '${now.microsecondsSinceEpoch}-${_sequence++}';
    final snapshot = await _createDiagSnapshot(
      directory: directory,
      stem: stem,
      sourcePath: diagSourcePath,
      intervals: intervals,
    );
    return snapshot?.path;
  }

  static Future<ObsExportBundle?> create({
    required String? obsSourcePath,
    required List<ObsRecordingInterval> intervals,
    Future<Directory> Function()? exportDirectoryProvider,
    String? diagSourcePath,
    DateTime Function()? clock,
  }) async {
    if (obsSourcePath == null) return null;
    final source = File(obsSourcePath);
    if (!await source.exists()) return null;

    final now = (clock ?? DateTime.now)().toUtc();
    final directory = await _exportDirectory(exportDirectoryProvider);
    final stem = '${now.microsecondsSinceEpoch}-${_sequence++}';
    final obsSnapshot = File('${directory.path}/$stem-obs.jsonl');
    final frozenObsBytes = await source.readAsBytes();
    await obsSnapshot.writeAsBytes(frozenObsBytes, flush: true);

    final activeDiagPath =
        diagSourcePath ?? DiagFileSink.active?.sessionFilePath;
    final diagSnapshot = await _createDiagSnapshot(
      directory: directory,
      stem: stem,
      sourcePath: activeDiagPath,
      intervals: intervals,
    );
    return ObsExportBundle(
      obsPath: obsSnapshot.path,
      diagPath: diagSnapshot?.path,
    );
  }

  static Future<File?> _createDiagSnapshot({
    required Directory directory,
    required String stem,
    required String? sourcePath,
    required List<ObsRecordingInterval>? intervals,
  }) async {
    if (sourcePath == null) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final target = File('${directory.path}/$stem-diag-events.jsonl');
    final sink = target.openWrite();
    try {
      await for (final line
          in source
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final sanitized = _sanitizeDiagEvent(line, intervals);
        if (sanitized != null) sink.writeln(jsonEncode(sanitized));
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return target;
  }

  static Map<String, Object?>? _sanitizeDiagEvent(
    String line,
    List<ObsRecordingInterval>? intervals,
  ) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map || decoded['t'] != 'evt') return null;
      final name = decoded['name'];
      final rawTimestamp = decoded['ts'];
      if (name is! String ||
          !RegExp(r'^(?!.*\d{4,})[a-z][a-z0-9_]{0,95}$').hasMatch(name) ||
          rawTimestamp is! String) {
        return null;
      }
      final timestamp = DateTime.tryParse(rawTimestamp)?.toUtc();
      if (timestamp == null ||
          (intervals != null &&
              !intervals.any((item) => item.contains(timestamp)))) {
        return null;
      }
      final rawData = decoded['data'];
      final data = rawData is Map
          ? SecretRedactor.redactBody(rawData)
          : const <String, Object?>{};
      return <String, Object?>{
        't': 'evt',
        'name': name,
        'data': data,
        'ts': timestamp.toIso8601String(),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _exportDirectory(
    Future<Directory> Function()? provider,
  ) async {
    final base = provider == null
        ? await getTemporaryDirectory()
        : await provider();
    final directory = Directory('${base.path}/jeeb_trace_exports');
    await directory.create(recursive: true);
    return directory;
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/diagnostics/diag.dart';
import 'voice_clip.dart';
import 'voice_recorder.dart';

typedef TempDirResolver = Future<Directory> Function();

typedef ClipBytesReader = Future<Uint8List> Function(String path);

Future<Directory> _defaultTempDirResolver() =>
    getApplicationDocumentsDirectory();

Future<Uint8List> _defaultClipBytesReader(String path) =>
    File(path).readAsBytes();

class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder({
    AudioRecorder? recorder,
    TempDirResolver tempDirResolver = _defaultTempDirResolver,
    ClipBytesReader bytesReader = _defaultClipBytesReader,
    RecordConfig config = const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 96000,
      sampleRate: 44100,
      numChannels: 1,
    ),
  }) : _recorder = recorder ?? AudioRecorder(),
       _tempDirResolver = tempDirResolver,
       _bytesReader = bytesReader,
       _config = config;

  final AudioRecorder _recorder;
  final TempDirResolver _tempDirResolver;
  final ClipBytesReader _bytesReader;
  final RecordConfig _config;

  String? _activePath;
  final Set<String> _ownedPaths = <String>{};

  @override
  Future<void> start() async {
    final bool granted = await _hasPermission();
    if (!granted) {
      throw const VoiceRecorderException(VoiceRecorderFailure.permissionDenied);
    }
    final String path = await _resolvePath();
    _ownedPaths.add(path);
    try {
      await _recorder.start(_config, path: path);
      _activePath = path;
    } catch (error, stackTrace) {
      _activePath = null;
      await _deleteOwnedPath(path);
      throw _wrap(error, stackTrace);
    }
  }

  @override
  Future<VoiceClip> stop({required Duration recordedDuration}) async {
    final String? activePath = _activePath;
    final String? path = await _stopRecorder();
    final String resolved = path ?? activePath ?? '';
    _activePath = null;
    if (resolved.isEmpty) {
      throw const VoiceRecorderException(VoiceRecorderFailure.unknown);
    }
    if (activePath != null && resolved != activePath) {
      await _deleteOwnedPath(activePath);
    }
    final Uint8List bytes;
    try {
      bytes = await _readBytes(resolved);
    } on VoiceRecorderException {
      await _deleteOwnedPath(resolved);
      rethrow;
    }
    if (bytes.isEmpty) {
      await _deleteOwnedPath(resolved);
      throw const VoiceRecorderException(VoiceRecorderFailure.unknown);
    }
    return VoiceClip(
      bytes: bytes,
      duration: recordedDuration,
      sourcePath: resolved,
    );
  }

  @override
  Future<void> cancel() async {
    final String? path = _activePath;
    _activePath = null;
    try {
      await _recorder.cancel();
    } catch (_) {
      Diag.event('voice_clip_cleanup_failed', const <String, Object?>{
        'op': 'cancel',
      });
    }
    if (path != null) {
      await _deleteOwnedPath(path);
    }
  }

  @override
  Future<void> deleteOwnedClip(VoiceClip clip) async {
    final path = clip.sourcePath;
    if (path == null || path.isEmpty) return;
    await _deleteOwnedPath(path);
  }

  Future<bool> _hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (error, stackTrace) {
      throw _wrap(error, stackTrace);
    }
  }

  Future<String> _resolvePath() async {
    final Directory dir = await _tempDirResolver();
    final String name =
        'voice-request-'
        '${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${dir.path}${Platform.pathSeparator}$name';
  }

  Future<String?> _stopRecorder() async {
    try {
      return await _recorder.stop();
    } catch (error, stackTrace) {
      throw _wrap(error, stackTrace);
    }
  }

  Future<Uint8List> _readBytes(String path) async {
    try {
      return await _bytesReader(path);
    } catch (_) {
      throw const VoiceRecorderException(VoiceRecorderFailure.unknown);
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final File file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _deleteOwnedPath(String path) async {
    if (!_ownedPaths.remove(path)) return;
    await _deleteQuietly(path);
  }

  VoiceRecorderException _wrap(Object error, StackTrace stackTrace) =>
      classifyRecorderFailure(error);
}

/// VOICE-03: the plugin's platform CODE decides; the prose sniff is only the
/// fallback for plugins that raise a bare `Exception`.
VoiceRecorderException classifyRecorderFailure(Object error) {
  if (error is VoiceRecorderException) return error;

  if (error is PlatformException) {
    final String code = error.code.toLowerCase();
    if (code.contains('permission')) {
      return const VoiceRecorderException(
        VoiceRecorderFailure.permissionDenied,
      );
    }
    if (code.contains('unavailable') ||
        code.contains('busy') ||
        code.contains('not_initialized')) {
      return const VoiceRecorderException(VoiceRecorderFailure.unavailable);
    }
  }

  final String message = error.toString().toLowerCase();
  if (message.contains('permission')) {
    return const VoiceRecorderException(VoiceRecorderFailure.permissionDenied);
  }
  if (message.contains('unavailable') ||
      message.contains('busy') ||
      message.contains('not initialized')) {
    return const VoiceRecorderException(VoiceRecorderFailure.unavailable);
  }
  return const VoiceRecorderException(VoiceRecorderFailure.unknown);
}

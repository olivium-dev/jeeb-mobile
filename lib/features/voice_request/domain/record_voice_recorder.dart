import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  })  : _recorder = recorder ?? AudioRecorder(),
        _tempDirResolver = tempDirResolver,
        _bytesReader = bytesReader,
        _config = config;

  final AudioRecorder _recorder;
  final TempDirResolver _tempDirResolver;
  final ClipBytesReader _bytesReader;
  final RecordConfig _config;

  String? _activePath;

  @override
  Future<void> start() async {
    final bool granted = await _hasPermission();
    if (!granted) {
      throw const VoiceRecorderException(
        VoiceRecorderFailure.permissionDenied,
      );
    }
    final String path = await _resolvePath();
    try {
      await _recorder.start(_config, path: path);
      _activePath = path;
    } catch (error, stackTrace) {
      _activePath = null;
      throw _wrap(error, stackTrace);
    }
  }

  @override
  Future<VoiceClip> stop({required Duration recordedDuration}) async {
    final String? path = await _stopRecorder();
    final String resolved = path ?? _activePath ?? '';
    _activePath = null;
    if (resolved.isEmpty) {
      throw const VoiceRecorderException(VoiceRecorderFailure.unknown);
    }
    final Uint8List bytes = await _readBytes(resolved);
    if (bytes.isEmpty) {
      await _deleteQuietly(resolved);
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

    }
    if (path != null) {
      await _deleteQuietly(path);
    }
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
    final String name = 'voice-request-'
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
    } catch (_) {

    }
  }

  VoiceRecorderException _wrap(Object error, StackTrace stackTrace) {
    if (error is VoiceRecorderException) return error;

    final String message = error.toString().toLowerCase();
    if (message.contains('permission')) {
      return const VoiceRecorderException(
        VoiceRecorderFailure.permissionDenied,
      );
    }
    if (message.contains('unavailable') ||
        message.contains('busy') ||
        message.contains('not initialized')) {
      return const VoiceRecorderException(VoiceRecorderFailure.unavailable);
    }
    return const VoiceRecorderException(VoiceRecorderFailure.unknown);
  }
}

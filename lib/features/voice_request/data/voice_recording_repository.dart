import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../domain/voice_clip.dart';

class TranscriptionResult extends Equatable {
  const TranscriptionResult({
    required this.id,
    this.transcript,
    this.status,
    this.language,
    this.reason,
  });

  final String id;
  final String? transcript;
  final String? status;
  final String? language;
  final String? reason;

  @override
  List<Object?> get props => [id, transcript, status, language, reason];
}

enum VoiceUploadFailure { network, server, unknown }

class VoiceUploadException implements Exception {
  const VoiceUploadException(this.failure);
  final VoiceUploadFailure failure;
  @override
  String toString() => 'VoiceUploadException($failure)';
}

abstract class VoiceRecordingRepository {
  Future<TranscriptionResult> upload(VoiceClip clip);
}

class HttpVoiceRecordingRepository implements VoiceRecordingRepository {
  HttpVoiceRecordingRepository({
    required Dio dio,
    Duration transcribeTimeout = defaultTranscribeTimeout,
  }) : _dio = dio,
       _transcribeTimeout = transcribeTimeout;

  static const String endpoint = '/transcribe';

  /// Sized to exceed the gateway's ~30s+ retry budget against
  /// voice-transcription-service. See root cause 5 in
  /// `docs/issues/04-voice-transcript-error.md`.
  static const Duration defaultTranscribeTimeout = Duration(seconds: 40);

  final Dio _dio;
  final Duration _transcribeTimeout;

  @override
  Future<TranscriptionResult> upload(VoiceClip clip) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'fileName': 'voice-request.m4a',
          'contentType': clip.mimeType,
          'audioBase64': base64Encode(clip.bytes),
        },
        options: Options(
          contentType: 'application/json',
          sendTimeout: _transcribeTimeout,
          receiveTimeout: _transcribeTimeout,
        ),
      );
      final body = response.data ?? const <String, dynamic>{};

      final id = body['audioId'] as String?;
      if (id == null || id.isEmpty) {
        throw const VoiceUploadException(VoiceUploadFailure.server);
      }
      return TranscriptionResult(
        id: id,
        transcript: body['transcription'] as String?,
        status: body['status'] as String?,
        language: body['language'] as String?,
        reason: body['reason'] as String?,
      );
    } on DioException catch (e) {
      throw VoiceUploadException(_mapDio(e));
    } on VoiceUploadException {
      rethrow;
    } catch (_) {
      throw const VoiceUploadException(VoiceUploadFailure.unknown);
    }
  }

  VoiceUploadFailure _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return VoiceUploadFailure.network;
      case DioExceptionType.badResponse:
        return VoiceUploadFailure.server;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return VoiceUploadFailure.unknown;
    }
  }
}

class FakeVoiceRecordingRepository implements VoiceRecordingRepository {
  FakeVoiceRecordingRepository({
    this.failure,
    this.transcript,
    this.status,
    this.language,
    this.reason,
  });

  VoiceUploadFailure? failure;

  final String? transcript;
  final String? status;
  final String? language;
  final String? reason;

  int uploadCalls = 0;
  VoiceClip? lastClip;

  @override
  Future<TranscriptionResult> upload(VoiceClip clip) async {
    uploadCalls++;
    lastClip = clip;
    if (failure != null) {
      throw VoiceUploadException(failure!);
    }
    return TranscriptionResult(
      id: 'fake-${clip.duration.inMilliseconds}-$uploadCalls',
      transcript: transcript,
      status: status,
      language: language,
      reason: reason,
    );
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
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

enum VoiceUploadFailure {
  network,
  server,
  unknown,

  /// The request outlived its own timeout budget — never a connectivity fault.
  timeout,

  /// 413: the clip is larger than the gateway accepts. Terminal.
  tooLarge,

  /// 415: the container/codec is not accepted. Terminal.
  unsupportedFormat,

  /// 502/503/504: transcription is down, retry later.
  unavailable,
}

class VoiceUploadException implements Exception {
  const VoiceUploadException(this.failure);
  final VoiceUploadFailure failure;
  @override
  String toString() => 'VoiceUploadException($failure)';
}

abstract class VoiceRecordingRepository {
  Future<TranscriptionResult> upload(VoiceClip clip);
}

/// Optional durable-status capability for repositories whose upload endpoint
/// can return `202 queued`.
///
/// Keeping this separate from [VoiceRecordingRepository] preserves catalog and
/// test implementations that only model synchronous uploads. Production uses
/// [HttpVoiceRecordingRepository], which implements both contracts.
abstract interface class VoiceTranscriptionStatusRepository {
  Future<TranscriptionResult> getTranscriptionStatus(String audioId);
}

class HttpVoiceRecordingRepository
    implements VoiceRecordingRepository, VoiceTranscriptionStatusRepository {
  HttpVoiceRecordingRepository({
    required Dio dio,
    Duration transcribeTimeout = defaultTranscribeTimeout,
  }) : _dio = dio,
       _transcribeTimeout = transcribeTimeout;

  static const String endpoint = '/transcribe';
  static String statusEndpoint(String audioId) =>
      '$endpoint/status/${Uri.encodeComponent(audioId)}';

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

  @override
  Future<TranscriptionResult> getTranscriptionStatus(String audioId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        statusEndpoint(audioId),
        options: Options(receiveTimeout: _transcribeTimeout),
      );
      final body = response.data ?? const <String, dynamic>{};
      final returnedId =
          (body['audio_id'] as String?) ??
          (body['audioId'] as String?) ??
          audioId;
      return TranscriptionResult(
        id: returnedId,
        transcript:
            (body['transcript'] as String?) ??
            (body['transcription'] as String?),
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
    // The HTTP status is authoritative for 413/415: an RFC 7807 body is not
    // guaranteed, and `ValidationFailure` does not carry the status itself.
    final int? status = e.response?.statusCode;
    if (status == 413) return VoiceUploadFailure.tooLarge;
    if (status == 415) return VoiceUploadFailure.unsupportedFormat;
    return switch (AppFailure.of(e)) {
      TimeoutFailure() => VoiceUploadFailure.timeout,
      NetworkFailure() => VoiceUploadFailure.network,
      ServerFailure(:final bool unavailable) when unavailable =>
        VoiceUploadFailure.unavailable,
      ServerFailure() || ValidationFailure() => VoiceUploadFailure.server,
      _ => VoiceUploadFailure.unknown,
    };
  }
}

class FakeVoiceRecordingRepository
    implements VoiceRecordingRepository, VoiceTranscriptionStatusRepository {
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
  int statusCalls = 0;
  VoiceClip? lastClip;
  final List<TranscriptionResult> statusResults = <TranscriptionResult>[];
  VoiceUploadFailure? statusFailure;

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

  @override
  Future<TranscriptionResult> getTranscriptionStatus(String audioId) async {
    statusCalls++;
    if (statusFailure != null) {
      throw VoiceUploadException(statusFailure!);
    }
    if (statusResults.isEmpty) {
      return TranscriptionResult(
        id: audioId,
        transcript: transcript,
        status: status ?? 'queued',
        language: language,
        reason: reason,
      );
    }
    return statusResults.removeAt(0);
  }
}

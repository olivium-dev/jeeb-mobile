import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../domain/voice_clip.dart';

/// Result echoed back by the gateway after a successful upload. The
/// `transcript` is optional because the back-end may complete the upload
/// synchronously but resolve the Whisper transcription asynchronously; the UI
/// only requires the id to acknowledge "sent".
class TranscriptionResult extends Equatable {
  const TranscriptionResult({required this.id, this.transcript});

  final String id;
  final String? transcript;

  @override
  List<Object?> get props => [id, transcript];
}

/// Reason a voice upload failed. The cubit maps these onto user copy.
enum VoiceUploadFailure { network, server, unknown }

class VoiceUploadException implements Exception {
  const VoiceUploadException(this.failure);
  final VoiceUploadFailure failure;
  @override
  String toString() => 'VoiceUploadException($failure)';
}

/// Repository that ships a captured clip to the jeeb-gateway transcription
/// endpoint. The gateway proxies to `voice-transcription-service` per the
/// REUSE-MAP — jeeb-mobile only talks to its own BFF.
abstract class VoiceRecordingRepository {
  Future<TranscriptionResult> upload(VoiceClip clip);
}

class HttpVoiceRecordingRepository implements VoiceRecordingRepository {
  HttpVoiceRecordingRepository({required Dio dio}) : _dio = dio;

  /// Endpoint verified against Mockoon :3055 — `POST /v1/voice/transcribe`.
  /// Acceptance-test note (T-MOB-011 AC): mock returns 200 with audioId +
  /// transcription fields. Path passes through unchanged (useMockPrefixes=false).
  static const String endpoint = '/v1/voice/transcribe';

  final Dio _dio;

  @override
  Future<TranscriptionResult> upload(VoiceClip clip) async {
    try {
      final form = FormData.fromMap({
        'durationMs': clip.duration.inMilliseconds,
        'audio': MultipartFile.fromBytes(
          clip.bytes,
          filename: 'voice-request.m4a',
          contentType: DioMediaType.parse(clip.mimeType),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      final body = response.data ?? const <String, dynamic>{};
      // Mock contract: { audioId, transcription, status, language }
      final id = (body['audioId'] ?? body['id']) as String?;
      if (id == null || id.isEmpty) {
        throw const VoiceUploadException(VoiceUploadFailure.server);
      }
      return TranscriptionResult(
        id: id,
        transcript: (body['transcription'] ?? body['transcript']) as String?,
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
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return VoiceUploadFailure.network;
      case DioExceptionType.badResponse:
        return VoiceUploadFailure.server;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return VoiceUploadFailure.unknown;
    }
  }
}

/// In-memory stub used by the UI milestone + cubit tests. Echoes the clip
/// duration in the result id so tests can assert ordering, and supports an
/// injected failure to cover the error branch.
class FakeVoiceRecordingRepository implements VoiceRecordingRepository {
  FakeVoiceRecordingRepository({this.failure, this.transcript});

  /// If non-null, the next [upload] throws with this failure. Reset to null
  /// to recover after the cubit's retry.
  VoiceUploadFailure? failure;

  /// Transcript echoed in the success response. Tests can leave this null to
  /// verify the cubit handles a delayed-transcript response.
  final String? transcript;

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
    );
  }
}

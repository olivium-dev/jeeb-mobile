import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../domain/voice_clip.dart';





class TranscriptionResult extends Equatable {
  const TranscriptionResult({required this.id, this.transcript});

  final String id;
  final String? transcript;

  @override
  List<Object?> get props => [id, transcript];
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
  HttpVoiceRecordingRepository({required Dio dio}) : _dio = dio;

  
  
  
  
  
  
  static const String endpoint = '/transcribe';

  final Dio _dio;

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
        options: Options(contentType: 'application/json'),
      );
      final body = response.data ?? const <String, dynamic>{};
      
      final id = body['audioId'] as String?;
      if (id == null || id.isEmpty) {
        throw const VoiceUploadException(VoiceUploadFailure.server);
      }
      return TranscriptionResult(
        id: id,
        transcript: body['transcription'] as String?,
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
  FakeVoiceRecordingRepository({this.failure, this.transcript});

  
  
  VoiceUploadFailure? failure;

  
  
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

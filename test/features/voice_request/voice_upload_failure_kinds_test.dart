// AE-15/VOICE-01 — `_mapDio` collapsed every timeout into `network` and every
// badResponse (413 / 415 / 503) into `server`, and the polling loop's own
// exhaustion was reported as "check your connection".

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_error_policy.dart';

VoiceClip _clip() => VoiceClip(
      bytes: Uint8List.fromList(List<int>.filled(64, 0x55)),
      duration: const Duration(seconds: 3),
      sourcePath: '/tmp/clip.m4a',
    );

Dio _dioRejecting(DioExceptionType type, {int? status}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions o, RequestInterceptorHandler h) => h.reject(
        DioException(
          requestOptions: o,
          type: type,
          response: status == null
              ? null
              : Response<dynamic>(requestOptions: o, statusCode: status),
        ),
      ),
    ),
  );
  return dio;
}

Future<VoiceUploadFailure> _failureFor(Dio dio) async {
  final repo = HttpVoiceRecordingRepository(dio: dio);
  try {
    await repo.upload(_clip());
  } on VoiceUploadException catch (e) {
    return e.failure;
  }
  fail('upload should have thrown');
}

void main() {
  group('HttpVoiceRecordingRepository._mapDio · AE-15', () {
    test('413 → tooLarge, not server', () async {
      expect(
        await _failureFor(_dioRejecting(DioExceptionType.badResponse, status: 413)),
        VoiceUploadFailure.tooLarge,
      );
    });

    test('415 → unsupportedFormat, not server', () async {
      expect(
        await _failureFor(_dioRejecting(DioExceptionType.badResponse, status: 415)),
        VoiceUploadFailure.unsupportedFormat,
      );
    });

    test('503 → unavailable, not a flat server failure', () async {
      expect(
        await _failureFor(_dioRejecting(DioExceptionType.badResponse, status: 503)),
        VoiceUploadFailure.unavailable,
      );
    });

    test('500 stays server', () async {
      expect(
        await _failureFor(_dioRejecting(DioExceptionType.badResponse, status: 500)),
        VoiceUploadFailure.server,
      );
    });

    // VOICE-01: a timeout is not a connectivity fault.
    test('receiveTimeout → timeout, NOT network', () async {
      expect(
        await _failureFor(_dioRejecting(DioExceptionType.receiveTimeout)),
        VoiceUploadFailure.timeout,
      );
    });

    test('connectionError stays network', () async {
      expect(
        await _failureFor(_dioRejecting(DioExceptionType.connectionError)),
        VoiceUploadFailure.network,
      );
    });
  });

  group('VoiceRecordingError · the seven upload kinds', () {
    test('hasUploadFailure covers all seven', () {
      for (final VoiceRecordingError error in const <VoiceRecordingError>[
        VoiceRecordingError.uploadNetwork,
        VoiceRecordingError.uploadServer,
        VoiceRecordingError.uploadUnknown,
        VoiceRecordingError.uploadTimeout,
        VoiceRecordingError.uploadTooLarge,
        VoiceRecordingError.uploadUnsupported,
        VoiceRecordingError.uploadUnavailable,
      ]) {
        expect(
          VoiceRecordingState(error: error).hasUploadFailure,
          isTrue,
          reason: '$error must render the retained-clip surface',
        );
        expect(isUploadVoiceError(error), isTrue);
        expect(isTransientVoiceError(error), isFalse);
      }
    });

    // R6: 413/415 can never succeed on a retry of the SAME clip.
    test('only tooLarge and unsupported are terminal', () {
      expect(
        const VoiceRecordingState(error: VoiceRecordingError.uploadTooLarge)
            .hasTerminalUploadFailure,
        isTrue,
      );
      expect(
        const VoiceRecordingState(error: VoiceRecordingError.uploadUnsupported)
            .hasTerminalUploadFailure,
        isTrue,
      );
      for (final VoiceRecordingError retryable in const <VoiceRecordingError>[
        VoiceRecordingError.uploadNetwork,
        VoiceRecordingError.uploadServer,
        VoiceRecordingError.uploadUnknown,
        VoiceRecordingError.uploadTimeout,
        VoiceRecordingError.uploadUnavailable,
      ]) {
        expect(
          VoiceRecordingState(error: retryable).hasTerminalUploadFailure,
          isFalse,
        );
      }
    });
  });

  group('VoiceRecordingCubit · the upload-failure map', () {
    for (final MapEntry<VoiceUploadFailure, VoiceRecordingError> entry
        in const <VoiceUploadFailure, VoiceRecordingError>{
      VoiceUploadFailure.network: VoiceRecordingError.uploadNetwork,
      VoiceUploadFailure.server: VoiceRecordingError.uploadServer,
      VoiceUploadFailure.unknown: VoiceRecordingError.uploadUnknown,
      VoiceUploadFailure.timeout: VoiceRecordingError.uploadTimeout,
      VoiceUploadFailure.tooLarge: VoiceRecordingError.uploadTooLarge,
      VoiceUploadFailure.unsupportedFormat: VoiceRecordingError.uploadUnsupported,
      VoiceUploadFailure.unavailable: VoiceRecordingError.uploadUnavailable,
    }.entries) {
      test('${entry.key.name} maps to ${entry.value.name}', () async {
        final cubit = VoiceRecordingCubit(
          recorder: FakeVoiceRecorder(),
          player: FakeVoicePlayer(),
          repository: FakeVoiceRecordingRepository(failure: entry.key),
          tickerFactory: (_) => const Stream<Duration>.empty(),
          initialState: VoiceRecordingState(
            phase: VoiceRecordingPhase.recorded,
            clip: _clip(),
          ),
        );

        await cubit.send();

        expect(cubit.state.error, entry.value);
        await cubit.close();
      });
    }
  });
}

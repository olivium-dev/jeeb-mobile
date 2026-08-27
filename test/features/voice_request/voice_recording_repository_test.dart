import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';

void main() {
  group('HttpVoiceRecordingRepository', () {
    test(
      'surfaces status, language, and reason from the gateway payload',
      () async {
        final adapter = _DelayedJsonAdapter(
          body: const <String, Object?>{
            'audioId': 'audio-123',
            'status': 'queued',
            'transcription': null,
            'language': 'ar-LB',
            'reason': 'circuit_open',
          },
        );
        final dio = _dioWith(adapter);
        addTearDown(() => dio.close(force: true));
        final repository = HttpVoiceRecordingRepository(dio: dio);

        final result = await repository.upload(_clip());

        expect(result.id, 'audio-123');
        expect(result.status, 'queued');
        expect(result.language, 'ar-LB');
        expect(result.reason, 'circuit_open');
      },
    );

    test('a slow response inside the per-call timeout succeeds', () async {
      const simulatedDelay = Duration(milliseconds: 300);
      const transcribeTimeout = Duration(milliseconds: 500);
      final adapter = _DelayedJsonAdapter(
        delay: simulatedDelay,
        body: const <String, Object?>{
          'audioId': 'audio-slow',
          'status': 'transcribed',
          'transcription': 'Bring water',
          'language': 'en',
          'reason': null,
        },
      );
      final dio = _dioWith(
        adapter,
        globalReceiveTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(() => dio.close(force: true));
      final repository = HttpVoiceRecordingRepository(
        dio: dio,
        transcribeTimeout: transcribeTimeout,
      );

      final result = await repository.upload(_clip());

      expect(result.id, 'audio-slow');
      expect(result.transcript, 'Bring water');
      expect(adapter.lastRequest?.sendTimeout, transcribeTimeout);
      expect(adapter.lastRequest?.receiveTimeout, transcribeTimeout);
    });

    test('the production timeout covers the gateway retry budget', () {
      expect(
        HttpVoiceRecordingRepository.defaultTranscribeTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
      );
    });
  });
}

VoiceClip _clip() => VoiceClip(
  bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
  duration: const Duration(seconds: 2),
);

Dio _dioWith(
  HttpClientAdapter adapter, {
  Duration globalReceiveTimeout = const Duration(seconds: 15),
}) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://gateway.test',
      receiveTimeout: globalReceiveTimeout,
    ),
  )..httpClientAdapter = adapter;
}

class _DelayedJsonAdapter implements HttpClientAdapter {
  _DelayedJsonAdapter({required this.body, this.delay = Duration.zero});

  final Map<String, Object?> body;
  final Duration delay;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final receiveTimeout = options.receiveTimeout;
    if (receiveTimeout != null && delay > receiveTimeout) {
      await Future<void>.delayed(receiveTimeout);
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    await Future<void>.delayed(delay);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

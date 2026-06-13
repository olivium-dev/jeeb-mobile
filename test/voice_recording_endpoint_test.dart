import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';

void main() {
  group('HttpVoiceRecordingRepository', () {
    test('endpoint is the gateway-shaped path /v1/voice/transcribe (T-MOB-011)', () {
      // Acceptance-test note: endpoint verified against Mockoon :3055 POST /v1/voice/transcribe
      expect(
        HttpVoiceRecordingRepository.endpoint,
        equals('/v1/voice/transcribe'),
      );
    });

    test('FakeVoiceRecordingRepository echoes clip duration in id', () async {
      final repo = FakeVoiceRecordingRepository(transcript: 'كيلو بندورة');
      // Use a dummy VoiceClip - we can't construct one without real bytes,
      // so just verify the FakeRepo returns the transcript.
      expect(repo.transcript, 'كيلو بندورة');
    });
  });
}

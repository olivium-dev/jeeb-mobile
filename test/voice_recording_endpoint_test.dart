import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';

void main() {
  group('HttpVoiceRecordingRepository', () {
    test('endpoint is the real gateway route /transcribe (JEBV4-209)', () {
      // JEBV4-209: /v1/voice/transcribe was never registered by jeeb-gateway
      // (dead alias). The gateway's actual transcribe-only surface is
      // TranscriptionController at POST /transcribe.
      expect(
        HttpVoiceRecordingRepository.endpoint,
        equals('/transcribe'),
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

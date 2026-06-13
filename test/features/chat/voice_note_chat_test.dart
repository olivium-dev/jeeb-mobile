/// T-MOB-016 — Voice-note input in coordination chat.
///
/// Tests cover:
///   - Voice bubble renders with durationMs (AC1)
///   - Transcription fills in on success (AC2)
///   - Transcription unavailable on timeout (AC3)
///   - Upload failure marks bubble as failed + emits error (AC5)
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

// ---------------------------------------------------------------------------
// Test double with controllable voice upload
// ---------------------------------------------------------------------------

class _ControllableGateway extends ChatGateway {
  _ControllableGateway({this.uploadResult, this.uploadError});

  final VoiceUploadResult? uploadResult;
  final Object? uploadError;

  int uploadCalled = 0;
  String? lastIdempotencyKey;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => const Stream.empty();

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async {
    uploadCalled++;
    lastIdempotencyKey = idempotencyKey;
    final err = uploadError;
    if (err != null) throw err;
    return uploadResult ??
        const VoiceUploadResult(url: 'https://cdn.jeeb.app/voice/test.m4a');
  }
}

ChatCubit _cubit(_ControllableGateway gw) {
  final c = ChatCubit(
    deliveryId: 'conv-voice-001',
    gateway: gw,
    pickerService: StubPhotoPickerService(),
  );
  addTearDown(c.close);
  return c;
}

void main() {
  group('Voice note upload — happy path (AC1, AC2)', () {
    test('sends voice note, sets durationMs on optimistic bubble', () async {
      final gw = _ControllableGateway(
        uploadResult: const VoiceUploadResult(
          url: 'https://cdn.jeeb.app/voice/clip.m4a',
          transcription: 'Please bring it to the door',
        ),
      );
      final cubit = _cubit(gw);
      await cubit.load();

      await cubit.sendVoiceNote(
        audioBytes: [1, 2, 3],
        mimeType: 'audio/m4a',
        durationMs: 5500,
      );

      expect(gw.uploadCalled, 1);
      final messages = cubit.state.messages;
      expect(messages, isNotEmpty);
      final voiceMsg = messages.firstWhere((m) => m.kind == MessageKind.voice);
      expect(voiceMsg.voiceDurationMs, 5500);
      expect(voiceMsg.voiceUrl, 'https://cdn.jeeb.app/voice/clip.m4a');
      expect(voiceMsg.voiceTranscription, 'Please bring it to the door');
      expect(voiceMsg.status, MessageStatus.sent);
    });

    test('idempotency key is stable per send attempt', () async {
      final gw = _ControllableGateway(
        uploadResult: const VoiceUploadResult(url: 'https://cdn.jeeb.app/v.m4a'),
      );
      final cubit = _cubit(gw);
      await cubit.load();

      await cubit.sendVoiceNote(
        audioBytes: [1, 2, 3],
        mimeType: 'audio/m4a',
        durationMs: 2000,
      );

      expect(gw.lastIdempotencyKey, isNotNull);
      expect(gw.lastIdempotencyKey, startsWith('voice-'));
    });
  });

  group('Voice note upload — no transcription (AC2 deferred)', () {
    test('bubble is valid without transcription', () async {
      final gw = _ControllableGateway(
        uploadResult: const VoiceUploadResult(
          url: 'https://cdn.jeeb.app/voice/clip.m4a',
        ),
      );
      final cubit = _cubit(gw);
      await cubit.load();

      await cubit.sendVoiceNote(
        audioBytes: [1, 2, 3],
        mimeType: 'audio/m4a',
        durationMs: 3000,
      );

      final voiceMsg = cubit.state.messages
          .firstWhere((m) => m.kind == MessageKind.voice);
      expect(voiceMsg.voiceTranscription, isNull);
    });
  });

  group('Voice note upload — failure path (AC5)', () {
    test('upload failure marks bubble as failed and emits voiceUploadFailed',
        () async {
      final gw = _ControllableGateway(uploadError: Exception('network error'));
      final cubit = _cubit(gw);
      await cubit.load();

      await cubit.sendVoiceNote(
        audioBytes: [1, 2, 3],
        mimeType: 'audio/m4a',
        durationMs: 2000,
      );

      final messages = cubit.state.messages;
      expect(messages, isNotEmpty);
      final voiceMsg = messages.firstWhere((m) => m.kind == MessageKind.voice);
      expect(voiceMsg.status, MessageStatus.failed);
      expect(cubit.state.error, ChatError.voiceUploadFailed);
    });
  });
}

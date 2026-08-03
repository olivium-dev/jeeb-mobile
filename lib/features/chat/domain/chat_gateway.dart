import 'dart:async';
import 'dart:typed_data';

import '../../client_offers/domain/offers_repository.dart' show OfferAcceptResult;
import 'delivery_chat_message.dart';

/// TRAP: id-scoped HTTP calls must short-circuit on this to avoid guaranteed-404s.
const String kComposeConversationSentinel = 'new';

abstract class ChatGateway {
  /// History newest last.
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId);

  /// TRAP: default must NOT be accepted (renders false-positive banner).
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.broadcasting;

  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  );

  /// Inbound chat events.
  Stream<ChatEvent> subscribe(String conversationId);

  /// TRAP: name kept (old poll deleted) to avoid burying behavior change.
  bool get supportsPolling => false;

  /// Returns server-created deliveryId.
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async =>
      OfferAcceptResult.empty;

  /// TRAP: idempotencyKey must be stable across retries.
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async => const VoiceUploadResult(url: '', transcription: null);

  /// Default empty preserves legacy local-bytes photo bubble.
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => '';

  /// Default empty renders unavailable.
  Future<Uint8List> fetchImageBytes(String objectRef) async => Uint8List(0);
}

class VoiceUploadResult {
  const VoiceUploadResult({required this.url, this.transcription});

  final String url;
  /// AI-generated transcription; null until async resolves or times out.
  final String? transcription;
}

/// Sealed union of inbound chat events.
sealed class ChatEvent {
  const ChatEvent();
}

/// TRAP: driven by stream lifecycle, never by arm time.
class RealtimeTransportChanged extends ChatEvent {
  const RealtimeTransportChanged({required this.live, this.reason});

  final bool live;
  /// Machine-readable cause (diagnostic only).
  final String? reason;
}

class IncomingMessage extends ChatEvent {
  const IncomingMessage(this.message);
  final DeliveryChatMessage message;
}

/// Delivery confirmed (status: sent → delivered).
class DeliveryReceipt extends ChatEvent {
  const DeliveryReceipt(this.messageId);
  final String messageId;
}

/// Read receipt (promotes sent/delivered outgoing).
class ReadReceipt extends ChatEvent {
  const ReadReceipt(this.throughMessageId);
  final String throughMessageId;
}

/// Phase transition (e.g. broadcasting → accepted).
class PhaseChanged extends ChatEvent {
  const PhaseChanged(this.phase, {this.deliveryId});
  final ConversationPhase phase;
  /// Enables Track order when transition created delivery.
  final String? deliveryId;
}

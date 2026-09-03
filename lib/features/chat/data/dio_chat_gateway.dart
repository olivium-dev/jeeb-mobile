import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/diagnostics/chat_diagnostics.dart';
import '../../../core/diagnostics/diag.dart';
import '../../client_offers/domain/offers_repository.dart'
    show OfferAcceptResult, acceptResponseDeliveryId;
import '../../kyc/domain/cdn_asset_gateway.dart';
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/chat_delta_reader.dart';
import '../domain/chat_gateway.dart';
import '../domain/chat_socket.dart';
import '../domain/conversation_lookup.dart';
import '../domain/delivery_chat_message.dart';
import 'chat_message_codec.dart';
import 'chat_realtime_resolver.dart';
import 'web_socket_chat_socket.dart';

class DioChatGateway implements ChatGateway, ChatDeltaReader {
  DioChatGateway({
    required Dio dio,
    required this.currentUserId,
    String? conversationCorrelationKey,
    ChatSocket Function(String conversationId)? socketFactory,
    Uri? socketBaseUri,
    ChatRealtimeResolver? realtimeResolver,
    HandoverCodeStore? handoverCodeStore,
    CdnAssetGateway? assetGateway,
  }) : _dio = dio,
       _correlationKey = conversationCorrelationKey,
       _socketBaseUri = socketBaseUri,
       _socketFactory = socketFactory,
       _realtimeResolver = realtimeResolver,
       _handoverCodeStore = handoverCodeStore,
       _assetGateway = assetGateway;

  final Dio _dio;

  final CdnAssetGateway? _assetGateway;

  final HandoverCodeStore? _handoverCodeStore;

  final String currentUserId;

  final String? _correlationKey;

  final Uri? _socketBaseUri;
  final ChatSocket Function(String conversationId)? _socketFactory;
  final ChatRealtimeResolver? _realtimeResolver;

  late final String _fallbackSenderScope = _mintFallbackSenderScope();

  ChatSocket? _socket;
  bool _socketResolutionInFlight = false;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    if (_isUnresolvedConversation(conversationId)) {
      return const <DeliveryChatMessage>[];
    }
    final response = await _dio.get<dynamic>(
      '/v1/conversations/$conversationId/messages',
    );
    final batch = _decodeHistory(response.data);
    _reportDecode('loadHistory', conversationId, batch);
    return batch.messages;
  }

  @override
  Future<ChatHistoryBatch> loadHistorySince(
    String conversationId,
    String cursor,
  ) async {
    if (_isUnresolvedConversation(conversationId)) {
      return ChatHistoryBatch.empty;
    }
    if (cursor.trim().isEmpty) {
      throw ArgumentError.value(cursor, 'cursor', 'must not be blank');
    }
    final response = await _dio.get<dynamic>(
      '/v1/conversations/$conversationId/messages/since/'
      '${Uri.encodeComponent(cursor)}',
    );
    final batch = _decodeHistory(response.data);
    _reportDecode('loadHistorySince', conversationId, batch);
    return batch;
  }

  void _reportDecode(String op, String conversationId, ChatHistoryBatch batch) {
    if (batch.malformedCount == 0) return;
    Diag.event('chat_history_decode', <String, Object?>{
      'op': op,
      'conversationId': conversationId,
      'decoded': batch.messages.length,
      'malformed': batch.malformedCount,
    });
  }

  ChatHistoryBatch _decodeHistory(dynamic data) {
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      final candidate = data['items'] ?? data['messages'] ?? data['data'];
      if (candidate is! List) {
        return const ChatHistoryBatch(
          messages: <DeliveryChatMessage>[],
          nextCursor: null,
          malformedCount: 1,
        );
      }
      items = candidate;
    } else {
      return const ChatHistoryBatch(
        messages: <DeliveryChatMessage>[],
        nextCursor: null,
        malformedCount: 1,
      );
    }

    final messages = <DeliveryChatMessage>[];
    var malformedCount = 0;
    String? finalRowCursor;
    for (var index = 0; index < items.length; index++) {
      final rawRow = items[index];
      final isPhysicalFinalRow = index == items.length - 1;
      if (rawRow is! Map<String, dynamic> || !_isValidHistoryRow(rawRow)) {
        malformedCount++;
        continue;
      }
      try {
        final message = _parseMessage(
          rawRow,
          fallbackSentAt: _provisionalAnchor(index),
        );
        messages.add(message);
        if (isPhysicalFinalRow) finalRowCursor = message.id;
      } catch (_) {
        malformedCount++;
      }
    }
    return ChatHistoryBatch(
      messages: List<DeliveryChatMessage>.unmodifiable(messages),
      nextCursor: finalRowCursor,
      malformedCount: malformedCount,
    );
  }

  static DateTime _provisionalAnchor(int wireIndex) =>
      _provisionalAnchorOrigin.add(Duration(microseconds: wireIndex));

  static final DateTime _provisionalAnchorOrigin = DateTime.utc(1970);

  bool _isValidHistoryRow(Map<String, dynamic> row) =>
      ChatMessageCodec.isValidRow(row);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    if (_isUnresolvedConversation(conversationId)) {
      return ConversationPhase.broadcasting;
    }
    try {
      final resolvedKey = _correlationKey;
      final hasResolvedKey = resolvedKey != null && resolvedKey.isNotEmpty;
      final correlationKey = hasResolvedKey ? resolvedKey : conversationId;
      if (hasResolvedKey && correlationKey == conversationId) {
        return ConversationPhase.broadcasting;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/conversations',
        queryParameters: <String, Object?>{'correlationKey': correlationKey},
      );
      final data = response.data;
      if (data == null) return ConversationPhase.broadcasting;
      final phase = ConversationPhase.fromWire(data['phase'] as String?);
      if (phase == ConversationPhase.accepted &&
          data['participants'] is List &&
          !_hasActiveWinner(data)) {
        return ConversationPhase.broadcasting;
      }
      return phase == ConversationPhase.unknown
          ? ConversationPhase.broadcasting
          : phase;
    } on DioException catch (e) {
      if (classifyLookupFailure(e) == ConversationLookup.absent) {
        return ConversationPhase.broadcasting;
      }
      throw ChatReadUnavailableException('loadPhase', e);
    } catch (e) {
      throw ChatReadUnavailableException('loadPhase', e);
    }
  }

  bool _hasActiveWinner(Map<String, dynamic> data) {
    final participants = data['participants'];
    if (participants is! List) return false;
    return participants.whereType<Map>().any((p) {
      final role = p['role_in_convo'] as String?;
      final removedAt = p['removed_at'];
      return role == 'jeeber_winner' && removedAt == null;
    });
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async {
    if (_isUnresolvedConversation(conversationId)) {
      return message.copyWith(status: MessageStatus.sent);
    }
    final isText = message.kind == MessageKind.text;
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/conversations/$conversationId/messages',
      data: <String, Object?>{
        'kind': message.kind.wireName,
        if (isText) 'body': message.text else 'payload': _bodyFor(message),
      },
      options: Options(
        headers: <String, Object?>{
          'Idempotency-Key': _idempotencyKeyFor(message),
        },
      ),
    );
    final data = response.data;
    final serverId = data?['id'] as String?;
    return message.copyWith(status: MessageStatus.sent)
      .._serverIdProbe(serverId);
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    _ensureSocket(conversationId);
    return _events.stream;
  }

  @override
  bool get supportsPolling => true;

  @override
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/offers/$offerId/accept',
      data: <String, Object?>{
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
        'acceptedBy': currentUserId,
      },
      options: Options(
        headers: <String, Object?>{'Idempotency-Key': 'accept-$offerId'},
      ),
    );
    final deliveryId = _deliveryIdOf(response.data);
    final handoverCode = _handoverCodeOf(response.data);
    if (_handoverCodeStore != null &&
        deliveryId != null &&
        handoverCode != null) {
      unawaited(
        _handoverCodeStore
            .save(deliveryId: deliveryId, code: handoverCode)
            .catchError((_) {}),
      );
    }
    if (!_events.isClosed) {
      _events.add(
        PhaseChanged(ConversationPhase.accepted, deliveryId: deliveryId),
      );
    }
    return OfferAcceptResult(
      deliveryId: deliveryId,
      handoverCode: handoverCode,
    );
  }

  bool _isUnresolvedConversation(String conversationId) =>
      conversationId.isEmpty || conversationId == kComposeConversationSentinel;

  /// Participant-scoped `Idempotency-Key` for a chat message POST (BUG-13).
  String _idempotencyKeyFor(DeliveryChatMessage message) {
    final sender = currentUserId.isNotEmpty
        ? currentUserId
        : _fallbackSenderScope;
    return '${message.id}-u-$sender';
  }

  static String _mintFallbackSenderScope() {
    final random = Random();
    final head = random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final tail = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return 'anon-$head$tail';
  }

  String? _deliveryIdOf(Map<String, dynamic>? body) {
    if (body == null) return null;
    return acceptResponseDeliveryId(body);
  }

  String? _handoverCodeOf(Map<String, dynamic>? body) {
    if (body == null) return null;
    final raw = body['handoverCode'] ?? body['handover_code'];
    return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  }

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async {
    final form = FormData.fromMap({
      'durationMs': durationMs,
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: 'voice-note.m4a',
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/voice/transcribe',
      data: form,
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final body = response.data ?? const <String, dynamic>{};
    return VoiceUploadResult(
      url: body['url'] as String? ?? body['audioUrl'] as String? ?? '',
      transcription:
          body['transcript'] as String? ?? body['transcription'] as String?,
    );
  }

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final cdn = _assetGateway;
    if (cdn == null) return '';
    return cdn.uploadAsset(
      slot: CdnUploadSlot.chatAttachment,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<Uint8List> fetchImageBytes(String objectRef) async {
    final cdn = _assetGateway;
    if (cdn == null || objectRef.isEmpty) return Uint8List(0);
    return cdn.fetchAsset(objectRef);
  }

  Future<void> dispose() async {
    await _socket?.close();
    if (!_events.isClosed) await _events.close();
  }

  void _ensureSocket(String conversationId) {
    if (_isUnresolvedConversation(conversationId) ||
        _socket != null ||
        _socketResolutionInFlight) {
      return;
    }
    final explicitFactory = _socketFactory;
    if (explicitFactory != null) {
      final socket = explicitFactory(conversationId);
      _socket = socket;
      unawaited(_connectAndJoin(socket, conversationId));
      return;
    }
    final explicitBase = _socketBaseUri;
    if (explicitBase != null) {
      final socket = WebSocketChatSocket(uri: explicitBase);
      _socket = socket;
      unawaited(_connectAndJoin(socket, conversationId));
      return;
    }
    final resolver = _realtimeResolver;
    if (resolver == null) return;
    _socketResolutionInFlight = true;
    unawaited(
      resolver
          .connect(conversationId)
          .then((socket) async {
            if (socket == null || _socket != null) return;
            _socket = socket;
            await _connectAndJoin(socket, conversationId);
          })
          .whenComplete(() => _socketResolutionInFlight = false),
    );
  }

  Future<void> _connectAndJoin(ChatSocket socket, String conversationId) async {
    try {
      await socket.connect();
      socket.send(<String, Object?>{
        'event': 'phx_join',
        'topic': 'jeeb:chat:$conversationId',
        'payload': <String, Object?>{},
        'ref': '1',
      });
      socket.events.listen(_handleFrame);
    } catch (error) {
      ChatDiagnostics.degraded(
        stage: ChatDiagStage.socket,
        reason: 'join_threw_${error.runtimeType}',
        conversationId: conversationId,
      );
    }
  }

  void _handleFrame(Map<String, Object?> frame) {
    if (_events.isClosed) return;
    final event = frame['event'] as String?;
    if (event != 'new_msg') return;
    final payload = frame['payload'];
    if (payload is! Map) return;
    try {
      final message = _parseMessage(payload.cast<String, dynamic>());
      _events.add(IncomingMessage(message));
    } catch (_) {}
  }

  Map<String, Object?> _bodyFor(DeliveryChatMessage message) {
    switch (message.kind) {
      case MessageKind.text:
        return <String, Object?>{'text': message.text};
      case MessageKind.image:
        return <String, Object?>{
          'url': message.imageUrl ?? '',
          if (message.text.isNotEmpty) 'caption': message.text,
        };
      case MessageKind.voice:
        return <String, Object?>{
          'url': message.voiceUrl ?? '',
          'durationMs': message.voiceDurationMs ?? 0,
        };
      case MessageKind.location:
        return <String, Object?>{
          'lat': message.latitude ?? 0,
          'lng': message.longitude ?? 0,
          if (message.text.isNotEmpty) 'label': message.text,
        };
      case MessageKind.photo:
        return <String, Object?>{'caption': message.text};
      case MessageKind.system:
      case MessageKind.offerCard:
      case MessageKind.offerAccepted:
      case MessageKind.offerRejected:
        return <String, Object?>{'text': message.text};
    }
  }

  DeliveryChatMessage _parseMessage(
    Map<String, dynamic> json, {
    DateTime? fallbackSentAt,
  }) => ChatMessageCodec(
    currentUserId,
  ).parse(json, fallbackSentAt: fallbackSentAt);
}

extension on DeliveryChatMessage {
  void _serverIdProbe(String? _) {}
}

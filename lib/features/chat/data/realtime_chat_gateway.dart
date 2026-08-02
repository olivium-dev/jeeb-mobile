import 'dart:async';
import 'dart:typed_data';

import '../../client_offers/domain/offers_repository.dart' show OfferAcceptResult;
import '../domain/chat_gateway.dart';
import '../domain/chat_realtime_source.dart';
import '../domain/delivery_chat_message.dart';

class RealtimeChatGateway implements ChatGateway {
  RealtimeChatGateway({
    required ChatGateway inner,
    required ChatRealtimeSource realtime,
  })  : _inner = inner,
        _realtime = realtime;

  final ChatGateway _inner;
  final ChatRealtimeSource _realtime;

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _MergedChatEvents(
        <Stream<ChatEvent> Function()>[
          () => _realtime.subscribe(conversationId),
          () => _inner.subscribe(conversationId),
        ],
      ).stream;

  @override
  bool get supportsPolling => _inner.supportsPolling;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) =>
      _inner.loadHistory(conversationId);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) =>
      _inner.loadPhase(conversationId);

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) =>
      _inner.send(conversationId, message);

  @override
  Future<OfferAcceptResult> acceptOffer(String conversationId, String offerId) =>
      _inner.acceptOffer(conversationId, offerId);

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) =>
      _inner.uploadVoice(
        idempotencyKey: idempotencyKey,
        audioBytes: audioBytes,
        mimeType: mimeType,
        durationMs: durationMs,
      );

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      _inner.uploadImage(bytes: bytes, contentType: contentType);

  @override
  Future<Uint8List> fetchImageBytes(String objectRef) =>
      _inner.fetchImageBytes(objectRef);

  Future<void> dispose() => _realtime.dispose();
}

class _MergedChatEvents {
  _MergedChatEvents(this._legs) {
    _out = StreamController<ChatEvent>(onListen: _open, onCancel: _cancelLegs);
  }

  final List<Stream<ChatEvent> Function()> _legs;
  final List<StreamSubscription<ChatEvent>> _subscriptions =
      <StreamSubscription<ChatEvent>>[];

  late final StreamController<ChatEvent> _out;

  int _openLegs = 0;

  Stream<ChatEvent> get stream => _out.stream;

  void _open() {
    _openLegs = _legs.length;
    for (final leg in _legs) {
      _subscriptions.add(
        leg().listen(
          _forward,
          onError: _forwardError,
          onDone: _legDone,
          cancelOnError: false,
        ),
      );
    }
  }

  void _forward(ChatEvent event) {
    if (!_out.isClosed) _out.add(event);
  }

  void _forwardError(Object error, StackTrace stackTrace) {
    if (!_out.isClosed) _out.addError(error, stackTrace);
  }

  void _legDone() {
    _openLegs -= 1;
    if (_openLegs <= 0 && !_out.isClosed) unawaited(_out.close());
  }

  Future<void> _cancelLegs() async {
    final legs = List<StreamSubscription<ChatEvent>>.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(legs.map((leg) => leg.cancel()));
  }
}

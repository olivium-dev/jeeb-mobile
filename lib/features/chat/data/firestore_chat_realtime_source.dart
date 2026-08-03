import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/chat_firebase_identity.dart';
import '../domain/chat_gateway.dart';
import '../domain/chat_realtime_source.dart';
import 'firestore_chat_message_mapper.dart';

class FirestoreChatRealtimeSource implements ChatRealtimeSource {
  FirestoreChatRealtimeSource({
    required FirebaseFirestore Function() firestore,
    required ChatFirebaseIdentity identity,
    required FirestoreChatMessageMapper mapper,
    int window = kChatRealtimeWindow,
  })  : _firestore = firestore,
        _identity = identity,
        _window = window,
        _projector = ChatRealtimeProjector(mapRow: mapper.map);

  final FirebaseFirestore Function() _firestore;
  final ChatFirebaseIdentity _identity;
  final ChatRealtimeProjector _projector;
  final int _window;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _snapshots;
  StreamController<ChatEvent>? _events;

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    final events = StreamController<ChatEvent>.broadcast(
      onCancel: () => unawaited(dispose()),
    );
    _events = events;
    unawaited(_open(conversationId, events));
    return events.stream;
  }

  Future<void> _open(
    String conversationId,
    StreamController<ChatEvent> events,
  ) async {
    final uid = await _identity.ensureSignedIn();
    if (uid == null || uid.isEmpty) {
      _emit(events, const RealtimeTransportChanged(
        live: false,
        reason: 'no_identity',
      ));
      Diag.event('chat_realtime_unavailable', <String, Object?>{
        'conversation_id': conversationId,
        'reason': 'no_identity',
      });
      return;
    }
    if (events.isClosed) return;

    _snapshots = _firestore()
        .collection(kConversationsCollection)
        .doc(conversationId)
        .collection(kMessagesSubcollection)
        .where(kChatMessageVisibleToField, arrayContains: uid)
        .orderBy(kChatMessageCreatedAtField, descending: true)
        .limit(_window)
        .snapshots()
        .listen(
          (snapshot) => _onSnapshot(conversationId, snapshot, events),
          onError: (Object error) => _onDead(
            conversationId,
            events,
            'stream_error',
            error: error,
          ),
          onDone: () => _onDead(conversationId, events, 'stream_closed'),
          cancelOnError: false,
        );
  }

  void _onSnapshot(
    String conversationId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    StreamController<ChatEvent> events,
  ) {
    if (!_live) {
      _live = true;
      _emit(events, const RealtimeTransportChanged(
        live: true,
        reason: 'first_snapshot',
      ));
      Diag.event('chat_realtime_live', <String, Object?>{
        'conversation_id': conversationId,
        'docs': snapshot.docs.length,
      });
    }
    final changes = <RealtimeDocChange>[];
    for (final change in snapshot.docChanges) {
      changes.add(RealtimeDocChange(
        id: change.doc.id,
        data: _normalise(change.doc.data() ?? const <String, dynamic>{}),
        removed: change.type == DocumentChangeType.removed,
      ));
    }
    for (final event in _projector.project(changes)) {
      _emit(events, event);
    }
  }

  void _onDead(
    String conversationId,
    StreamController<ChatEvent> events,
    String reason, {
    Object? error,
  }) {
    _live = false;
    _emit(events, RealtimeTransportChanged(live: false, reason: reason));
    Diag.event('chat_realtime_down', <String, Object?>{
      'conversation_id': conversationId,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    });
  }

  bool _live = false;

  void _emit(StreamController<ChatEvent> events, ChatEvent event) {
    if (events.isClosed) return;
    events.add(event);
  }

  static Map<String, Object?> _normalise(Map<String, dynamic> data) {
    final out = <String, Object?>{};
    for (final entry in data.entries) {
      final value = entry.value;
      out[entry.key] = value is Timestamp ? value.toDate() : value;
    }
    return out;
  }

  @override
  Future<void> dispose() async {
    _live = false;
    await _snapshots?.cancel();
    _snapshots = null;
    final events = _events;
    _events = null;
    if (events != null && !events.isClosed) await events.close();
  }
}

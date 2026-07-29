import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/chat_firebase_identity.dart';
import '../domain/chat_gateway.dart';
import '../domain/chat_realtime_source.dart';
import 'firestore_chat_message_mapper.dart';

/// The realtime chat transport: ONE Firestore `.snapshots()` listener per open
/// thread.
///
/// # This is a stream, not a poll
///
/// There is no [Timer] in this file, no interval, and no repeated request. The
/// listener is opened once; Firestore's channel stays open and the SERVER writes
/// each new document down it. That is the whole architecture the owner named —
/// *"the backend should only store in firestore and that will automatically
/// updated on the mobile"* — and it is why `armed-poll-inventory.py` reports
/// nothing here: a subscription that registers as a poll would be the wrong
/// thing built.
///
/// # Ported from
///
/// `rahmah-fe/lib/features/chat/presentation/screens/chat_screen.dart:259-270`:
///
/// ```dart
/// _firestore
///     .collection(channelsCollection)
///     .doc(widget.channelId)
///     .collection(messageCollection)
///     .orderBy(createdAt, descending: true)
///     .snapshots()
///     .listen((snapshot) { ... }, onError: (error) { ... });
/// ```
///
/// Same query shape, four deliberate differences, each stated so a reviewer can
/// disagree with it:
///
///  1. **Different collection, different project.** Rahmah reads
///     `Channels/{channelId}/Messages` in `alrahmah-d7a33`. Jeeb reads
///     `Conversations/{conversationId}/Messages` in **`jeeb-5a293`** — a
///     different root in a different Firebase project. Jeeb chat history was
///     once written into Rahmah's project and caused a live outage; the two must
///     never meet. This class takes its [FirebaseFirestore] from the default app,
///     which `google-services.json` pins to `jeeb-5a293` (both the release and
///     the `dev` flavor copy read `project_id: jeeb-5a293`).
///  2. **Filtered by durable visibility.** The message rule reads
///     `resource.data.VisibleTo`, so the LIST carries the matching
///     `arrayContains` filter for the exact uid established by
///     [ChatFirebaseIdentity]. Firestore otherwise refuses the unprovable query.
///  3. **Bounded.** Rahmah has no `.limit()`, so opening a thread re-reads its
///     entire history. This adds `.limit(kChatRealtimeWindow)` — see that
///     constant for the argument.
///  4. **`docChanges`, not `docs`.** Rahmah reads the whole window each snapshot
///     and re-derives the delta by hand (`_knownMessageIds` + `_areMapsEqual`).
///     `docChanges` is the SDK's own answer to the same question.
///
/// # Liveness (I-13)
///
/// `debugPositionStreamWired` returned `true` on a dead SSE stream because it was
/// set when the stream was ARMED and never cleared on the stream's own `onDone`.
/// So liveness here is emitted from the stream's lifecycle and nothing else:
/// [RealtimeTransportChanged] `live: true` only when a snapshot has actually
/// ARRIVED, and `live: false` on `onError`/`onDone`. Arming the listener emits
/// nothing.
class FirestoreChatRealtimeSource implements ChatRealtimeSource {
  FirestoreChatRealtimeSource({
    /// Resolved LAZILY, and deliberately: it is called only after the identity
    /// check has passed. That ordering is the security property — "no identity"
    /// must mean Firestore is never reached at all, not "Firestore is reached
    /// and the rules turn it away" — and making it a callback is what lets a
    /// test assert it by passing something that throws if touched.
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
    // NO IDENTITY, NO READ. This is the line that makes "the token mint does not
    // exist yet" degrade to "the HTTP path keeps running" instead of to "the app
    // reads a conversation collection unauthenticated". See
    // [ChatFirebaseIdentity] for why an unauthenticated read of this
    // subcollection is a competing-bid leak, not merely an unauthorised one.
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
        // Newest first + a window: the same ordering Rahmah subscribes with, so
        // `.limit()` keeps the MOST RECENT messages rather than the oldest.
        // `ChatCubit._ordered` re-sorts for render, so descending here costs
        // nothing on screen.
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
      // Emitted on ARRIVAL, never on arm — I-13.
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
      // The message, not the object: a Firestore `permission-denied` is the
      // single most likely failure while the security rules are unwritten, and
      // it must be legible in a device capture rather than inferred.
      if (error != null) 'error': error.toString(),
    });
  }

  bool _live = false;

  void _emit(StreamController<ChatEvent> events, ChatEvent event) {
    if (events.isClosed) return;
    events.add(event);
  }

  /// Flattens the SDK's own value types out of a document so everything
  /// downstream is plain Dart. Only [Timestamp] needs it today; doing it here is
  /// what keeps `FirestoreChatMessageMapper` (and its tests) free of
  /// `cloud_firestore`.
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

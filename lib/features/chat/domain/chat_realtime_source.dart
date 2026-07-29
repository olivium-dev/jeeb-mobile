import 'chat_gateway.dart';

/// Ordering field on a chat-service message document.
///
/// The chat-service writes `CreatedAt` (PascalCase — `BaseModel.CreatedAt`,
/// mapped by Firestore's native `[FirestoreData]` POCO mapper, so the document
/// field name IS the property name). The HTTP projection renames it to
/// `created_at`; the document does not.
const String kChatMessageCreatedAtField = 'CreatedAt';

/// Additive per-viewer array on each message document.
///
/// Chat-service writes `VisibleTo` at message-write time, computed with
/// `MessageVisibilityResolver` — the same resolver used by the REST projection.
/// It makes that per-viewer visibility matrix durable on the message instead of
/// asking the client or the rule to recompute it.
///
/// The Firestore LIST must filter on this field because the security rule reads
/// `resource.data`, and Firestore refuses a query it cannot prove is authorised.
/// Legacy documents written before chat-service ships `VisibleTo` have no such
/// field, so `arrayContains` excludes them. The listener is a live-tail while
/// the cold thread still arrives over the existing HTTP history read; the
/// exclusion therefore costs only history that was already fetched, never a
/// missing live message.
///
/// This query requires a composite index with collection `Messages`, scope
/// COLLECTION (not COLLECTION_GROUP), and fields `VisibleTo` with arrayConfig
/// CONTAINS plus `CreatedAt` ordered DESCENDING. Without it the query fails with
/// FAILED_PRECONDITION at runtime.
const String kChatMessageVisibleToField = 'VisibleTo';

/// Top-level collection the chat-service writes Jeeb conversations into
/// (`FirestoreConversationStore.ConversationsCollection`).
const String kConversationsCollection = 'Conversations';

/// Per-conversation message subcollection
/// (`FirestoreConversationStore.MessagesSubcollection`).
const String kMessagesSubcollection = 'Messages';

/// How many of the most recent messages the realtime listener holds open.
///
/// **Rahmah does not bound its listener** — `chat_screen.dart:264-269` has no
/// `.limit()`, so a long thread re-reads every document on the first snapshot
/// and holds them all in memory. That is the one place this client deliberately
/// does NOT copy Rahmah: an unbounded listener makes the cold cost of opening a
/// thread proportional to its whole history, which is exactly the wire cost this
/// work exists to remove. The HTTP history read
/// (`GET /v1/conversations/{id}/messages`) still supplies the full thread on
/// mount, so the window only has to cover what can arrive DURING a session.
///
/// 50 is well above any realistic single-session burst on a delivery thread and
/// is a bounded, predictable first-snapshot cost.
const int kChatRealtimeWindow = 50;

/// One document-level change in a realtime snapshot, in a shape that carries no
/// `cloud_firestore` types.
///
/// This is what makes the projection testable without a Firebase app: the
/// adapter that touches `cloud_firestore` is a dozen lines and does nothing but
/// build these, and every decoding/dedup/ordering decision lives in
/// [ChatRealtimeProjector], which takes plain maps.
class RealtimeDocChange {
  const RealtimeDocChange({
    required this.id,
    required this.data,
    this.removed = false,
  });

  /// Document id. This is the chat-service's `Guid` (the store writes with
  /// `.Document(message.Guid).SetAsync(...)`), so it is the SAME id the HTTP
  /// projection returns as `message_id` — which is what lets the cubit's
  /// id-dedupe collapse a stream row and a history row into one bubble.
  final String id;

  /// Raw document fields, PascalCase as the chat-service wrote them.
  final Map<String, Object?> data;

  /// True for a `DocumentChangeType.removed`. Jeeb's message subcollection is
  /// append-only (there is no delete path in `FirestoreConversationStore`), so
  /// this is expected to stay false; it is modelled rather than ignored so a
  /// removal can never be decoded as an arrival.
  final bool removed;
}

/// Turns raw realtime document changes into [ChatEvent]s.
///
/// Ported from the Rahmah listener body
/// (`rahmah-fe/lib/features/chat/presentation/screens/chat_screen.dart:259-380`)
/// with two deliberate differences, both stated so a reader can check them:
///
///  1. **Rahmah diffs by hand.** It keeps a `_knownMessageIds` set (`:262`) and
///     an `_areMapsEqual` field-by-field comparison (`:380-390`) to work out
///     which of the documents in each snapshot are new or changed — because it
///     reads `snapshot.docs`, i.e. the WHOLE window, every time. This client
///     reads `snapshot.docChanges` instead, which is Firestore's own answer to
///     the same question and is `added`/`modified`/`removed` per document. Same
///     semantics, computed by the SDK rather than re-derived.
///  2. **Rahmah renders straight into `setState`.** This client emits
///     [IncomingMessage] into the existing `ChatGateway.subscribe` stream, so
///     the rows land in `ChatCubit._handleEvent` and go through the SAME
///     id-dedupe and own-echo reconciliation the socket path already had. That
///     matters: without it, the user's own message would appear twice — once as
///     the optimistic bubble, once as the server document.
class ChatRealtimeProjector {
  ChatRealtimeProjector({required this.mapRow});

  /// Maps one raw document (id + PascalCase fields) to a decoded message, or
  /// null when the document cannot be rendered. Injected rather than hard-wired
  /// so the projector stays free of both `cloud_firestore` and the codec.
  final ChatEvent? Function(RealtimeDocChange change) mapRow;

  /// Events for one snapshot batch, in document order.
  ///
  /// Malformed documents are SKIPPED, never fatal: one unrenderable row must not
  /// tear down the listener and take the whole thread's realtime with it. That
  /// is the same rule `_decodeHistory` applies on the HTTP path.
  List<ChatEvent> project(Iterable<RealtimeDocChange> changes) {
    final events = <ChatEvent>[];
    for (final change in changes) {
      if (change.removed) continue;
      final event = mapRow(change);
      if (event != null) events.add(event);
    }
    return events;
  }
}

/// A realtime message channel for ONE conversation.
///
/// The contract is deliberately narrow: open a channel, get messages pushed
/// down it. There is no `fetch`, no `poll`, no `refresh` — a source that needed
/// one would not be a realtime source.
abstract class ChatRealtimeSource {
  /// Opens the channel for [conversationId].
  ///
  /// The returned stream carries [IncomingMessage] for each document that
  /// arrives and [RealtimeTransportChanged] for the channel's own liveness. It
  /// is the caller's job to cancel the subscription; [dispose] releases anything
  /// the source itself holds.
  Stream<ChatEvent> subscribe(String conversationId);

  Future<void> dispose();
}

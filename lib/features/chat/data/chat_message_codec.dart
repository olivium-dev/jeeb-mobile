import '../domain/delivery_chat_message.dart';

/// Message kinds this build knows how to render. A row carrying anything else
/// is counted malformed rather than guessed at.
///
/// Moved here from `DioChatGateway` when the Firestore realtime transport
/// landed, so BOTH transports validate against the same set. Two copies of this
/// set is how one transport silently starts dropping a kind the other renders.
const Set<String> kSupportedMessageKinds = <String>{
  'text',
  'photo',
  'voice',
  'image',
  'location',
  'system',
  'offer',
  'offer_card',
  'offer_accepted',
  'offer_rejected',
};

/// THE decoder that turns a chat-service message row into a
/// [DeliveryChatMessage] — for every transport.
///
/// ## Why this is a separate class
///
/// It used to be three private methods on [DioChatGateway]
/// (`_parseMessage` / `_sentAtOf` / `_buildMessage`). The Firestore realtime
/// transport needs the identical mapping — same kind switch, same
/// `hasServerTimestamp` rule, same own-vs-counterpart derivation — and a second
/// copy of a nine-branch switch is a drift generator: the HTTP path already
/// carries four separate historical bug fixes in that switch (the `photo`
/// husk, the `0001-01-01` timestamp husk, the string-vs-map `body`, the
/// snake_case/camelCase tolerance), and a divergent copy would have to
/// re-discover every one of them.
///
/// So the body below is UNCHANGED from the version that shipped on the HTTP
/// path; only its address moved. [DioChatGateway] delegates to it.
///
/// ## The wire shape it consumes
///
/// A flat map with (tolerating every historical alias):
///   * `message_id` / `id`              — message identity, required
///   * `author_id` / `senderId`         — author identity, required
///   * `kind`                           — one of [kSupportedMessageKinds]
///   * `body` (string OR map) / `payload` (map) — content
///   * `created_at` / `createdAt` / `sent_at` / `sentAt` — ISO-8601 send time
///
/// The Firestore transport normalises its PascalCase document into exactly this
/// shape before calling [parse] (see `FirestoreChatMessageMapper`), so there is
/// one decoder and one validation rule, not two.
class ChatMessageCodec {
  const ChatMessageCodec(this.currentUserId);

  /// Id of the local user, used to derive [ChatAuthor.me] vs [ChatAuthor.them].
  final String currentUserId;

  /// Whether [row] carries enough to render. Identity fields (id, author, kind,
  /// content) are required; a TIMESTAMP IS NOT — see the note below.
  static bool isValidRow(Map<String, dynamic> row) {
    final id = row['message_id'] ?? row['id'];
    if (id is! String || id.trim().isEmpty) return false;

    final senderId = row['author_id'] ?? row['senderId'];
    if (senderId is! String || senderId.trim().isEmpty) return false;

    // THE BILATERAL EMPTY-THREAD DEFECT (fixed before this move): this used to
    // reject any row whose timestamp was absent or unparseable —
    //   `if (rawTimestamp is! String) return false;`
    // The gateway's message projection carries no timestamp at all, so the
    // check rejected 100% of rows on every read, for both participants. `GET
    // /v1/conversations/{id}/messages` answered 200 with the whole thread and
    // the client decoded ZERO messages from it.
    //
    // A timestamp is NOT identity: a message with an unknown send time is still
    // a message and must render. Rows are no longer rejected on timestamp
    // grounds at all — [sentAtOf] returns null for a missing/garbage/husk
    // (`0001-01-01`) value and the caller anchors ordering on the row's server
    // position instead.

    final kind = row['kind'];
    if (kind is! String || !kSupportedMessageKinds.contains(kind)) return false;

    final rawBody = row['body'] ?? row['payload'];
    if (rawBody is! Map && rawBody is! String) return false;
    return true;
  }

  DeliveryChatMessage parse(
    Map<String, dynamic> json, {
    DateTime? fallbackSentAt,
  }) {
    // FROZEN `JeebMessageResponse` uses snake_case (`message_id`, `author_id`)
    // and a string `body` for text — DISTINCT from the camelCase the client
    // originally assumed. Tolerate BOTH wire shapes so messages render whether
    // the gateway emits snake_case (live) or the legacy camelCase (mock/socket).
    final id =
        (json['message_id'] as String?) ?? (json['id'] as String?) ?? '';
    final senderId =
        (json['author_id'] as String?) ?? (json['senderId'] as String?) ?? '';
    final author = senderId == currentUserId ? ChatAuthor.me : ChatAuthor.them;
    final wireSentAt = sentAtOf(json);
    final sentAt = wireSentAt ?? fallbackSentAt ?? DateTime.now();
    // Falling back to [fallbackSentAt] means using an ORDERING ANCHOR, so the
    // message must not render a clock. Falling back to the local clock (the
    // live-stream path, which passes no anchor) stays honest: a frame that just
    // crossed the wire was sent at ~now, to within the transport latency.
    final hasServerTimestamp = wireSentAt != null || fallbackSentAt == null;
    final kind = MessageKind.fromWire(json['kind'] as String?);
    // `body` is a plain string for text (frozen contract); structured payloads
    // arrive under `payload` (or a legacy map `body`). Normalize to the map the
    // builder consumes.
    final rawBody = json['body'] ?? json['payload'];
    final Map<String, Object?> body;
    if (rawBody is Map) {
      body = rawBody.cast<String, Object?>();
    } else if (rawBody is String) {
      body = <String, Object?>{'text': rawBody};
    } else {
      body = const <String, Object?>{};
    }
    return build(
      id: id,
      author: author,
      sentAt: sentAt,
      hasServerTimestamp: hasServerTimestamp,
      kind: kind,
      body: body,
    );
  }

  /// Real send time carried by a wire row, or null when the row has none the
  /// client can use. Tolerates all four historical aliases. `0001-01-01` (the
  /// .NET `default(DateTime)` husk) is treated as ABSENT, not as a date — it is
  /// a serializer artefact, never a send time.
  static DateTime? sentAtOf(Map<String, dynamic> json) {
    final raw = json['createdAt'] ??
        json['created_at'] ??
        json['sentAt'] ??
        json['sent_at'];
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || parsed.year <= 1) return null;
    return parsed.toLocal();
  }

  DeliveryChatMessage build({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required bool hasServerTimestamp,
    required MessageKind kind,
    required Map<String, Object?> body,
  }) {
    const status = MessageStatus.delivered;
    switch (kind) {
      case MessageKind.text:
        return DeliveryChatMessage.text(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          text: body['text'] as String? ?? '',
        );
      case MessageKind.image:
        return DeliveryChatMessage.image(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          url: body['url'] as String? ?? '',
          caption: body['caption'] as String? ?? '',
        );
      case MessageKind.voice:
        return DeliveryChatMessage.voice(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          url: body['url'] as String? ?? '',
          durationMs: body['durationMs'] as int? ?? 0,
        );
      case MessageKind.location:
        final lat = body['lat'];
        final lng = body['lng'];
        return DeliveryChatMessage.location(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          lat: lat is num ? lat.toDouble() : 0,
          lng: lng is num ? lng.toDouble() : 0,
          label: body['label'] as String? ?? '',
        );
      case MessageKind.system:
        return DeliveryChatMessage.system(
          id: id,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          text: body['text'] as String? ?? '',
        );
      case MessageKind.offerCard:
        return DeliveryChatMessage.offerCard(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          payload: OfferCardPayload.fromWire(body),
        );
      case MessageKind.offerAccepted:
        return DeliveryChatMessage.offerAccepted(
          id: id,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          payload: SystemOfferPayload.fromWire(body),
        );
      case MessageKind.offerRejected:
        return DeliveryChatMessage.offerRejected(
          id: id,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          payload: SystemOfferPayload.fromWire(body),
        );
      case MessageKind.photo:
        // A `photo` row on the wire can only come from the PRE-FIX build,
        // which posted `{caption:''}` with no bytes and no url. Decoding it as
        // a text bubble made it an INVISIBLE empty bubble. Surface it as an
        // `image` with an empty url so the bubble renders the "unavailable"
        // placeholder instead — the messages the broken build persisted stay
        // visible as something.
        return DeliveryChatMessage.image(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          url: '',
          caption: body['caption'] as String? ?? '',
        );
    }
  }
}

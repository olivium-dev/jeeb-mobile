import 'package:equatable/equatable.dart';

/// Coarse status surfaced on the client home card. Mirrors the visible
/// states a sender cares about between "I just submitted" and "the driver
/// is at my door". Finer-grained server states (pending vs queued,
/// dispatched vs assigned) collapse into these for the home summary.
enum ClientRequestStatus {
  /// We're still looking for a Jeeber.
  searching,

  /// Offers have come back and the sender is choosing.
  offersReceived,

  /// A Jeeber accepted; nothing on the road yet.
  accepted,

  /// Jeeber is at the pickup point.
  atPickup,

  /// Jeeber is heading toward the drop-off.
  enRoute,

  /// Terminal: the delivery completed (V3 `Done`). The order is delivered;
  /// nothing is left to track. Core Flow step 7 — the correct delivered/
  /// completed final state, NOT "accepted"/in-progress.
  delivered,

  /// Terminal: the request was cancelled or expired before completion. Like
  /// [delivered] it is history — it must never linger in In Progress, nor read
  /// as "searching" (which would falsely re-open a dead auction).
  cancelled,
}

/// Tier badge the card renders (Flash red / Express orange / Standard blue).
/// `unknown` falls back to a neutral chip so the screen never crashes when
/// the backend introduces a new tier mid-deploy.
enum ClientRequestTier { flash, express, standard, unknown;

  static ClientRequestTier parse(String? raw) {
    switch (raw) {
      case 'flash':
        return ClientRequestTier.flash;
      case 'express':
        return ClientRequestTier.express;
      case 'standard':
        return ClientRequestTier.standard;
      default:
        return ClientRequestTier.unknown;
    }
  }
}

/// A single active delivery request to render as a card on the home tab.
///
/// Used by all three home tabs:
///   - **In Progress** — [progressStep] drives the Ordered → Picked →
///     In Transit indicator; [jeeberName] + [tier] populate the row.
///   - **Pending Requests** — only [id], [title], [tier] are set.
///   - **Replies** — [offerCount] + [offerAvatarUrls] feed the avatar stack
///     and "+N" badge; [conversationId] is the deep-link target for
///     "Check Offers".
class ClientHomeRequest extends Equatable {
  const ClientHomeRequest({
    required this.id,
    required this.title,
    required this.status,
    required this.destinationLabel,
    this.itemsSummary,
    this.etaMinutes,
    this.jeeberName,
    this.tier = ClientRequestTier.unknown,
    this.progressStep = 0,
    this.offerCount = 0,
    this.offerAvatarUrls = const <String>[],
    this.conversationId,
    this.displayId,
    this.ttlSeconds,
    this.deliveryId,
    this.chatCorrelationId,
  });

  /// Server-side identifier; also used as the deep-link key.
  ///
  /// For In-Progress cards this is the parent REQUEST/order id — NOT the
  /// delivery row id. The delivery the accept created is keyed separately
  /// (`delivery-<offerId>`); see [deliveryId].
  final String id;

  /// The server-created delivery row id (`delivery-<offerId>`) for an
  /// accepted/in-progress order, when the list endpoint surfaces it.
  ///
  /// S9 live-tracking fix: the live-tracking surface reads
  /// `GET /v1/delivery/<deliveryId>`, which 404s on a request id. The
  /// In-Progress "Track my order" CTA must navigate with THIS id, not [id].
  /// Null when the gateway list item does not carry a distinct delivery id;
  /// callers then fall back to [id] via [trackingId] (correct only when the
  /// list endpoint already keys items on the delivery id).
  final String? deliveryId;

  /// The id the live-tracking surface (`/orders/:id/tracking`,
  /// `GET /v1/delivery/<id>`) must be opened with: the server delivery id when
  /// known, else the request id as a best-effort fallback.
  String get trackingId =>
      (deliveryId != null && deliveryId!.isNotEmpty) ? deliveryId! : id;

  /// The parent REQUEST/order id this card's chat thread is keyed on.
  ///
  /// S13 Defect 1: for an In-Progress *delivery* row [id] is the delivery id
  /// (`delivery-<offerId>`), but the order's conversation is correlated on the
  /// parent request id (the chat-detail create-or-get uses the route id as the
  /// conversation CORRELATION KEY). Opening chat with the delivery id mints a
  /// fresh empty conversation instead of the order's existing thread. The
  /// gateway active-list item carries the parent id under `requestId`/
  /// `request_id`; we capture it here so the "Open chat" CTA routes to the
  /// correct existing thread. Null when the row genuinely lacks one (then
  /// callers fall back to [id] via [chatThreadId]).
  final String? chatCorrelationId;

  /// The id the order-chat surface (`/chat/:id`, `chat-detail`) must be opened
  /// with: the parent request/correlation id when known, else [id] as a
  /// best-effort fallback (preserves the pre-S13 behavior for rows that carry
  /// no distinct parent id).
  String get chatThreadId =>
      (chatCorrelationId != null && chatCorrelationId!.isNotEmpty)
          ? chatCorrelationId!
          : id;

  /// Human-readable order id (e.g. `ORD-23748`) used in the chat header /
  /// Replies card title. Falls back to [id] when the server omits it.
  final String? displayId;

  /// Short description the sender typed/spoke (e.g. "Pharmacy → Ashrafieh").
  final String title;

  /// Where the package is going. Display-only.
  final String destinationLabel;

  /// Comma-joined item names the sender requested (e.g.
  /// "1 kilo potato, water gallon, coffee blend"). Rendered as the card
  /// subtitle on every My Orders tab. Falls back to [destinationLabel] when
  /// the backend omits an items list.
  final String? itemsSummary;

  /// The subtitle line every order card renders — items summary when present,
  /// otherwise the destination.
  ///
  /// G1: `itemsSummary` now carries the request `description` (the customer's
  /// own "What do you need?" text). Cards render `displayId ?? title` as their
  /// header, so when the summary would repeat the exact same string the
  /// header already shows (no displayId + title==description), fall back to
  /// the destination instead of echoing it twice.
  String get summaryLine {
    final items = itemsSummary;
    if (items != null && items.isNotEmpty) {
      final header = displayId ?? title;
      if (items != header) return items;
    }
    return destinationLabel;
  }

  /// Current coarse status.
  final ClientRequestStatus status;

  /// Tier badge color (Flash / Express / Standard).
  final ClientRequestTier tier;

  /// Progress through the SM-1 happy-path: 0=Ordered, 1=Picked, 2=InTransit,
  /// 3=AtDoor/Done. The progress bar fills proportionally.
  final int progressStep;

  /// Minutes left on the live ETA, when known. `null` once the request is
  /// merely searching/offered (no driver yet).
  final int? etaMinutes;

  /// Name of the assigned Jeeber once one accepts. `null` while
  /// [ClientRequestStatus.searching] or [ClientRequestStatus.offersReceived].
  final String? jeeberName;

  /// Remaining seconds before the pending request expires, as returned by the
  /// server at fetch time. The UI drives a local countdown from this snapshot.
  /// `null` for requests that are not pending.
  final int? ttlSeconds;

  /// Number of offers received so far (Replies tab only).
  final int offerCount;

  /// Avatar URLs for the first few offerers — the Replies card renders these
  /// as a stacked row with a "+N" badge when more exist.
  final List<String> offerAvatarUrls;

  /// Conversation backing this request, if any. Set on Replies rows; the
  /// `Check Offers` CTA navigates to `/chat/{conversationId}`.
  final String? conversationId;

  ClientHomeRequest copyWith({
    String? id,
    String? title,
    ClientRequestStatus? status,
    String? destinationLabel,
    Object? itemsSummary = _sentinel,
    Object? etaMinutes = _sentinel,
    Object? jeeberName = _sentinel,
    ClientRequestTier? tier,
    int? progressStep,
    int? offerCount,
    List<String>? offerAvatarUrls,
    Object? conversationId = _sentinel,
    Object? displayId = _sentinel,
    Object? ttlSeconds = _sentinel,
    Object? deliveryId = _sentinel,
    Object? chatCorrelationId = _sentinel,
  }) {
    return ClientHomeRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      itemsSummary: identical(itemsSummary, _sentinel)
          ? this.itemsSummary
          : itemsSummary as String?,
      etaMinutes: identical(etaMinutes, _sentinel)
          ? this.etaMinutes
          : etaMinutes as int?,
      jeeberName: identical(jeeberName, _sentinel)
          ? this.jeeberName
          : jeeberName as String?,
      tier: tier ?? this.tier,
      progressStep: progressStep ?? this.progressStep,
      offerCount: offerCount ?? this.offerCount,
      offerAvatarUrls: offerAvatarUrls ?? this.offerAvatarUrls,
      conversationId: identical(conversationId, _sentinel)
          ? this.conversationId
          : conversationId as String?,
      displayId: identical(displayId, _sentinel)
          ? this.displayId
          : displayId as String?,
      ttlSeconds: identical(ttlSeconds, _sentinel)
          ? this.ttlSeconds
          : ttlSeconds as int?,
      deliveryId: identical(deliveryId, _sentinel)
          ? this.deliveryId
          : deliveryId as String?,
      chatCorrelationId: identical(chatCorrelationId, _sentinel)
          ? this.chatCorrelationId
          : chatCorrelationId as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        displayId,
        title,
        destinationLabel,
        itemsSummary,
        status,
        tier,
        progressStep,
        etaMinutes,
        jeeberName,
        offerCount,
        offerAvatarUrls,
        conversationId,
        ttlSeconds,
        deliveryId,
        chatCorrelationId,
      ];
}

const Object _sentinel = Object();

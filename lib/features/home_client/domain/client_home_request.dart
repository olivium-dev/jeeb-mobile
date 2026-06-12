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
  });

  /// Server-side identifier; also used as the deep-link key.
  final String id;

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
  String get summaryLine =>
      (itemsSummary != null && itemsSummary!.isNotEmpty)
          ? itemsSummary!
          : destinationLabel;

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
      ];
}

const Object _sentinel = Object();

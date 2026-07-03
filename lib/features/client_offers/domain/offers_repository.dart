import 'offer.dart';

/// Classified failure surfaces the cubit translates into copy. Mirrors the
/// gateway's error envelope so the UI never has to introspect raw Dio types.
enum OffersFailure {
  network,
  requestNotOpen,
  offerNotPending,
  unknown,
}

/// Outcome of accepting an offer.
///
/// The offer-accept saga creates the delivery server-side; the [deliveryId]
/// it returns is the id the client uses to reach live tracking
/// (`/orders/<deliveryId>/tracking`). It is **nullable on purpose**: the
/// mock's pre-golden accept response did not carry a delivery id, and a
/// degraded/legacy gateway may still omit it. Callers MUST treat a null
/// [deliveryId] as "tracking not yet reachable" rather than crashing — the
/// "Track order" CTA simply stays hidden in that case.
///
/// [conversationId] is the 1:1 order-chat conversation the saga promotes the
/// winning Jeeber into (the mock's `POST /v1/offers/:offerId/accept` returns
/// `conversationId` + `conversationPhase=accepted`). The accept-confirm sheet
/// (JM-029) navigates to `order-chat` (`/chat/<conversationId>`) on confirm so
/// the pinned summary (D11/D71) renders. Also nullable: a legacy/in-memory
/// gateway may omit it, in which case the caller falls back to the
/// request/delivery id (`ChatDetailScreen` resolves either by `by-request`).
class OfferAcceptResult {
  const OfferAcceptResult({
    this.deliveryId,
    this.conversationId,
    this.handoverCode,
  });

  /// Server-created delivery id, or null when the accept response did not
  /// surface one. Never an empty string — parsers normalise `''` to null.
  final String? deliveryId;

  /// The accepted order's 1:1 conversation id, or null when the accept
  /// response did not surface one. Never an empty string — parsers normalise
  /// `''` to null. Drives the JM-029 confirm → order-chat navigation.
  final String? conversationId;

  /// G4 (sprint-009): the delivery hand-over code the accept saga mints
  /// (`POST /v1/offers/:offerId/accept` → `{ offer, handoverCode,
  /// conversationId, … }`). This is the ONLY wire moment the customer's app is
  /// given the code — the `GET /deliveries/{id}/otp` fallback is an SMS
  /// trigger that returns no code — so parsers MUST retain it (the pre-fix
  /// `_parseAcceptResult` discarded it, leaving the customer with nothing to
  /// show at the door). Null when the gateway omits it. Never an empty string.
  /// NEVER log this value — `DiagRedaction` masks `handoverCode` keys.
  final String? handoverCode;

  /// Empty result — used by gateways that do not produce a delivery id
  /// (the MVP in-memory and dev-fixture gateways) and as the safe default
  /// when the wire body is malformed.
  static const OfferAcceptResult empty = OfferAcceptResult();
}

/// Snapshot of the open offer set for a single request.
///
/// [windowExpiresAt] is the server-stamped deadline after which the request
/// auto-cancels if nothing has been accepted (T-mobile-035 hard expiry). The
/// cubit drives a local countdown from this value — no clock skew correction,
/// the server is authoritative.
class OffersSnapshot {
  const OffersSnapshot({
    required this.offers,
    required this.windowExpiresAt,
    required this.requestIsOpen,
  });

  final List<Offer> offers;
  final DateTime windowExpiresAt;
  final bool requestIsOpen;
}

/// Read-side contract for the offer cards screen. Implementations call the
/// gateway in production and an in-memory fake during tests.
abstract class OffersRepository {
  /// Pulls the current open offers + window deadline for [requestId].
  Future<OffersSnapshot> fetchOffers(String requestId);

  /// Accepts a single offer. Returns an [OfferAcceptResult] carrying the
  /// server-created [OfferAcceptResult.deliveryId] (may be null when the
  /// gateway does not surface one); throws an [OffersRepositoryException]
  /// tagged with the canonical [OffersFailure] on failure.
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  });
}

/// Typed exception the repository raises so the cubit can map cleanly without
/// peeking at the underlying transport.
class OffersRepositoryException implements Exception {
  const OffersRepositoryException(this.failure, [this.message]);
  final OffersFailure failure;
  final String? message;

  @override
  String toString() => 'OffersRepositoryException($failure, $message)';
}

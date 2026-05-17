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

/// A single active delivery request to render as a card on the home tab.
class ClientHomeRequest extends Equatable {
  const ClientHomeRequest({
    required this.id,
    required this.title,
    required this.status,
    required this.destinationLabel,
    this.etaMinutes,
    this.jeeberName,
  });

  /// Server-side identifier; also used as the deep-link key.
  final String id;

  /// Short description the sender typed/spoke (e.g. "Pharmacy → Ashrafieh").
  final String title;

  /// Where the package is going. Display-only.
  final String destinationLabel;

  /// Current coarse status.
  final ClientRequestStatus status;

  /// Minutes left on the live ETA, when known. `null` once the request is
  /// merely searching/offered (no driver yet).
  final int? etaMinutes;

  /// Name of the assigned Jeeber once one accepts. `null` while
  /// [ClientRequestStatus.searching] or [ClientRequestStatus.offersReceived].
  final String? jeeberName;

  @override
  List<Object?> get props => [
        id,
        title,
        destinationLabel,
        status,
        etaMinutes,
        jeeberName,
      ];
}

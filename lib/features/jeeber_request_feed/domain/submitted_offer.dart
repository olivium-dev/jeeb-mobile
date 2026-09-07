import 'package:equatable/equatable.dart';

enum OfferStatus {

  submitted,

  accepted,

  lost;

  static OfferStatus fromWire(String? raw) {
    switch (raw?.toLowerCase().replaceAll('_', '')) {
      case 'accepted':
      case 'accept':
        return OfferStatus.accepted;
      case 'lost':
      case 'rejected':
      case 'declined':
      case 'notselected':
        return OfferStatus.lost;
      case 'submitted':
      case 'pending':
      case 'open':
      case 'live':
      default:
        return OfferStatus.submitted;
    }
  }

  bool get isTerminal => this != OfferStatus.submitted;
}

class SubmittedOffer extends Equatable {
  const SubmittedOffer({
    required this.id,
    required this.requestId,
    required this.price,
    required this.currency,
    this.currencyKnown = true,
    this.etaMinutes,
    this.note,
    this.status = OfferStatus.submitted,
  });

  final String id;

  final String requestId;

  final double price;

  final String currency;

  /// False when the envelope named no currency: [currency] is then a
  /// formatting placeholder the UI must not present as a real unit.
  final bool currencyKnown;

  final int? etaMinutes;

  final String? note;

  final OfferStatus status;

  SubmittedOffer copyWith({OfferStatus? status}) {
    return SubmittedOffer(
      id: id,
      requestId: requestId,
      price: price,
      currency: currency,
      currencyKnown: currencyKnown,
      etaMinutes: etaMinutes,
      note: note,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props =>
      [id, requestId, price, currency, currencyKnown, etaMinutes, note, status];
}

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
    this.etaMinutes,
    this.note,
    this.status = OfferStatus.submitted,
  });

  
  
  final String id;

  
  
  final String requestId;

  
  
  final double price;

  
  final String currency;

  
  final int? etaMinutes;

  
  final String? note;

  
  
  final OfferStatus status;

  
  
  
  SubmittedOffer copyWith({OfferStatus? status}) {
    return SubmittedOffer(
      id: id,
      requestId: requestId,
      price: price,
      currency: currency,
      etaMinutes: etaMinutes,
      note: note,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props =>
      [id, requestId, price, currency, etaMinutes, note, status];
}

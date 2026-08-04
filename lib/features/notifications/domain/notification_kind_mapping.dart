import 'notifications_repository.dart';

NotificationKind notificationKindFromWireType(String? wireType) {
  var type = wireType?.trim();
  if (type == null || type.isEmpty) return NotificationKind.unknown;

  if (type.toLowerCase().startsWith('jeeb.')) {
    type = type.substring('jeeb.'.length).trim();
  }

  switch (type) {
    case 'offer':
    case 'offer_received':
      return NotificationKind.offer;
    case 'offer_accepted':
    case 'offerAccepted':
      return NotificationKind.offerAccepted;
    case 'status':
    case 'order_status':
      return NotificationKind.status;
    case 'low_balance':
    case 'lowBalance':
      return NotificationKind.lowBalance;
    case 'fee_won':
    case 'feeWon':
      return NotificationKind.feeWon;
    case 'refund_penalty':
    case 'refundPenalty':
      return NotificationKind.refundPenalty;
    case 'topup':
      return NotificationKind.topup;
    case 'kyc_approved':
    case 'kycApproved':
      return NotificationKind.kycApproved;
    case 'kyc_rejected':
    case 'kycRejected':
      return NotificationKind.kycRejected;
    case 'request_expired':
    case 'requestExpired':
      return NotificationKind.requestExpired;
    case 'new_request':
    case 'newRequest':
      return NotificationKind.newRequest;
    case 'confirm_receipt':
    case 'confirmReceipt':
      return NotificationKind.confirmReceipt;
    case 'marketing':
      return NotificationKind.marketing;
    default:
      return NotificationKind.unknown;
  }
}

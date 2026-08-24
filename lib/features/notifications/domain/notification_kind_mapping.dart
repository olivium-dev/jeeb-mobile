import 'notifications_repository.dart';

NotificationKind notificationKindFromWireType(String? wireType) {
  var type = wireType?.trim().toLowerCase();
  if (type == null || type.isEmpty) return NotificationKind.unknown;

  if (type.startsWith('jeeb.')) {
    type = type.substring('jeeb.'.length).trim();
  }
  if (type.startsWith('dispute.')) return NotificationKind.dispute;
  if (type.startsWith('support.')) return NotificationKind.support;

  switch (type) {
    case 'offer':
    case 'offer_received':
      return NotificationKind.offer;
    case 'offer_accepted':
    case 'offeraccepted':
      return NotificationKind.offerAccepted;
    case 'status':
    case 'order_status':
      return NotificationKind.status;
    case 'low_balance':
    case 'lowbalance':
      return NotificationKind.lowBalance;
    case 'fee_won':
    case 'feewon':
      return NotificationKind.feeWon;
    case 'refund_penalty':
    case 'refundpenalty':
      return NotificationKind.refundPenalty;
    case 'topup':
      return NotificationKind.topup;
    case 'kyc_approved':
    case 'kycapproved':
      return NotificationKind.kycApproved;
    case 'kyc_rejected':
    case 'kycrejected':
      return NotificationKind.kycRejected;
    case 'request_expired':
    case 'requestexpired':
      return NotificationKind.requestExpired;
    case 'new_request':
    case 'newrequest':
      return NotificationKind.newRequest;
    case 'confirm_receipt':
    case 'confirmreceipt':
      return NotificationKind.confirmReceipt;
    case 'marketing':
      return NotificationKind.marketing;
    case 'dispute':
    case 'dispute_update':
    case 'dispute_updated':
    case 'dispute_resolved':
      return NotificationKind.dispute;
    case 'support':
    case 'support_reply':
    case 'support_update':
    case 'support_ticket_update':
      return NotificationKind.support;
    // CONTRACT §3 wallet-guard withdraw push (the `jeeb.` prefix is already
    // stripped above); the second slug is the notification-service variant.
    case 'offer_withdrawn_insufficient_balance':
    case 'wallet_insufficient_balance':
      return NotificationKind.offerWithdrawnInsufficientBalance;
    default:
      return NotificationKind.unknown;
  }
}

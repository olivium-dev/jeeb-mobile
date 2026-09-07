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
    case 'delivery':
    case 'delivery_status_updated':
    case 'cancellation_decision':
    case 'delivery_cancelled':
      return NotificationKind.status;
    case 'chat':
    case 'chat_message':
    case 'new_message':
      return NotificationKind.chat;
    case 'availability':
    case 'auto_offline':
      return NotificationKind.availability;
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
    case 'request.try_expand_tier':
    case 'request.expired':
    case 'try_expand_tier':
    case 'request_expiring':
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
    default:
      return NotificationKind.unknown;
  }
}

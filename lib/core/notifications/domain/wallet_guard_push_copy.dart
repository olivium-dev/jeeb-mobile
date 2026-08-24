/// Wire `type` of the guard-2 auto-withdraw push (CONTRACT §3, FROZEN).
const String kOfferWithdrawnInsufficientBalancePushType =
    'offer_withdrawn_insufficient_balance';

/// True for that push, with or without the upstream `jeeb.` event prefix;
/// anything else stays on the wire-verbatim path.
bool isWalletGuardWithdrawPush(String? wireType) {
  if (wireType == null) return false;
  final normalized = wireType.trim().toLowerCase();
  const prefix = 'jeeb.';
  final stripped = normalized.startsWith(prefix)
      ? normalized.substring(prefix.length)
      : normalized;
  return stripped == kOfferWithdrawnInsufficientBalancePushType;
}

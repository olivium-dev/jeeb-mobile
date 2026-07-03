/// PURE Dart domain entity for the customer confirm-receipt screen (JM-033,
/// blueprint `delivered-receipt-confirm`). No Flutter / Dio / GetIt imports.
///
/// This is the **customer-facing** receipt view: it carries ONLY what the
/// "Did you receive your order?" prompt needs — the cash amount the customer
/// pays the Jeeber in person (D11, cash-on-delivery), the Jeeber's name, and
/// the proof-of-delivery photo URL the Jeeber uploaded (D3). It deliberately
/// carries NO commission / platform-fee field: the customer never sees the
/// 10% economics (JM-033 AC4, D11). The fee lives on the jeeber/wallet
/// surfaces, not here.
class DeliveryReceipt {
  const DeliveryReceipt({
    required this.deliveryId,
    required this.jeeberName,
    required this.cashAmount,
    required this.currency,
    required this.status,
    this.jeeberId,
    this.proofPhotoUrl,
  });

  /// The delivery this receipt confirms. Path-param id from the route.
  final String deliveryId;

  /// Display name of the Jeeber the customer pays in cash. Empty string when
  /// the gateway did not surface a name (the copy then degrades to a generic
  /// "the Jeeber" rather than crashing).
  final String jeeberName;

  /// Server id of the Jeeber, forwarded on the cash-settlement record so the
  /// COD ledger attributes the cash to the right courier. Nullable — the
  /// record call omits it when absent (the mock defaults to `'unknown'`).
  final String? jeeberId;

  /// Cash the customer hands the Jeeber, in whole/decimal currency units
  /// (e.g. `9.0`). This is the gross order amount paid in person — NOT a fee.
  ///
  /// NULL when the gateway did not surface a usable amount (run-22 P1-A: the
  /// live `GET /v1/deliveries/{id}` drops the `amount` key once the delivery
  /// reaches `Done`). An absent amount is UNKNOWN — it must never be rendered
  /// as a fabricated `$0.00`; the screen degrades to amount-less copy instead.
  final double? cashAmount;

  /// True when the gateway surfaced a real, positive cash amount. Zero and
  /// negative wire values are treated as unknown too — the COD amount of a
  /// priced delivery is never actually 0, so a 0 here means enrichment broke.
  bool get hasKnownAmount => (cashAmount ?? 0) > 0;

  /// ISO currency code (e.g. `USD`). Drives the "Pay $N" copy formatting.
  final String currency;

  /// SM-1 delivery status (e.g. `AtDoor`). The receipt prompt is meaningful at
  /// the receipt-pending states (`AtDoor`); confirming transitions it to
  /// `Done`.
  final String status;

  /// URL of the proof-of-delivery photo the Jeeber uploaded (D3, D1m sink).
  /// Nullable — when null the screen shows a neutral placeholder instead of an
  /// image (a malformed/absent body must degrade, never crash).
  final String? proofPhotoUrl;

  /// True when the proof photo can be rendered (non-null, non-empty URL).
  bool get hasProofPhoto => (proofPhotoUrl ?? '').isNotEmpty;
}

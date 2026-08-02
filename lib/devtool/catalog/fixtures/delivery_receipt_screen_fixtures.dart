// Shared dev-only fixtures for `DeliveryReceiptScreen` (JM-033

import 'dart:async';

import 'package:jeeb_mobile/features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';

/// A read that never lands, holding the screen on
/// `DeliveryReceiptStatus.loading` for as long as the surface is open.
/// `load()` is fired from `BlocProvider.create` on the first build, so the
class DeliveryReceiptScreenPendingRepository
    implements DeliveryReceiptRepository {
  const DeliveryReceiptScreenPendingRepository();

  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) =>
      Completer<DeliveryReceipt>().future;

  /// Unreachable: the confirm CTA only exists inside the loaded body, and this
  /// repository never produces one. Loud rather than silent — a dev surface
  @override
  Future<void> confirmReceipt(DeliveryReceipt receipt) async =>
      throw UnsupportedError(
        'DeliveryReceiptScreenPendingRepository never loads a receipt, so '
        'nothing can confirm one. Reaching this means the screen grew a '
        'confirm path that does not require a loaded receipt.',
      );
}

/// The designed states, named once for both dev surfaces.
abstract final class DeliveryReceiptScreenFixtures {
  /// The delivery every state confirms. Matches the reference the Screen
  /// Catalog has used for this screen since it was written.
  static const String deliveryId = 'ORD-4821';

  /// The gateway dropped `amount` (run-22 P1-A): the live
  /// `GET /v1/deliveries/{id}` stops sending it once the delivery reaches
  static const DeliveryReceipt amountUnknownReceipt = DeliveryReceipt(
    deliveryId: deliveryId,
    jeeberName: 'Kamal Hajj',
    jeeberId: 'user-jeeber-002',
    cashAmount: null,
    currency: 'USD',
    status: 'Done',
    proofPhotoUrl: null,
  );

  /// The OTHER half of the run-22 P1-A guard: the amount arrived as `0`.
  /// `DeliveryReceipt.hasKnownAmount` treats zero and negative as unknown too —
  static const DeliveryReceipt amountZeroReceipt = DeliveryReceipt(
    deliveryId: deliveryId,
    jeeberName: 'Nour Chami',
    jeeberId: 'user-jeeber-004',
    cashAmount: 0,
    currency: 'USD',
    status: 'AtDoor',
    proofPhotoUrl: null,
  );

  /// The gateway surfaced no courier name. The copy degrades to the localized
  /// generic noun (`receiptJeeberFallback` — "the Jeeber" / "الجيبر") rather
  static const DeliveryReceipt noJeeberNameReceipt = DeliveryReceipt(
    deliveryId: deliveryId,
    jeeberName: '',
    jeeberId: 'user-jeeber-003',
    cashAmount: 9,
    currency: 'USD',
    status: 'AtDoor',
    proofPhotoUrl: null,
  );

  /// The layout ceiling for the cash-on-delivery row: the longest name a
  /// Lebanese account plausibly carries, plus a non-USD amount, which
  static const DeliveryReceipt longContentReceipt = DeliveryReceipt(
    deliveryId: deliveryId,
    jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi Al-Shami',
    jeeberId: 'user-jeeber-005',
    cashAmount: 1250000,
    currency: 'LBP',
    status: 'AtDoor',
    proofPhotoUrl: null,
  );

  /// A perfectly ordinary receipt whose CONFIRM is bound to be rejected — see
  /// [confirmRejected]. Distinct name and amount so it cannot be mistaken for
  static const DeliveryReceipt confirmRejectedReceipt = DeliveryReceipt(
    deliveryId: deliveryId,
    jeeberName: 'Rami Saab',
    jeeberId: 'user-jeeber-006',
    cashAmount: 42,
    currency: 'USD',
    status: 'AtDoor',
    proofPhotoUrl: null,
  );

  /// The happy path: `$9.00` owed to Kamal Hajj, with the proof-of-delivery
  /// photo the jeeber uploaded (D3).
  static DeliveryReceiptRepository loaded() => FakeDeliveryReceiptRepository();

  /// [amountUnknownReceipt], loaded successfully.
  static DeliveryReceiptRepository amountUnknown() =>
      FakeDeliveryReceiptRepository(receipt: amountUnknownReceipt);

  /// [amountZeroReceipt], loaded successfully.
  static DeliveryReceiptRepository amountZero() =>
      FakeDeliveryReceiptRepository(receipt: amountZeroReceipt);

  /// [noJeeberNameReceipt], loaded successfully.
  static DeliveryReceiptRepository noJeeberName() =>
      FakeDeliveryReceiptRepository(receipt: noJeeberNameReceipt);

  /// [longContentReceipt], loaded successfully.
  static DeliveryReceiptRepository longContent() =>
      FakeDeliveryReceiptRepository(receipt: longContentReceipt);

  /// Loads fine; `confirmReceipt` throws the 422 the mock returns when `Done`
  /// is not a legal transition from the delivery's current state.
  static DeliveryReceiptRepository confirmRejected() =>
      FakeDeliveryReceiptRepository(
        receipt: confirmRejectedReceipt,
        confirmFailure: DeliveryReceiptFailure.transitionNotAllowed,
      );

  /// The read is still in flight — the first frame of every receipt.
  static DeliveryReceiptRepository pending() =>
      const DeliveryReceiptScreenPendingRepository();

  /// 404: the delivery id resolved no receipt. There is nothing to confirm and
  /// `Retry` cannot fix it.
  static DeliveryReceiptRepository notFound() => FakeDeliveryReceiptRepository(
        fetchFailure: DeliveryReceiptFailure.notFound,
      );

  /// The read never reached the server. Retryable, and the fixture keeps
  /// failing, so `Retry` behaves the way it does on a dead connection.
  static DeliveryReceiptRepository networkDown() =>
      FakeDeliveryReceiptRepository(
        fetchFailure: DeliveryReceiptFailure.network,
      );
}

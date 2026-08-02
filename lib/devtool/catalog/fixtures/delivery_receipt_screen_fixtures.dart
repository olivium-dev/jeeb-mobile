// Shared dev-only fixtures for `DeliveryReceiptScreen` (JM-033
// `delivered-receipt-confirm`, the customer's "Did you receive your order?"
// prompt at `/orders/:id/receipt`).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_03_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart`.
//
// The catalog owned three inline states — the default fake, a hand-built
// `DeliveryReceipt` with a null amount, and a `fetchFailure` — built straight
// into the entry list. Copying those into the preview section would have given
// the two surfaces two independent notions of "the delivered receipt", free to
// drift the moment either is edited. Both surfaces now import this file; the
// three catalog states are [loaded], [amountUnknown] and [notFound], unchanged.
//
// ## Why every fixture is a FUNCTION, not a const
//
// `DeliveryReceiptScreen` resolves its repository once per mount and the cubit
// it builds calls `fetchReceipt` immediately, so a repository shared between
// two mounted states is shared MUTABLE state:
// `FakeDeliveryReceiptRepository.confirmed` is a plain field the confirm path
// flips. Each call below hands out a fresh instance, so a confirm tapped in one
// canvas card cannot be observed from another. The receipts themselves ARE
// const — they are immutable value objects and safe to share.
//
// ## Why there is no seeded cubit here
//
// Unlike `MutualRatingScreen`, this screen builds its own
// `DeliveryReceiptCubit` inside `BlocProvider.create` and exposes no `cubit:`
// or `seed:` seam — the ONLY injectable seam is `repository:`. Every state
// below is therefore reached the way production reaches it: through a
// repository that answers, stalls, or throws. The two confirm sub-states
// (`inFlight`, `failed`) are not constructible at all without a tap, which is
// why [confirmRejected] loads normally and only fails when the CTA is pressed.
//
// Everything here is a LOCAL fake over the domain contract — no Dio, no GetIt,
// no network — so both surfaces are network-free by construction rather than
// merely by the `CatalogNetworkGuard` their hosts install. That matters more
// than usual for this screen: `DeliveryReceiptScreen._resolveRepository()`
// falls back to `DioDeliveryReceiptRepository(sl<Dio>())` whenever `Dio` is
// registered, and inside the running app — the only place the catalog runs —
// it always is. An entry that forgot `repository:` would issue a live
// `GET /v1/deliveries/{id}` (a GET, so the guard passes it) and render whatever
// that order happens to be.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import 'package:jeeb_mobile/features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';

/// A read that never lands, holding the screen on
/// `DeliveryReceiptStatus.loading` for as long as the surface is open.
///
/// `load()` is fired from `BlocProvider.create` on the first build, so the
/// full-screen `OmdsLoadingState` is what EVERY customer sees for as long as
/// `GET /v1/deliveries/{id}` takes. This is the only way to inspect that frame
/// without a real slow connection.
class DeliveryReceiptScreenPendingRepository
    implements DeliveryReceiptRepository {
  const DeliveryReceiptScreenPendingRepository();

  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) =>
      Completer<DeliveryReceipt>().future;

  /// Unreachable: the confirm CTA only exists inside the loaded body, and this
  /// repository never produces one. Loud rather than silent — a dev surface
  /// that quietly pretends to have settled a cash-on-delivery is worse than one
  /// that stops.
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
  ///
  /// It is never rendered — the prompt shows no order reference — but it is the
  /// path parameter both hosts route with and the id the proof-photo URL is
  /// built from.
  static const String deliveryId = 'ORD-4821';

  /// The gateway dropped `amount` (run-22 P1-A): the live
  /// `GET /v1/deliveries/{id}` stops sending it once the delivery reaches
  /// `Done`. An absent amount is UNKNOWN and must degrade to the amount-less
  /// copy, never to a fabricated `$0.00`.
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
  ///
  /// `DeliveryReceipt.hasKnownAmount` treats zero and negative as unknown too —
  /// the cash owed on a priced delivery is never actually 0, so a 0 here means
  /// enrichment broke upstream. Renders the same degraded copy as
  /// [amountUnknownReceipt]; the jeeber name differs so the two can be told
  /// apart on screen.
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
  /// than asking the customer to hand cash to nobody.
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
  /// `MoneyFormat` renders as the widest token it can produce
  /// (`LBP 1,250,000.00` — ISO code, thousands separators, two decimals).
  ///
  /// The row is `Icon + Expanded(Text)`, so this is what decides whether the
  /// line wraps cleanly or collides with the icon at 200% text and in RTL.
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
  /// the happy path in a screenshot.
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
  ///
  /// The photo URL is the fake's own synthesized `cdn.jeeb.app` one, which is
  /// the single reason this state behaves differently from every other:
  /// `OmdsCachedImage` starts a real fetch and shows an indefinite shimmer
  /// until it resolves. See the note in the preview section.
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
  ///
  /// The confirm-failure banner (`receipt_confirm_error`) is only reachable by
  /// pressing the CTA — the screen builds its own cubit and there is no seam to
  /// seed one — so this fixture is the whole of that state's setup.
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

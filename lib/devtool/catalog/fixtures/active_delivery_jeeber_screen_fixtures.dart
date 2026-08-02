// Shared dev-only fixtures for `ActiveDeliveryJeeberScreen` (the jeeber-side
// active-delivery / mark-delivered surface at `/jeeber/deliveries/:id/active`).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_01_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart`.
//
// The four states the catalog already named — `inTransit`, `atDoorOtpRequired`,
// `completed`, `loadFailed` — were LIFTED VERBATIM from that entry (its private
// `_InertActiveDeliveryRepository`, `_SeededActiveDeliveryCubit` and
// `_demoDelivery`), so the catalog renders exactly what it rendered before;
// only the declaration site moved. Everything after them is new ground the
// catalog never covered, and is listed under "preview-only states" below.
//
// ## Why a seeded cubit rather than a fake repository
//
// The screen takes BOTH seams (`repository:` and `cubit:`), and they are not
// equivalent here. Handing it a repository makes it build a real
// [ActiveDeliveryCubit] and call `loadDelivery()`, which walks the load →
// arm-push → sync-GPS path and can only ever produce the two states that path
// produces. Half the states below (`transitioning`, `otpRequired`,
// `gpsPhase: permissionDenied`, a `delivered` one-shot) are simply not
// reachable from a canned `fetchDelivery`. So every state here is EMITTED into
// the cubit directly, through [ActiveDeliveryJeeberScreenSeededCubit], and the
// repository underneath it is inert by construction: with the `cubit:` seam
// supplied the screen never calls `loadDelivery()`, so
// [ActiveDeliveryJeeberScreenInertRepository] is never reached at all. It
// throws on every method rather than answering canned data, so that if a future
// edit DOES reach it the dev surface stops loudly instead of quietly inventing
// a delivery.
//
// No Dio, no GetIt, no `resolvePushRefreshStream` (that call sits in the branch
// the `cubit:` seam skips). Network-free by construction, not merely by the
// `CatalogNetworkGuard` both hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:typed_data';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_state.dart';

/// The repository the seeded cubit is built over. Every method throws, because
/// none of them may ever run: the screen's `cubit:` seam skips `loadDelivery()`
/// entirely, so a reached method means a wiring change, not a data need.
class ActiveDeliveryJeeberScreenInertRepository
    implements ActiveDeliveryRepository {
  const ActiveDeliveryJeeberScreenInertRepository();

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      throw const ActiveDeliveryException(ActiveDeliveryFailure.network);
}

/// Seeds [ActiveDeliveryCubit] directly into a designed state — the screen's
/// `cubit` constructor seam means `loadDelivery()` is never invoked, so the
/// (unreachable) [ActiveDeliveryJeeberScreenInertRepository] never fires.
///
/// No `gpsUploader` and no `refreshSignals`: the GPS phase every state needs is
/// already MIRRORED into [ActiveDeliveryState] (`gpsPhase` /
/// `gpsNeedsSystemSettings`), and with no push stream the cubit has nothing to
/// subscribe to — the seeded state is the only state it will ever hold.
class ActiveDeliveryJeeberScreenSeededCubit extends ActiveDeliveryCubit {
  ActiveDeliveryJeeberScreenSeededCubit(ActiveDeliveryState seed)
      : super(
          repository: const ActiveDeliveryJeeberScreenInertRepository(),
          deliveryId: ActiveDeliveryJeeberScreenFixtures.deliveryId,
        ) {
    emit(seed);
  }
}

/// The designed states, named once for both dev surfaces.
abstract final class ActiveDeliveryJeeberScreenFixtures {
  /// The delivery every dev surface shows. Matches the reference the Screen
  /// Catalog has used for this screen since the entry was written.
  static const String deliveryId = 'demo-delivery-01';

  /// The catalog's drop-off, shared by the four lifecycle states so that
  /// flipping between them shows the lifecycle moving and nothing else.
  static const String dropOffLabel = '221B Olaya Street';
  static const String dropOffDetail = 'Gate 3, near the blue door';
  static const String clientName = 'Sara Al-Otaibi';
  static const String amountText = r'$42.00';

  /// The load-failure copy. `ActiveDeliveryCubit._mapLoadError` produces this
  /// exact string for a `server` failure, so the error surface below is the one
  /// a 500 really renders — not an invented sentence.
  static const String loadErrorMessage = 'Unable to load delivery';

  /// Drop-off for the optimistic-completion state, which is otherwise pixel-
  /// identical to a plain `Done` render and needs a handle of its own.
  static const String optimisticDropOffLabel = 'Corniche El Mazraa 47';

  /// The longest plausible drop-off a jeeber can be handed: a mall unit with a
  /// landmark clause. Long enough to wrap three times inside `_AddressCard`'s
  /// `Expanded` column at 320 pt.
  static const String longDropOffLabel =
      'Beirut Souks, Block C, Rue Allenby — entrance beside the north '
      'escalator, opposite the fountain';

  /// A concierge instruction of the length customers actually type.
  static const String longDropOffDetail =
      'Ring the intercom marked “Al-Hajj Trading & Logistics — fourth floor, '
      'door on the right”. The lift is out of service until Thursday, so use '
      'the stairs at the back of the lobby.';

  /// A full Arabic-transliterated legal name — the cash line renders it inline
  /// after the amount, so this is where that Row runs out of room.
  static const String longClientName =
      'Abdulrahman Al-Muhandis Al-Trabulsi Al-Shamali';

  /// A LBP-denominated total: the currency with the most digits the app shows.
  static const String longAmountText = '1,250,000.00 LBP';

  /// One delivery, at whichever stage the caller wants it.
  ///
  /// Everything except [status] defaults to the catalog's demo row, so a state
  /// that varies nothing reads as "the same delivery, later".
  static JeeberDelivery delivery({
    required JeeberDeliveryStatus status,
    String label = dropOffLabel,
    String? detail = dropOffDetail,
    String? client = clientName,
    String? amount = amountText,
    String? proofPhotoUrl,
  }) =>
      JeeberDelivery(
        id: deliveryId,
        status: status,
        dropOff: DropOffAddress(
          label: label,
          lat: 24.6877,
          lng: 46.6857,
          detail: detail,
        ),
        clientName: client,
        conversationId: 'demo-conversation-01',
        amountText: amount,
        cashNote: 'Customer confirms receipt and pays cash on delivery.',
        proofPhotoUrl: proofPhotoUrl,
      );

  // ── The four states the Screen Catalog names ──────────────────────────────

  /// En route with the parcel: the stepper drops its inline advance button and
  /// the mark-delivered panel takes over the journey to Done (JM-051).
  static final ActiveDeliveryState inTransit = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.inTransit),
  );

  /// At the door, holding for the recipient's code. `AtDoor → Done` is not a
  /// client-patchable edge (P6/B1), so the panel swaps its CTA for the 4-cell
  /// door-OTP entry.
  static final ActiveDeliveryState atDoorOtpRequired = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.atDoor),
    otpRequired: true,
  );

  /// Handed over and verified — the `delivery_completed_state` panel above the
  /// address, and no advance affordance anywhere.
  static final ActiveDeliveryState completed = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(
      status: JeeberDeliveryStatus.done,
      proofPhotoUrl: 'https://example.com/proof.jpg',
    ),
  );

  /// `GET /v1/deliveries/{id}` failed — the full-screen error with its retry.
  static const ActiveDeliveryState loadFailed = ActiveDeliveryState(
    mode: ActiveDeliveryMode.error,
    errorMessage: loadErrorMessage,
  );

  // ── Preview-only states (the catalog never covered these) ─────────────────

  /// Cold open: the state the cubit is BORN in, before `loadDelivery()`
  /// resolves. A bare spinner — no title, no message, no cancel.
  static const ActiveDeliveryState loading = ActiveDeliveryState();

  /// Pre-pickup. The only stage group that still owns an inline advance button
  /// (`Ordered → Picked → InTransit`); from InTransit on, the stepper hides it.
  static final ActiveDeliveryState ordered = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.ordered),
  );

  /// P0 live tracking: en route with the GPS uploader PARKED on a missing
  /// permission the jeeber can still grant in-app ("Allow location").
  static final ActiveDeliveryState gpsBlockedRetryable = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.inTransit),
    gpsPhase: BackgroundGpsPhase.permissionDenied,
  );

  /// The same park, permanently denied or awaiting the Android 11+ "Allow all
  /// the time" upgrade — only the OS settings page can lift it, so the CTA
  /// changes rather than firing a request the platform would drop.
  static final ActiveDeliveryState gpsBlockedSettingsOnly = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.inTransit),
    gpsPhase: BackgroundGpsPhase.permissionDenied,
    gpsNeedsSystemSettings: true,
  );

  /// JEBV4-276: `Done` while a write is still in flight. The row already reads
  /// Done optimistically, but nothing is confirmed — the OTP path reverts to
  /// AtDoor from exactly here — so the "Delivered successfully" banner must NOT
  /// be painted yet.
  static final ActiveDeliveryState completingOptimistically =
      ActiveDeliveryState(
    mode: ActiveDeliveryMode.transitioning,
    delivery: delivery(
      status: JeeberDeliveryStatus.done,
      label: optimisticDropOffLabel,
    ),
  );

  /// Cancelled terminal — neutral empty state, no stepper, no actions.
  static final ActiveDeliveryState cancelled = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.cancelled),
  );

  /// Expired terminal — a broadcast that timed out before completion.
  static final ActiveDeliveryState expired = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.expired),
  );

  /// `FailedNeedsEscalation` — the one "terminal" an admin can still move
  /// (SM edges 12/13), which is why the cubit keeps watching it (P6/A2).
  static final ActiveDeliveryState disputed = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(status: JeeberDeliveryStatus.disputed),
  );

  /// The layout ceiling: longest address, longest concierge detail, longest
  /// recipient name and the widest amount, all on the state that already
  /// carries the most content (en route, panel mounted).
  static final ActiveDeliveryState longestContent = ActiveDeliveryState(
    mode: ActiveDeliveryMode.ready,
    delivery: delivery(
      status: JeeberDeliveryStatus.inTransit,
      label: longDropOffLabel,
      detail: longDropOffDetail,
      client: longClientName,
      amount: longAmountText,
    ),
  );
}

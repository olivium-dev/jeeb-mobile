import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../background_gps/application/background_gps_cubit.dart';
import '../../background_gps/application/background_gps_state.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// View-mode enum for the active-delivery Jeeber screen.
enum ActiveDeliveryMode { loading, ready, transitioning, error }

/// Lifecycle of the proof-of-delivery photo capture+upload (D3 / D1m, JM-051).
enum ProofPhotoStatus { none, uploading, captured, failed }

/// State emitted by [ActiveDeliveryCubit].
class ActiveDeliveryState extends Equatable {
  const ActiveDeliveryState({
    this.mode = ActiveDeliveryMode.loading,
    this.delivery,
    this.transitionError,
    this.transitionErrorKind,
    this.errorMessage,
    this.proofPhotoStatus = ProofPhotoStatus.none,
    this.proofPhotoBytes,
    this.note,
    this.delivered = false,
    this.otpRequired = false,
    this.isVerifyingOtp = false,
    this.otpError,
    this.gpsPhase = BackgroundGpsPhase.idle,
    this.gpsNeedsSystemSettings = false,
  });

  final ActiveDeliveryMode mode;
  final JeeberDelivery? delivery;

  /// P0 (live tracking): the jeeber's GPS uploader phase, MIRRORED here from
  /// [BackgroundGpsCubit] so the screen can render a permission banner off the
  /// one state it already builds from.
  ///
  /// Mirrored rather than provided: the uploader is optional (null in tests and
  /// devtool), and a `BlocBuilder` on a bloc that may not exist in the tree is
  /// the kind of conditional plumbing that quietly renders nothing — which is
  /// precisely the failure mode this banner exists to end. Defaults to
  /// [BackgroundGpsPhase.idle], so a screen with no uploader shows no banner.
  final BackgroundGpsPhase gpsPhase;

  /// True when the jeeber can only recover the GPS grant from the OS settings
  /// page (permanent denial, or the Android 11+ "Allow all the time" upgrade,
  /// which no in-app dialog can perform). Drives WHICH CTA the banner shows —
  /// an honest "Open settings" instead of a "Try again" that would silently
  /// no-op.
  final bool gpsNeedsSystemSettings;

  /// True when the uploader is parked on a missing permission while the
  /// delivery is en route — i.e. the customer's map is receiving nothing.
  bool get isGpsBlocked => gpsPhase == BackgroundGpsPhase.permissionDenied;

  /// One-shot snack error after a failed transition (reverted).
  final String? transitionError;

  /// P6/B4: the TYPED failure behind [transitionError], so the screen can
  /// render kind-specific localized copy instead of the cubit's English
  /// literal. Cleared together with [transitionError] by `clearTransitionError`.
  final ActiveDeliveryFailure? transitionErrorKind;

  /// Full-screen error message on load failure.
  final String? errorMessage;

  /// Proof-of-delivery photo capture/upload lifecycle (JM-051 AC1).
  final ProofPhotoStatus proofPhotoStatus;

  /// JEBV4-200: the locally captured proof-photo bytes, retained so the jeeber
  /// sees the ACTUAL image they just took (rendered from memory) while the
  /// stamped `evidenceUrl` is a durable `object_ref` the gateway resolves on the
  /// customer receipt read. Null until a photo is captured this session.
  final Uint8List? proofPhotoBytes;

  /// Optional Jeeber note attached to the delivery (JM-051 AC1).
  final String? note;

  /// One-shot signal that the delivery reached `Done` — the screen routes to
  /// `feedback-rate-delivery` (JM-051 AC2 / JM-034 / D56), NOT the OTP handover.
  final bool delivered;

  /// iter6 close-tail: true once `AtDoor → Done` came back **422 `otp_required`**
  /// — the delivery carries a recipient phone, so the screen surfaces a
  /// door-OTP entry. The recipient gives the jeeber the code; the jeeber enters
  /// it and [ActiveDeliveryCubit.submitDoorOtp] completes the delivery.
  final bool otpRequired;

  /// True while a submitted door OTP is being verified against the gateway.
  final bool isVerifyingOtp;

  /// Inline error under the door-OTP field (wrong code / locked / network).
  final String? otpError;

  bool get isTransitioning => mode == ActiveDeliveryMode.transitioning;

  bool get isUploadingProof => proofPhotoStatus == ProofPhotoStatus.uploading;

  bool get hasProofPhoto =>
      proofPhotoStatus == ProofPhotoStatus.captured &&
      (delivery?.hasProofPhoto ?? false);

  ActiveDeliveryState copyWith({
    ActiveDeliveryMode? mode,
    JeeberDelivery? delivery,
    String? transitionError,
    ActiveDeliveryFailure? transitionErrorKind,
    bool clearTransitionError = false,
    String? errorMessage,
    bool clearError = false,
    ProofPhotoStatus? proofPhotoStatus,
    Uint8List? proofPhotoBytes,
    String? note,
    bool clearNote = false,
    bool? delivered,
    bool? otpRequired,
    bool? isVerifyingOtp,
    String? otpError,
    bool clearOtpError = false,
    BackgroundGpsPhase? gpsPhase,
    bool? gpsNeedsSystemSettings,
  }) {
    return ActiveDeliveryState(
      mode: mode ?? this.mode,
      delivery: delivery ?? this.delivery,
      transitionError: clearTransitionError
          ? null
          : (transitionError ?? this.transitionError),
      transitionErrorKind: clearTransitionError
          ? null
          : (transitionErrorKind ?? this.transitionErrorKind),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      proofPhotoStatus: proofPhotoStatus ?? this.proofPhotoStatus,
      proofPhotoBytes: proofPhotoBytes ?? this.proofPhotoBytes,
      note: clearNote ? null : (note ?? this.note),
      delivered: delivered ?? this.delivered,
      otpRequired: otpRequired ?? this.otpRequired,
      isVerifyingOtp: isVerifyingOtp ?? this.isVerifyingOtp,
      otpError: clearOtpError ? null : (otpError ?? this.otpError),
      gpsPhase: gpsPhase ?? this.gpsPhase,
      gpsNeedsSystemSettings:
          gpsNeedsSystemSettings ?? this.gpsNeedsSystemSettings,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        delivery,
        transitionError,
        transitionErrorKind,
        errorMessage,
        proofPhotoStatus,
        proofPhotoBytes,
        note,
        delivered,
        otpRequired,
        isVerifyingOtp,
        otpError,
        gpsPhase,
        gpsNeedsSystemSettings,
      ];
}

/// Drives the Jeeber active-delivery screen (T-MOB-031, extended by JM-051).
///
/// Loads the delivery snapshot from [ActiveDeliveryRepository] and lets the
/// Jeeber advance the early stages ([advanceStatus]) and finally complete the
/// delivery ([markDelivered]) — which captures a proof photo (D3), walks the
/// forward ladder up to **`AtDoor`** carrying the evidence URL, and then raises
/// the door-OTP entry. P6/B1: the CTA does **not** drive `AtDoor → Done`; the
/// frozen SM opens that door only for `otp_verified`, so [submitDoorOtp]
/// completes the delivery and emits `delivered: true` so the screen chains to
/// the mandatory rating (JM-034/D56).
class ActiveDeliveryCubit extends Cubit<ActiveDeliveryState> {
  ActiveDeliveryCubit({
    required ActiveDeliveryRepository repository,
    required this.deliveryId,
    PhotoPickerService? photoPicker,
    PhotoCompressor compressor = const HalvingPhotoCompressor(),
    Stream<void>? refreshSignals,
    BackgroundGpsCubit? gpsUploader,
  })  : _repository = repository,
        _photoPicker = photoPicker ?? StubPhotoPickerService(),
        _compressor = compressor,
        _refreshSignals = refreshSignals,
        _gpsUploader = gpsUploader,
        super(const ActiveDeliveryState()) {
    _armGpsMirror();
  }

  final ActiveDeliveryRepository _repository;
  final String deliveryId;

  /// JEBV4-269: the jeeber's live-GPS upload pipeline, owned for the lifetime
  /// of this cubit. While the delivery is en route (`InTransit`) the uploader
  /// streams the jeeber's position to the gateway so the customer's live map
  /// has data; it is stopped the moment the delivery leaves InTransit (AtDoor /
  /// Done / any terminal state) or the screen closes — the gateway only ingests
  /// during the en-route phase (409 otherwise) and battery is spared the rest
  /// of the time. Null in tests/devtool that don't exercise GPS; every call
  /// site is null-guarded via [_syncGpsUpload]. Its own lifecycle (permissions,
  /// stream teardown) is delegated entirely to [BackgroundGpsCubit].
  final BackgroundGpsCubit? _gpsUploader;

  /// Captures the proof-of-delivery photo from the device camera (JEBV4-200).
  /// Defaults to [StubPhotoPickerService] (canned bytes) so devtool/tests run
  /// without a real camera; production injects [ImagePickerPhotoPickerService].
  final PhotoPickerService _photoPicker;

  /// Shrinks the captured photo under the upload ceiling before it streams to
  /// the CDN broker — reused from the KYC/attachment capture path.
  final PhotoCompressor _compressor;

  /// b02 wave C — N6. Payload-less push→refetch bus. Every event is ONE re-read
  /// of `GET /v1/deliveries/{id}`; there is no cadence behind it.
  ///
  /// This REPLACED a 5s `LifecyclePoller` (JEBV4-282) whose own rationale said
  /// it existed so that a backend-side transition — the customer or the system
  /// advancing or cancelling the row — would surface WITHOUT the jeeber leaving
  /// and re-entering the screen. That is a description of a push, written before
  /// the push existed: the delivery-status push used to be composed against the
  /// in-gateway stack, which binds `InMemoryPushTransport`, delivers nothing and
  /// then logs `Delivered` (see `IDeliveryStatusPushNotifier`). So the poll was
  /// load-bearing at the time it was written.
  ///
  /// It is not any more. `NotifyOtherPartyAsync`
  /// (`Controllers/DeliveriesController.cs:1296-1300`) puts BOTH `req.ClientId`
  /// AND `req.JeeberId` on the recipient list — this jeeber is a recipient of
  /// every status flip, not only the customer — and
  /// `Notifications/DeliveryStatusPushNotifier.cs:211` now goes out over the
  /// push microservice with `type=delivery` + a snake_case `delivery_id`, which
  /// is exactly the discriminator/id pair
  /// `PushNotificationHandler._maybeSignalStatusChange` needs to clear its
  /// `orderish` id guard.
  ///
  /// The resume backstop is UNCHANGED and still matters: the screen's
  /// `_ResumeRefresh` observer calls [refresh] on every foreground resume
  /// (`active_delivery_jeeber_screen.dart:695-701`), which catches a push the OS
  /// dropped or coalesced while the process was backgrounded. That read is
  /// caused by the user returning to the app, not by a clock.
  ///
  /// `null` in a bare test/devtool with no DI — the cubit then only reads on
  /// load, resume and the jeeber's own actions.
  final Stream<void>? _refreshSignals;

  StreamSubscription<void>? _refreshSubscription;

  /// Mirrors [BackgroundGpsCubit]'s phase into [ActiveDeliveryState] so the
  /// screen renders the permission banner. Null when no uploader was injected.
  StreamSubscription<BackgroundGpsState>? _gpsSubscription;

  /// True once the push subscription is armed. Lets a test assert the wiring
  /// without reaching into the stream.
  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  /// True once the GPS-phase mirror is armed. Same purpose as
  /// [debugPushRefreshWired] — asserts the wiring, not the behaviour.
  @visibleForTesting
  bool get debugGpsMirrorWired => _gpsSubscription != null;

  /// Subscribes to the uploader's state and mirrors the two fields the banner
  /// needs. Idempotent; a no-op without an uploader.
  ///
  /// Called from the constructor body path rather than lazily, because the very
  /// first thing that can go wrong (a permission park on `start`) happens before
  /// any user interaction — if the mirror armed on first render we would miss it.
  void _armGpsMirror() {
    final gps = _gpsUploader;
    if (gps == null || _gpsSubscription != null) return;
    _mirrorGpsState(gps.state);
    _gpsSubscription = gps.stream.listen(_mirrorGpsState);
  }

  void _mirrorGpsState(BackgroundGpsState gpsState) {
    if (isClosed) return;
    emit(state.copyWith(
      gpsPhase: gpsState.phase,
      gpsNeedsSystemSettings: gpsState.needsSystemSettings,
    ));
  }

  /// Banner CTA — re-runs the permission escalation for the live delivery.
  /// Also called on app resume so a grant made in system settings is picked up
  /// without the jeeber leaving and re-entering the screen.
  Future<void> retryGpsPermission() async {
    await _gpsUploader?.retryPermission();
  }

  /// Banner CTA — opens the app's OS settings page, the only place Android 11+
  /// exposes "Allow all the time".
  Future<void> openGpsSettings() async {
    await _gpsUploader?.openSystemSettings();
  }

  Future<void> loadDelivery() async {
    emit(state.copyWith(mode: ActiveDeliveryMode.loading, clearError: true));
    try {
      final delivery = await _repository.fetchDelivery(deliveryId);
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: delivery,
        // Reflect a pre-stamped proof photo (seam may seed evidenceUrl).
        proofPhotoStatus: delivery.hasProofPhoto
            ? ProofPhotoStatus.captured
            : ProofPhotoStatus.none,
      ));
      // JEBV4-282: begin re-polling once we have a live (non-terminal) row.
      _armPoll();
      // JEBV4-269: (re)evaluate GPS upload against the freshly loaded status —
      // a deep-link straight into an already-InTransit delivery starts
      // streaming immediately.
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.error,
        errorMessage: _mapLoadError(e),
      ));
    }
  }

  /// JEBV4-282: (re)arm the background poll. No-op once the delivery is
  /// `Done`/`Cancelled`/`Expired` — such a row never changes again, so we stop
  /// hitting the gateway. A `disputed` (`FailedNeedsEscalation`) row KEEPS
  /// polling — an admin can still resolve it to Done (SM edge 12) or cancel it
  /// (edge 13), and pre-fix the jeeber's screen stopped watching (P6/A2).
  ///
  /// The stop predicate is [JeeberDeliveryStatus.isPollTerminal], NOT
  /// `isTerminal`: `isTerminal` includes `disputed`, so using it here would
  /// re-break P6/A2. It also matches [_canPoll], which gates the same rows.
  /// Arm the push subscription for a live row, retire it for a dead one.
  ///
  /// Retiring on a poll-terminal row is not merely an optimisation: it is what
  /// stops a LATER unrelated push (the bus is app-wide and payload-less) from
  /// re-reading a `Done`/`Cancelled`/`Expired` delivery forever.
  ///
  /// Idempotent — safe to call from load, from every user-driven write, and
  /// from the push handler itself.
  void _armPoll() {
    final delivery = state.delivery;
    if (delivery == null || delivery.status.isPollTerminal) {
      _retireRefreshSubscription();
      return;
    }
    _refreshSubscription ??= _refreshSignals?.listen((_) => _refreshFromPush());
  }

  /// Stop listening to the push bus. Deliberately SYNCHRONOUS, and the
  /// `cancel()` future is deliberately NOT awaited.
  ///
  /// Two independent reasons:
  ///  1. Correctness does not need the await. Once `cancel()` RETURNS, the
  ///     subscription delivers no further events; the future it hands back only
  ///     reports downstream cleanup. Nulling the field is what makes this
  ///     observable (`debugPushRefreshWired`) and is done first.
  ///  2. Awaiting it DEADLOCKS `close()` under `testWidgets`. Awaiting
  ///     `cancel()` as the first statement of [close] hangs the fake-async test
  ///     zone indefinitely — the test never completes and the shell is
  ///     SIGTERM'd, which reads as an infrastructure flake rather than as
  ///     something this file did. Recorded here so nobody "tidies" it back.
  void _retireRefreshSubscription() {
    unawaited(_refreshSubscription?.cancel());
    _refreshSubscription = null;
  }

  /// Kept as a distinct name at the user-driven-write call sites: those used to
  /// RESTART the poll interval so the optimistic emit was not immediately
  /// overwritten by an in-flight tick. With no cadence there is nothing to
  /// restart, but the terminality check still has to run — a write that lands
  /// the row on `Done` must retire the subscription.
  void _schedulePoll() => _armPoll();

  /// One push → one re-read. Single-flighted so two pushes landing inside one
  /// round trip produce ONE re-pull, not two whose emits race (the later request
  /// can complete first and paint the OLDER snapshot).
  Future<void> _refreshFromPush() async {
    if (isClosed || _pushRefreshInFlight) return;
    _pushRefreshInFlight = true;
    try {
      await _poll();
    } finally {
      _pushRefreshInFlight = false;
    }
  }

  bool _pushRefreshInFlight = false;

  /// Silent re-fetch (no loading flash). Skips while a user-driven transition /
  /// proof upload is in flight so it never clobbers optimistic state; a fetch
  /// failure is swallowed (the last good snapshot stays on screen and the next
  /// push / resume retries).
  ///
  /// Every gate below is preserved verbatim from the poll era — only the TRIGGER
  /// changed from a 5s timer to a `type=delivery` push (plus the unchanged
  /// resume backstop). In particular the door-OTP window still only accepts a
  /// TERMINAL server verdict (P6/A4), because a push arriving mid-OTP-entry can
  /// clobber the field exactly as a poll tick could.
  Future<void> _poll() async {
    if (isClosed) return;
    if (!_canPoll(state)) return;
    // P6/A4: while the door-OTP surface is up the poll is allowed to RUN but
    // may only deliver a TERMINAL server verdict — anything else would clobber
    // the OTP entry the jeeber is typing into.
    final otpWindow = state.otpRequired || state.isVerifyingOtp;
    try {
      final fresh = await _repository.fetchDelivery(deliveryId);
      if (isClosed || !_canPoll(state)) return;
      if (otpWindow && !fresh.status.isTerminal) return;
      // Preserve a proof photo captured locally this session that the backend
      // snapshot may not carry yet.
      final localProof = state.delivery?.proofPhotoUrl;
      final merged = (fresh.proofPhotoUrl == null && localProof != null)
          ? fresh.withProofPhoto(localProof)
          : fresh;
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: merged,
        // A terminal verdict read during the OTP window closes the OTP surface…
        otpRequired: otpWindow && merged.status.isTerminal ? false : null,
        isVerifyingOtp: otpWindow && merged.status.isTerminal ? false : null,
        // …and a Done read chains to the mandatory rating exactly like the
        // in-app verify would (JM-034/D56).
        delivered: merged.status.isSuccessfulTerminal ? true : null,
      ));
      if (merged.status.isPollTerminal) {
        _retireRefreshSubscription();
      }
      // JEBV4-269: a backend-driven status flip (customer/system advancing the
      // row to InTransit, or completing/cancelling it) starts or stops the GPS
      // upload without the jeeber tapping anything.
      _syncGpsUpload();
    } on ActiveDeliveryException {
      // Swallow — keep the last good snapshot; the next tick retries.
    }
  }

  /// JEBV4-269: reconcile the live-GPS uploader with the current delivery
  /// status. The uploader runs for exactly one window — while the delivery is
  /// `InTransit` (the en-route phase, the only phase the gateway ingests fixes
  /// for and the only phase the customer needs a live map) — and is idle every
  /// other stage. [BackgroundGpsCubit.start] is idempotent (a no-op when
  /// already tracking this delivery), so this is safe to call on every poll
  /// tick and status transition; the `stop` is guarded on the uploader not
  /// already being idle so a stationary Ordered/Picked delivery doesn't churn
  /// its state. No-op when no uploader was injected (tests / devtool).
  void _syncGpsUpload() {
    final gps = _gpsUploader;
    if (gps == null) return;
    final enRoute = state.delivery?.status == JeeberDeliveryStatus.inTransit;
    if (enRoute) {
      unawaited(gps.start(deliveryId));
    } else if (gps.state.phase != BackgroundGpsPhase.idle) {
      unawaited(gps.stop());
    }
  }

  /// True when a silent poll may RUN — i.e. we have a live (non-poll-terminal)
  /// row and no user-driven write (transition / proof upload) is mid-flight.
  ///
  /// P6/A4: the door-OTP conditions moved out of here — they now govern which
  /// poll RESULTS are ACCEPTED (see [_poll]), not whether the poll is
  /// scheduled, so a delivery completed out-of-band while the jeeber stares at
  /// the OTP entry still surfaces.
  bool _canPoll(ActiveDeliveryState s) {
    final delivery = s.delivery;
    return delivery != null &&
        !delivery.status.isPollTerminal &&
        !s.isTransitioning &&
        !s.isUploadingProof;
  }

  /// JEBV4-282: force an immediate silent re-fetch + re-evaluate the push
  /// subscription. The screen wires this to app-resume
  /// (`active_delivery_jeeber_screen.dart:695-701`) so a delivery advanced while
  /// the app was backgrounded surfaces on return — a push the OS dropped or
  /// coalesced while the process was down is exactly what this catches. This is
  /// the ONLY remaining non-push read trigger besides the cold load and the
  /// jeeber's own writes, and it is caused by the user returning to the app, not
  /// by a clock.
  /// Single-flighted with the push path via [_pushRefreshInFlight]. Not
  /// belt-and-braces: `didChangeAppLifecycleState(resumed)` can fire MORE THAN
  /// ONCE for a single background→foreground trip (the platform normalizes
  /// `paused → hidden → inactive → resumed` and notifies along the way) and the
  /// screen's hook posts a frame callback on each. Without the latch that is two
  /// full `GET /v1/deliveries/{id}` round trips on every app switch — the exact
  /// traffic this change exists to remove, invisible in the poll era because the
  /// poll's own ticks buried it.
  Future<void> refresh() async {
    if (isClosed || _pushRefreshInFlight) return;
    _pushRefreshInFlight = true;
    try {
      await _poll();
    } finally {
      _pushRefreshInFlight = false;
    }
    _armPoll();
  }

  /// Advance status to the next valid stage (Ordered → Picked → InTransit).
  ///
  /// Emits transitioning immediately (optimistic UI), then either confirms on
  /// success or reverts + sets [transitionError] on failure. The delivering
  /// phase (`InTransit → AtDoor → Done`) is driven by [markDelivered] (it needs
  /// the proof photo + done→rating chain), so this no-ops from `InTransit` on.
  Future<void> advanceStatus() async {
    final current = state.delivery;
    if (current == null) return;
    if (current.status == JeeberDeliveryStatus.inTransit ||
        current.status == JeeberDeliveryStatus.atDoor) {
      return;
    }
    final nextStatus = current.status.next;
    if (nextStatus == null) return;
    if (state.isTransitioning) return;

    final optimistic = _withStatus(current, nextStatus);
    emit(state.copyWith(
      mode: ActiveDeliveryMode.transitioning,
      delivery: optimistic,
      clearTransitionError: true,
    ));

    try {
      final confirmed = await _repository.transition(
        deliveryId: deliveryId,
        from: current.status,
        to: nextStatus,
      );
      _logTransition(current.status, confirmed);
      final confirmedDelivery = _withStatus(current, confirmed);
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: confirmedDelivery,
      ));
      // JEBV4-269: the jeeber's own `Picked → InTransit` tap starts the GPS
      // upload immediately (no wait for the next poll tick).
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      // Revert
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: current,
        transitionError: _mapTransitionError(e),
        transitionErrorKind: e.failure,
      ));
    }
  }

  /// Capture + upload the proof-of-delivery photo (D3, JM-051 AC1, JEBV4-200).
  ///
  /// Opens the device camera, compresses the captured frame, and streams the
  /// REAL image BYTES through the gateway CDN signed-PUT proxy — never a
  /// filename stand-in. The durable `object_ref` the upload returns is stamped
  /// as the delivery's `evidenceUrl` so the `AtDoor → Done` transition carries
  /// it; the captured bytes are retained in state so the jeeber sees the actual
  /// photo they just took.
  ///
  /// A cancelled capture is a silent no-op (the jeeber backed out of the camera);
  /// a permission/hardware failure reverts to the tappable placeholder to retry.
  Future<void> captureProofPhoto() async {
    final current = state.delivery;
    if (current == null) return;
    if (state.isUploadingProof) return;

    final Uint8List bytes;
    try {
      final raw = await _photoPicker.pickFromCamera();
      bytes = await _compressor.compress(raw.bytes);
    } on PhotoPickException catch (e) {
      // Cancelled → leave the capture affordance untouched. Any other pick
      // failure (permission/hardware) → drop back to the retryable placeholder.
      if (e.failure != PhotoPickFailure.cancelled) {
        emit(state.copyWith(proofPhotoStatus: ProofPhotoStatus.none));
      }
      return;
    }

    emit(state.copyWith(
      proofPhotoStatus: ProofPhotoStatus.uploading,
      proofPhotoBytes: bytes,
      clearTransitionError: true,
    ));
    try {
      final url = await _repository.uploadProofPhoto(
        deliveryId: deliveryId,
        bytes: bytes,
      );
      emit(state.copyWith(
        delivery: current.withProofPhoto(url),
        proofPhotoStatus: ProofPhotoStatus.captured,
      ));
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        proofPhotoStatus: ProofPhotoStatus.failed,
        transitionError: _mapTransitionError(e),
        transitionErrorKind: e.failure,
      ));
    }
  }

  /// Record the optional Jeeber note (JM-051 AC1).
  void setNote(String value) {
    final trimmed = value.trim();
    emit(trimmed.isEmpty
        ? state.copyWith(clearNote: true)
        : state.copyWith(note: trimmed));
  }

  /// Complete the delivery (JM-051 AC2, P6/B1).
  ///
  /// Walks the remaining SM-1 forward steps up to — and only up to — `AtDoor`
  /// (`Ordered → … → InTransit → AtDoor`), stamping the proof `evidenceUrl` on
  /// the last walked step (D3). The final `AtDoor → Done` leg is NOT patched:
  /// the frozen SM (`DeliverySm.cs:53-62`) opens that door only for
  /// `otp_verified`, so the cubit raises the door-OTP entry and [submitDoorOtp]
  /// completes the delivery — which is what emits `delivered: true` and chains
  /// to the mandatory rating (D56).
  Future<void> markDelivered() async {
    final original = state.delivery;
    if (original == null) return;
    if (state.isTransitioning) return;
    if (original.status.isTerminal) return;

    // Already at the door: nothing to patch. Straight to the OTP handover.
    if (original.status == JeeberDeliveryStatus.atDoor) {
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        otpRequired: true,
        clearTransitionError: true,
        clearOtpError: true,
      ));
      _syncGpsUpload();
      return;
    }

    emit(state.copyWith(
      mode: ActiveDeliveryMode.transitioning,
      delivery: _withStatus(original, JeeberDeliveryStatus.atDoor),
      clearTransitionError: true,
    ));

    var from = original.status;
    // P6/B5: the display must never fall BELOW what the server already
    // committed, so a failed step reverts to the last CONFIRMED status.
    var lastConfirmed = original.status;
    try {
      while (from != JeeberDeliveryStatus.atDoor) {
        final to = from.next;
        if (to == null) break;
        final isLastWalkedStep = to == JeeberDeliveryStatus.atDoor;
        final confirmed = await _repository.transition(
          deliveryId: deliveryId,
          from: from,
          to: to,
          // The proof evidence rides the last step we actually patch.
          evidenceUrl: isLastWalkedStep ? original.proofPhotoUrl : null,
        );
        _logTransition(from, confirmed);
        lastConfirmed = confirmed;
        from = confirmed;
        // Guard against a server that refuses to advance (avoid an infinite
        // loop if `confirmed` echoes `from`).
        if (confirmed != to) break;
      }
      final atDoor = from == JeeberDeliveryStatus.atDoor;
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        delivery: _withStatus(original, from),
        // Reached the door → hand over to the recipient OTP.
        otpRequired: atDoor,
        // Defensive: a server that already completed the row out-of-band.
        delivered: from == JeeberDeliveryStatus.done,
        clearOtpError: true,
      ));
      // FM-4: re-arm the poll from a full fresh interval after a user-driven
      // write, so the optimistic emit above is never immediately overwritten.
      _schedulePoll();
      // JEBV4-269: mark-delivered walks the row past InTransit (→ AtDoor), so
      // this stops the GPS upload — the jeeber has arrived and the customer no
      // longer needs a live position.
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      // A phone-bearing delivery can answer an early step with `otp_required`
      // too. Don't show "transition not allowed" — surface the door-OTP entry
      // instead, held at the last stage the server confirmed.
      if (e.failure == ActiveDeliveryFailure.otpRequired) {
        emit(state.copyWith(
          mode: ActiveDeliveryMode.ready,
          delivery: _withStatus(original, lastConfirmed),
          otpRequired: true,
          clearTransitionError: true,
          clearOtpError: true,
        ));
        // JEBV4-269: held awaiting the recipient OTP — past the en-route
        // window, so the uploader stops here too.
        _syncGpsUpload();
        return;
      }
      emit(state.copyWith(
        mode: ActiveDeliveryMode.ready,
        // P6/B5: last CONFIRMED status, not `original`.
        delivery: _withStatus(original, lastConfirmed),
        transitionError: _mapTransitionError(e),
        transitionErrorKind: e.failure,
      ));
    }
  }

  /// iter6 close-tail: verify the recipient's door OTP to complete a
  /// phone-bearing delivery `AtDoor → Done` (live :10090 ground truth:
  /// `POST /v1/deliveries/{id}/otp/verify {code}` → 200 { verified, status:Done }).
  /// The recipient hands the jeeber the code at the door; the jeeber enters it
  /// on the complete screen.
  ///
  /// On success emits `delivered: true` so the screen chains to the mandatory
  /// rating (JM-034 / D56). A wrong code keeps the entry open with an inline
  /// error; a network fault is retryable.
  Future<void> submitDoorOtp(String code) async {
    final current = state.delivery;
    if (current == null) return;
    if (state.isVerifyingOtp) return;
    final trimmed = code.trim();
    if (trimmed.length < 4) {
      emit(state.copyWith(otpError: 'Enter the 4-digit delivery code'));
      return;
    }
    emit(state.copyWith(isVerifyingOtp: true, clearOtpError: true));
    try {
      final status = await _repository.verifyDoorOtp(
        deliveryId: deliveryId,
        code: trimmed,
      );
      _logTransition(JeeberDeliveryStatus.atDoor, status);
      final done = status == JeeberDeliveryStatus.done;
      emit(state.copyWith(
        isVerifyingOtp: false,
        delivery: _withStatus(current, status),
        otpRequired: !done,
        delivered: done,
        clearOtpError: true,
      ));
      _schedulePoll();
      // JEBV4-269: door-OTP verification completes the row (Done) — ensure the
      // uploader is stopped (it already is post-AtDoor; defensive/idempotent).
      _syncGpsUpload();
    } on ActiveDeliveryException catch (e) {
      emit(state.copyWith(
        isVerifyingOtp: false,
        otpError: _mapOtpError(e),
      ));
    }
  }

  void acknowledgeTransitionError() {
    emit(state.copyWith(clearTransitionError: true));
  }

  /// Clear the inline door-OTP error after the snackbar/field rebuild reads it.
  void acknowledgeOtpError() {
    emit(state.copyWith(clearOtpError: true));
  }

  /// Acknowledge the one-shot `delivered` navigation signal so a rebuild does
  /// not re-fire the rating route.
  void acknowledgeDelivered() {
    emit(state.copyWith(delivered: false));
  }

  @override
  Future<void> close() async {
    _retireRefreshSubscription();
    // Drop the phase mirror BEFORE stopping the uploader — `stop()` emits an
    // idle state, and mirroring it would `emit` into an already-closing cubit.
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    // JEBV4-269: the uploader is owned for this cubit's lifetime — tear its GPS
    // stream down and close it so no fixes leak past the screen (battery + no
    // stray uploads for a delivery the jeeber has navigated away from).
    final gps = _gpsUploader;
    if (gps != null) {
      await gps.stop();
      await gps.close();
    }
    return super.close();
  }

  JeeberDelivery _withStatus(JeeberDelivery d, JeeberDeliveryStatus s) {
    return JeeberDelivery(
      id: d.id,
      status: s,
      dropOff: d.dropOff,
      clientName: d.clientName,
      conversationId: d.conversationId,
      amountText: d.amountText,
      cashNote: d.cashNote,
      proofPhotoUrl: d.proofPhotoUrl,
    );
  }

  String _mapLoadError(ActiveDeliveryException e) {
    if (e.failure == ActiveDeliveryFailure.network) {
      return 'No internet connection';
    }
    if (e.failure == ActiveDeliveryFailure.notFound) {
      return 'Delivery not found';
    }
    return 'Unable to load delivery';
  }

  String _mapTransitionError(ActiveDeliveryException e) {
    if (e.failure == ActiveDeliveryFailure.otpRequired) {
      // Defensive: markDelivered handles otpRequired before this maps it, so
      // this is only hit if an EARLY step somehow returns the gate. Point the
      // jeeber at the code rather than the misleading "not allowed".
      return 'Enter the delivery OTP from the recipient to complete';
    }
    if (e.failure == ActiveDeliveryFailure.invalidTransition) {
      return 'That transition is not allowed';
    }
    // P6/B4: a 400 is the gateway's own body resolver refusing the request —
    // a client-bug signature, never an SM verdict, so it must not read as one.
    if (e.failure == ActiveDeliveryFailure.badRequest) {
      return 'We couldn’t apply that update';
    }
    if (e.failure == ActiveDeliveryFailure.network) {
      return 'No internet connection';
    }
    return 'Unable to update status';
  }

  String _mapOtpError(ActiveDeliveryException e) {
    switch (e.failure) {
      case ActiveDeliveryFailure.invalidOtp:
        return 'Incorrect code — ask the recipient and try again';
      case ActiveDeliveryFailure.otpLocked:
        return 'Too many attempts — contact support';
      case ActiveDeliveryFailure.network:
        return 'No internet connection';
      case ActiveDeliveryFailure.notFound:
        return 'Delivery not found';
      case ActiveDeliveryFailure.otpRequired:
      case ActiveDeliveryFailure.invalidTransition:
      case ActiveDeliveryFailure.badRequest:
      case ActiveDeliveryFailure.server:
        return 'Unable to verify the code';
    }
  }

  // AC7: delivery.status_transition log
  // ignore: avoid_print
  void _logTransition(JeeberDeliveryStatus from, JeeberDeliveryStatus to) {
    // ignore: avoid_print
    print('[delivery.status_transition] from=${from.apiValue} to=${to.apiValue}');
  }
}

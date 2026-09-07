import 'dart:async';

import '../../../features/delivery_status/domain/jeeber_summary.dart';
import '../../../features/live_tracking/domain/delivery_tracking_info.dart';
import '../../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../../features/otp_handover/domain/handover_code_store.dart';
import '../../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../../features/otp_handover/domain/otp_handover_result.dart';

/// Fixed arrival source for R13's orange banner (doc-13 Pattern G: the banner
/// had no fixture, so no capture ever showed the board's one solid block).
class ScriptedArrivalTracking implements LiveTrackingRepository {
  const ScriptedArrivalTracking(this.info);

  final DeliveryTrackingInfo info;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => info;
}

/// Fake [OtpHandoverRepository] with independent fetch and submit paths.
class ScriptedOtpHandoverRepository implements OtpHandoverRepository {
  const ScriptedOtpHandoverRepository({
    this.fetchResult,
    this.fetchErrorKind,
    this.fetchStalls = false,
    this.submitErrorKind,
    this.submitStalls = false,
    this.submitLocked,
    this.submitAttemptsRemaining,
  });

  /// Successful `fetchHandoverCode` result; defaults to SMS trigger.
  final OtpFetchResult? fetchResult;

  /// Error thrown by `fetchHandoverCode` when set.
  final OtpHandoverErrorKind? fetchErrorKind;

  /// When true, `fetchHandoverCode` never resolves.
  final bool fetchStalls;

  /// Error thrown by `submitOtp` when set.
  final OtpHandoverErrorKind? submitErrorKind;

  /// When true, `submitOtp` never resolves.
  final bool submitStalls;

  /// A 423 carrying the case the gateway already opened.
  final OtpHandoverLocked? submitLocked;

  /// Server-reported attempts left on a rejected code.
  final int? submitAttemptsRemaining;

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) {
    if (fetchStalls) return Completer<OtpFetchResult>().future;
    final OtpHandoverErrorKind? kind = fetchErrorKind;
    if (kind != null) {
      return Future<OtpFetchResult>.error(OtpHandoverException(kind));
    }
    return Future<OtpFetchResult>.value(
      fetchResult ?? const OtpFetchResult(smsTriggered: true),
    );
  }

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) {
    if (submitStalls) return Completer<OtpHandoverResult>().future;
    final OtpHandoverException? locked = submitLocked;
    if (locked != null) return Future<OtpHandoverResult>.error(locked);
    final OtpHandoverErrorKind? kind = submitErrorKind;
    if (kind != null) {
      return Future<OtpHandoverResult>.error(
        OtpHandoverException(kind, null, submitAttemptsRemaining),
      );
    }
    return Future<OtpHandoverResult>.value(
      const OtpHandoverResult(success: true),
    );
  }
}

/// In-memory [HandoverCodeStore] for preview use; avoids SharedPreferences.
class InMemoryHandoverCodeStore implements HandoverCodeStore {
  InMemoryHandoverCodeStore([this._code]);

  String? _code;

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    _code = code;
  }

  @override
  Future<String?> read({required String deliveryId}) async => _code;

  @override
  Future<void> clear({required String deliveryId}) async {
    _code = null;
  }
}

/// Designed states as collaborators plus cubit pre-drive.
class OtpHandoverScreenPreviewFixtures {
  const OtpHandoverScreenPreviewFixtures._();

  /// The delivery id for all states.
  static const String deliveryId = 'DEL-3091';

  /// Code shown to customer and typed by jeeber to succeed.
  static const String storedCode = '4821';

  /// Four digits for 320 pt floor.
  static const String compactCode = '9061';

  /// Code wider than UI design.
  static const String widenedCode = '481902';

  /// Incorrect code for testing rejection.
  static const String wrongCode = '0000';

  /// Reference repository: fetch SMS trigger, submit succeeds.
  static OtpHandoverRepository accepting() =>
      const ScriptedOtpHandoverRepository();

  /// Customer's cold read in flight.
  static OtpHandoverRepository stalledFetch() =>
      const ScriptedOtpHandoverRepository(fetchStalls: true);

  /// Customer's cold read failed.
  static OtpHandoverRepository failingFetch([
    OtpHandoverErrorKind kind = OtpHandoverErrorKind.network,
  ]) => ScriptedOtpHandoverRepository(fetchErrorKind: kind);

  /// Gateway answered with a code.
  static OtpHandoverRepository returningCode([String code = storedCode]) =>
      ScriptedOtpHandoverRepository(fetchResult: OtpFetchResult(code: code));

  /// Every verify rejected as wrong code.
  static OtpHandoverRepository rejectingSubmit() =>
      const ScriptedOtpHandoverRepository(
        submitErrorKind: OtpHandoverErrorKind.invalidOtp,
      );

  /// Verify POST never resolves.
  static OtpHandoverRepository stalledSubmit() =>
      const ScriptedOtpHandoverRepository(submitStalls: true);

  /// 423 with an already-opened case: the dialog routes to it (AE-03).
  static OtpHandoverRepository lockedWithEscalation([
    String escalationId = 'ESC-9001',
  ]) => ScriptedOtpHandoverRepository(
        submitLocked: OtpHandoverLocked(escalationId: escalationId),
      );

  /// The jeeber is not at the door yet (AE-12).
  static OtpHandoverRepository notAtDoor() =>
      const ScriptedOtpHandoverRepository(
        submitErrorKind: OtpHandoverErrorKind.notAtDoor,
      );

  /// The code belongs to someone else (AE-12).
  static OtpHandoverRepository wrongParty() =>
      const ScriptedOtpHandoverRepository(
        submitErrorKind: OtpHandoverErrorKind.wrongParty,
      );

  /// A rejected code the gateway counted for us (AE-11).
  static OtpHandoverRepository attemptsRemaining2() =>
      const ScriptedOtpHandoverRepository(
        submitErrorKind: OtpHandoverErrorKind.invalidOtp,
        submitAttemptsRemaining: 2,
      );

  /// Code already on device.
  static HandoverCodeStore codeStore([String code = storedCode]) =>
      InMemoryHandoverCodeStore(code);

  /// The board's own banner payload: `Karim` · `Scooter` · `$8` · at the door.
  static LiveTrackingRepository arrivalAtDoor({
    TrackingStage stage = TrackingStage.atDoor,
    double? price = 8,
  }) => ScriptedArrivalTracking(
    DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: stage,
      stageTimestamps: const <TrackingStage, DateTime>{},
      jeeber: const JeeberSummary(
        displayName: 'Karim',
        vehicleLabel: 'Scooter',
      ),
      price: price,
      currency: 'USD',
    ),
  );

  /// Cubit mounted above the screen, optionally pre-driven.
  static OtpHandoverCubit cubit({
    required bool isClient,
    required OtpHandoverRepository repository,
    HandoverCodeStore? codeStore,
    LiveTrackingRepository? deliveryInfo,
    Future<void> Function(OtpHandoverCubit cubit)? drive,
  }) {
    final OtpHandoverCubit cubit = OtpHandoverCubit(
      repository: repository,
      deliveryId: deliveryId,
      isClient: isClient,
      codeStore: codeStore,
      deliveryInfo: deliveryInfo,
    );
    if (drive != null) unawaited(drive(cubit));
    return cubit;
  }

  /// One rejected verify.
  static Future<void> driveWrongCode(OtpHandoverCubit cubit) =>
      cubit.submitOtp(wrongCode);

  /// Three rejected verifies to trigger escalation.
  static Future<void> driveToEscalation(OtpHandoverCubit cubit) async {
    for (int i = 0; i < 3; i++) {
      await cubit.submitOtp(wrongCode);
    }
  }

  /// Four rejected verifies with dialog dismissal.
  static Future<void> driveBeyondCap(OtpHandoverCubit cubit) async {
    for (int i = 0; i < 4; i++) {
      await cubit.submitOtp(wrongCode);
      cubit.dismissEscalate();
    }
  }

  /// Successful verify submission.
  static Future<void> driveSuccessfulSubmit(OtpHandoverCubit cubit) =>
      cubit.submitOtp(storedCode);
}

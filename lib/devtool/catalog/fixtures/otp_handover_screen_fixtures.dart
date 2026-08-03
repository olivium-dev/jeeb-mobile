import 'dart:async';

import '../../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../../features/otp_handover/domain/handover_code_store.dart';
import '../../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../../features/otp_handover/domain/otp_handover_result.dart';

/// Fake [OtpHandoverRepository] with independent fetch and submit paths.
class ScriptedOtpHandoverRepository implements OtpHandoverRepository {
  const ScriptedOtpHandoverRepository({
    this.fetchResult,
    this.fetchErrorKind,
    this.fetchStalls = false,
    this.submitErrorKind,
    this.submitStalls = false,
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
    final OtpHandoverErrorKind? kind = submitErrorKind;
    if (kind != null) {
      return Future<OtpHandoverResult>.error(OtpHandoverException(kind));
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

  /// Code already on device.
  static HandoverCodeStore codeStore([String code = storedCode]) =>
      InMemoryHandoverCodeStore(code);

  /// Cubit mounted above the screen, optionally pre-driven.
  static OtpHandoverCubit cubit({
    required bool isClient,
    required OtpHandoverRepository repository,
    HandoverCodeStore? codeStore,
    Future<void> Function(OtpHandoverCubit cubit)? drive,
  }) {
    final OtpHandoverCubit cubit = OtpHandoverCubit(
      repository: repository,
      deliveryId: deliveryId,
      isClient: isClient,
      codeStore: codeStore,
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

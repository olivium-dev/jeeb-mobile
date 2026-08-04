// Designed states for `KycRejectedScreen` (JM-043 kyc-rejected) — ONE source of

import 'dart:async';

import '../../../features/kyc/domain/kyc_contract_template.dart';
import '../../../features/kyc/domain/kyc_form_schema.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';

/// The canned reads behind every mocked `KycRejectedScreen` state.
/// Each accessor returns a FRESH gateway: `FakeKycGateway` holds a mutable
final class KycRejectedScreenFixtures {
  KycRejectedScreenFixtures._();

  /// Catalog state `Reason — ID unreadable`.
  static KycGateway idUnreadable() =>
      _rejectedWith(KycRejectionReason.idUnreadable);

  /// Catalog state `Reason — selfie mismatch`.
  static KycGateway selfieMismatch() =>
      _rejectedWith(KycRejectionReason.selfieMismatch);

  /// Catalog state `Reason — document expired`.
  static KycGateway expired() => _rejectedWith(KycRejectionReason.expired);

  /// Catalog state `Reason — other/generic`.
  static KycGateway other() => _rejectedWith(KycRejectionReason.other);

  /// Rejected, but the back-office attached no structured cause.
  /// The closest thing this screen has to an empty state: the decision is real
  static KycGateway rejectedWithoutReason() => FakeKycGateway(
        initial: const KycSubmission(status: KycStatus.rejected),
      );

  /// A submission that is NOT rejected but still carries a reason.
  /// `KycStatus.resubmitRequested` is the tri-state third path (E19/Q-040/SM-6)
  static KycGateway resubmitRequestedWithReason() => FakeKycGateway(
        initial: const KycSubmission(
          status: KycStatus.resubmitRequested,
          rejectionReason: KycRejectionReason.idUnreadable,
          resubmitSteps: <KycResubmitStep>[KycResubmitStep.selfie],
        ),
      );

  /// `GET /v1/kyc/status` failed — the cubit's `error` branch.
  static KycGateway failing() => const KycRejectedScreenFailingGateway();

  /// `GET /v1/kyc/status` is still on the wire and never lands — the cubit's
  /// opening `loading` phase, held open.
  static KycGateway pending() => const KycRejectedScreenPendingGateway();

  static KycGateway _rejectedWith(KycRejectionReason reason) => FakeKycGateway(
        initial: KycSubmission(
          status: KycStatus.rejected,
          rejectionReason: reason,
        ),
      );
}

/// Thrown by [KycRejectedScreenFailingGateway] so a failed read is a typed
/// object rather than a bare `Exception` — the cubit catches everything, but a
/// named type says which failure the fixture means.
class KycRejectedScreenStatusReadFailure implements Exception {
  const KycRejectedScreenStatusReadFailure();

  @override
  String toString() => 'KycRejectedScreenStatusReadFailure(GET /v1/kyc/status)';
}

/// Fails every `fetchStatus()` read.
/// The other four `KycGateway` members are unreachable from this screen —
/// `KycRejectedCubit` calls `fetchStatus()` and nothing else — so they throw
class KycRejectedScreenFailingGateway implements KycGateway {
  const KycRejectedScreenFailingGateway();

  @override
  Future<KycSubmission> fetchStatus() async =>
      throw const KycRejectedScreenStatusReadFailure();

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) =>
      throw UnsupportedError('kyc-rejected never fetches the form schema');

  @override
  Future<KycContractTemplate> fetchContractTemplate() =>
      throw UnsupportedError('kyc-rejected never fetches the ToS template');

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) =>
      throw UnsupportedError('kyc-rejected never signs the ToS');

  @override
  Future<KycSubmission> submit(KycSubmission draft) =>
      throw UnsupportedError('kyc-rejected is FINAL — it never submits (D52)');
}

/// A `fetchStatus()` read that never lands, holding the cubit on
/// `KycRejectedStatus.loading` for as long as the surface is open.
/// The screen paints no spinner in that phase, so nothing schedules frames and
class KycRejectedScreenPendingGateway implements KycGateway {
  const KycRejectedScreenPendingGateway();

  @override
  Future<KycSubmission> fetchStatus() => Completer<KycSubmission>().future;

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) =>
      throw UnsupportedError('kyc-rejected never fetches the form schema');

  @override
  Future<KycContractTemplate> fetchContractTemplate() =>
      throw UnsupportedError('kyc-rejected never fetches the ToS template');

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) =>
      throw UnsupportedError('kyc-rejected never signs the ToS');

  @override
  Future<KycSubmission> submit(KycSubmission draft) =>
      throw UnsupportedError('kyc-rejected is FINAL — it never submits (D52)');
}

// Designed states for `KycRejectedScreen` (JM-043 kyc-rejected) — ONE source of
// truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_05_entries.dart
//       the designer-facing, on-device Screen Catalog
//   lib/features/kyc_rejected/presentation/kyc_rejected_screen.dart
//       the JEEB PREVIEWS section at its bottom
//
// The catalog owned four inline `FakeKycGateway(initial: KycSubmission(...))`
// literals, one per [KycRejectionReason]. They moved here whole: [idUnreadable],
// [selfieMismatch], [expired] and [other] ARE those four, value for value, so
// the designer still signs off on exactly what was signed off before. The rest
// of this file is preview-only — a fixture file is the union of what both
// surfaces need, not the intersection.
//
// ## The screen has exactly ONE seam, and every state drives it
//
// `KycRejectedScreen` takes a `gateway:` constructor override
// (40_GUARDRAILS_ARCH §5.4) and builds its own `KycRejectedCubit(...)..load()`
// at mount. There is no cubit seed, so a state is expressible here only if the
// real `load()` can reach it. That bounds the set to three:
//
//  * `loaded` with a reason — a gateway answering a [KycStatus.rejected]
//    submission that carries a `rejectionReason`;
//  * `loaded` with NO reason — either a rejected submission whose
//    `rejectionReason` is null, or ANY non-rejected submission, because
//    `KycRejectedCubit.load()` passes `clearRejectionReason:
//    submission.status != KycStatus.rejected`;
//  * `error` — a gateway whose `fetchStatus()` throws;
//  * `loading` — a gateway whose future never completes.
//
// The last three are indistinguishable on screen: `_RejectionReasonSection`
// renders `SizedBox.shrink()` whenever `state.rejectionReason == null`, which
// is deliberate (the FINAL copy must never wait on the status fetch) and is
// why the preview section pins those cards by caption rather than by copy.
//
// ## Network-free by construction
//
// Every gateway here answers from a `const` object, throws, or never completes.
// None builds a Dio client or touches GetIt — `KycRejectedScreen._resolveGateway`
// is never reached because both surfaces pass `gateway:` — so neither dev
// surface depends on the `CatalogNetworkGuard` its host installs. That is a net,
// not the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import '../../../features/kyc/domain/kyc_contract_template.dart';
import '../../../features/kyc/domain/kyc_form_schema.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';

/// The canned reads behind every mocked `KycRejectedScreen` state.
///
/// Each accessor returns a FRESH gateway: `FakeKycGateway` holds a mutable
/// `_stored` submission, and two surfaces sharing one instance would share that
/// slot. Nothing here submits, so the mutation never fires — but a factory costs
/// nothing and removes the question.
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
  ///
  /// The closest thing this screen has to an empty state: the decision is real
  /// and FINAL, and `_RejectionReasonSection` collapses to nothing.
  static KycGateway rejectedWithoutReason() => FakeKycGateway(
        initial: const KycSubmission(status: KycStatus.rejected),
      );

  /// A submission that is NOT rejected but still carries a reason.
  ///
  /// `KycStatus.resubmitRequested` is the tri-state third path (E19/Q-040/SM-6)
  /// and the kyc-service makes a reason mandatory on `request_resubmit` too, so
  /// this payload is one the wire really produces. `KycRejectedCubit.load()`
  /// drops the reason (`clearRejectionReason: status != rejected`), leaving the
  /// FINAL copy over an actionable decision.
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
///
/// The other four `KycGateway` members are unreachable from this screen —
/// `KycRejectedCubit` calls `fetchStatus()` and nothing else — so they throw
/// rather than answer, which turns any future widening of the cubit into a loud
/// failure instead of a silent canned response.
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
///
/// The screen paints no spinner in that phase, so nothing schedules frames and
/// `pumpAndSettle` still settles — the card is simply the FINAL copy with the
/// reason slot collapsed.
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

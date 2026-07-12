import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/text/digit_normalization.dart';
import '../../photo_attachment/domain/photo_attachment.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/kyc_gateway.dart';
import '../domain/kyc_submission.dart';
import 'kyc_wizard_state.dart';

/// Drives the KYC identity wizard: schema load → identity capture → submit.
///
/// On construction the cubit starts in [KycWizardStep.schema] and immediately
/// kicks off [loadSchema] (via [loadStatus]). If the schema load fails the user
/// is shown an error with a retry button.
///
/// JM-040 (D20): the Vehicle step was removed. The single [KycWizardStep.identity]
/// screen now collects gov-ID front/back + selfie + ToS acceptance, and a single
/// [submit] signs the ToS and POSTs the KYC submission. On a FRESH success the
/// state carries [KycWizardState.justSubmitted] so the screen can chain to
/// `onboarding-funding` (JM-041) rather than render the standalone status view.
class KycWizardCubit extends Cubit<KycWizardState> {
  KycWizardCubit({
    required PhotoPickerService pickerService,
    KycGateway? gateway,
    PhotoCompressor compressor = const HalvingPhotoCompressor(),
  })  : _pickerService = pickerService,
        _gateway = gateway ?? FakeKycGateway(),
        _compressor = compressor,
        super(const KycWizardState());

  final PhotoPickerService _pickerService;
  final KycGateway _gateway;
  final PhotoCompressor _compressor;

  int _nextId = 0;

  // ── Schema load ──────────────────────────────────────────────────────────

  Future<void> loadSchema() async {
    emit(state.copyWith(step: KycWizardStep.schema, clearError: true));
    try {
      final schema = await _gateway.fetchFormSchema();
      emit(state.copyWith(formSchema: schema, step: KycWizardStep.identity));
    } catch (_) {
      emit(state.copyWith(error: KycWizardError.schemaLoadFailed));
    }
  }

  // ── Status (cold-start re-read) ──────────────────────────────────────────

  Future<void> loadStatus() async {
    emit(state.copyWith(isLoadingStatus: true, clearError: true));
    final snapshot = await _gateway.fetchStatus();
    if (snapshot.status == KycStatus.notSubmitted) {
      await loadSchema();
      return;
    }
    emit(state.copyWith(
      isLoadingStatus: false,
      submission: snapshot,
      step: KycWizardStep.status,
    ));
  }

  // ── Status refresh (poll while pending) ───────────────────────────────────

  /// JEBV4-271 / JEBV4-279: quietly re-reads KYC status so a `pending → approved`
  /// flip is picked up with NO re-login and NO dependence on an FCM push (the
  /// gateway push path is unreliable, bug JEBV4-281).
  ///
  /// On MSI the gateway auto-approves INLINE — the `POST /v1/kyc/submit` RESPONSE
  /// already carries `state: "Verified"`, so the wizard normally lands straight on
  /// the approved body (which fires [JeeberRoleActivator]). But auto-approve is
  /// best-effort server-side (`KycSubmissionBffController.TryAutoApproveAsync`
  /// swallows any upstream blip and returns the still-`Submitted` state), and an
  /// idempotent replay or a slower admin approval can likewise leave the caller on
  /// `pending`. [KycStatusView] therefore polls this on a timer + on app-resume;
  /// the moment the status turns `approved` the cubit emits it, the approved body
  /// renders, and the jeeber goes online via `POST /v1/users/me/role/switch`.
  ///
  /// Fail-soft and quiet: a transient fetch error is swallowed (the poller just
  /// retries) and — unlike [loadStatus] — it never toggles
  /// [KycWizardState.isLoadingStatus], so the pending body never flickers. It
  /// emits only on a real status change, and a `notSubmitted` read never regresses
  /// an already-shown submission.
  Future<void> refreshStatus() async {
    if (state.step == KycWizardStep.submitting) return;
    final KycSubmission snapshot;
    try {
      snapshot = await _gateway.fetchStatus();
    } catch (_) {
      return;
    }
    if (snapshot.status == state.submission.status) return;
    if (snapshot.status == KycStatus.notSubmitted) return;
    emit(state.copyWith(
      submission: snapshot,
      step: KycWizardStep.status,
    ));
  }

  // ── Submit safety-net (poll while STUCK on the submitting spinner) ─────────

  /// JEBV4-259/271 safety-net for a STALLED [submit]: when the in-flight
  /// `submit()` future never completes — a half-open CDN-upload socket, or a
  /// `POST /v1/kyc/submit` whose 201 response the client never receives even
  /// though the gateway already auto-approved it (`Verified`) — the wizard is
  /// stranded on [KycWizardStep.submitting] with nothing polling ([refreshStatus]
  /// deliberately no-ops while submitting, and [KycStatusView]'s poller only
  /// mounts once we reach [KycWizardStep.status]). [KycSubmittingView] drives
  /// this out-of-band once the spinner outlives a short grace window.
  ///
  /// It re-reads `GET /v1/kyc/status`; if the SERVER already recorded the
  /// submission (anything but [KycStatus.notSubmitted]) the local future is hung,
  /// so it advances the wizard off the spinner onto the [status] step. On an
  /// auto-approved `Verified` that renders [KycStatusView]'s approved body, which
  /// fires [JeeberRoleActivator] (`POST /v1/users/me/role/switch`) and brings the
  /// jeeber online — the SAME self-heal a force-stop+relaunch achieves via
  /// [loadStatus], but with NO force-stop and NO re-login.
  ///
  /// Fail-soft: a transient fetch error is swallowed (the poller retries) and a
  /// `notSubmitted` read (submit hasn't reached the server yet) never advances.
  /// The step is re-checked after the await so a `submit()` that completed
  /// meanwhile wins the race. [justSubmitted] stays false so a recovered submit
  /// lands on the in-wizard status view (whose own poller tracks a later
  /// approval) instead of silently chaining to `onboarding-funding`.
  Future<void> refreshWhileSubmitting() async {
    if (state.step != KycWizardStep.submitting) return;
    final KycSubmission snapshot;
    try {
      snapshot = await _gateway.fetchStatus();
    } catch (_) {
      return;
    }
    if (state.step != KycWizardStep.submitting) return;
    if (snapshot.status == KycStatus.notSubmitted) return;
    emit(state.copyWith(
      step: KycWizardStep.status,
      submission: snapshot,
      justSubmitted: false,
    ));
  }

  // ── Capture ──────────────────────────────────────────────────────────────

  Future<void> captureIdFront() => _capture(KycCaptureSlot.idFront);
  Future<void> captureIdBack() => _capture(KycCaptureSlot.idBack);
  Future<void> captureSelfie() => _capture(KycCaptureSlot.selfie);

  // ── Identity fields (inline on the identity screen) ───────────────────────

  /// Records the identity-document type picked on the identity screen. Sent
  /// as the REQUIRED `id_type` on submit (E3/JEBV4-197 — ratified set
  /// {national_id, passport, residency}). Switching type keeps the typed
  /// number (validation re-evaluates against the new type) and clears any
  /// inline field error.
  void setIdType(KycIdType type) {
    if (type == state.submission.idType) return;
    emit(state.copyWith(
      submission: state.submission.copyWith(idType: type),
      clearError: true,
      clearSubmitFieldError: true,
    ));
  }

  /// Records the identity-document number typed on the identity screen. Sent
  /// as the REQUIRED `id_number` on submit (E3/JEBV4-197); the live BFF
  /// enforces `^\d{12}$` for `national_id`. Eastern Arabic-Indic digits from
  /// Arabic keyboards are normalized to ASCII defensively (the input field
  /// already normalizes as-you-type; this keeps the domain value canonical no
  /// matter how it arrives).
  void setIdNumber(String value) {
    final trimmed = normalizeArabicIndicDigits(value).trim();
    if (trimmed == (state.submission.idNumber ?? '')) return;
    emit(state.copyWith(
      submission: state.submission.copyWith(idNumber: trimmed),
      clearError: true,
      clearSubmitFieldError: true,
    ));
  }

  // ── ToS acceptance (inline on the identity screen) ────────────────────────

  void setTosAccepted(bool accepted) {
    if (accepted == state.tosAccepted) return;
    emit(state.copyWith(tosAccepted: accepted, clearError: true));
  }

  // ── Submit (sign ToS + POST submission) ───────────────────────────────────

  /// Signs the ToS then POSTs the KYC submission. Loads the contract template
  /// lazily if it hasn't been fetched yet. On success the state flips to
  /// [KycWizardStep.status] AND sets [KycWizardState.justSubmitted] so a fresh
  /// submit chains to `onboarding-funding`. Re-renders the identity screen with
  /// a [KycWizardError.submitFailed] on failure (draft preserved).
  ///
  /// The photo captures are NOT a hard client gate — the back-office is the
  /// source of truth for KYC completeness and will reject an incomplete
  /// submission (this mirrors the JM-051 mark-delivered convention where the
  /// camera evidence is optional client-side). The ID NUMBER, however, IS a
  /// hard client gate (E3/JEBV4-197 makes it contract-required for every id
  /// type): a blank/invalid `id_number` never reaches the network — the gate
  /// re-renders the identity screen with the failure inline on the field.
  /// An in-flight submit is also guarded to prevent double-posting.
  Future<void> submit() async {
    if (state.step == KycWizardStep.submitting) return;
    if (!state.submission.hasValidIdNumber) {
      emit(state.copyWith(
        step: KycWizardStep.identity,
        submitFieldError: KycSubmitFieldError.idNumber,
        clearError: true,
      ));
      return;
    }
    emit(state.copyWith(
      step: KycWizardStep.submitting,
      clearError: true,
      clearSubmitFieldError: true,
    ));
    try {
      final template = state.contractTemplate ??
          await _gateway.fetchContractTemplate();
      final stamp = await _gateway.signContract(
        templateId: template.templateId,
        tosVersion: template.tosVersion,
        signatureBlob: _tosAcceptanceBlob,
      );
      // Thread the freshly-signed ToS version onto the draft so the gateway
      // can carry `tos_accepted_version` in the submit body (JEBV4-113).
      final updated = await _gateway.submit(
        state.submission.copyWith(
          status: KycStatus.notSubmitted,
          tosAcceptedVersion: stamp.tosAcceptedVersion,
        ),
      );
      emit(state.copyWith(
        step: KycWizardStep.status,
        submission: updated,
        contractTemplate: template,
        tosAcceptedVersion: stamp.tosAcceptedVersion,
        // JEBV4-271: an AUTO-APPROVED submit (gateway returns state:Verified →
        // KycStatus.approved) must NOT chain to `onboarding-funding`; it stays
        // on the in-wizard status step so KycStatusView renders the approved
        // body, which fires JeeberRoleActivator (POST /v1/users/me/role/switch,
        // re-mints the jeeber-capable token) and the jeeber goes online with NO
        // re-login. Only a still-pending submit chains to funding.
        justSubmitted: updated.status != KycStatus.approved,
      ));
    } on KycSubmitFieldException catch (e) {
      // The BFF rejected a specific field (RFC-7807 `field` extension).
      // Surface it INLINE on the offending field — not the generic snackbar.
      // Unknown field names fall back to the generic surface so the failure
      // is never silent. (state.error is already null here — cleared at
      // submit start — so the known-field branch adds no snackbar.)
      final fieldError = _mapFieldError(e.field);
      emit(state.copyWith(
        step: KycWizardStep.identity,
        submitFieldError: fieldError,
        error: fieldError == null ? KycWizardError.submitFailed : null,
      ));
    } catch (_) {
      emit(state.copyWith(
        step: KycWizardStep.identity,
        error: KycWizardError.submitFailed,
      ));
    }
  }

  /// Maps the BFF's snake_case `field` extension to the inline-error surface.
  static KycSubmitFieldError? _mapFieldError(String field) {
    switch (field) {
      case 'id_number':
        return KycSubmitFieldError.idNumber;
      case 'id_type':
        return KycSubmitFieldError.idType;
      default:
        return null;
    }
  }

  /// Acknowledges that the presentation layer has consumed the one-shot
  /// [KycWizardState.justSubmitted] navigation signal so it does not re-fire.
  void acknowledgeNavigation() {
    if (!state.justSubmitted) return;
    emit(state.copyWith(justSubmitted: false));
  }

  // ── Resubmit after rejection ─────────────────────────────────────────────
  //
  // Kept for the standalone status view's appeal path; the rejected screen
  // (JM-043) is appeal-only (D52/D87), but tests + the in-wizard status view
  // still exercise a reset-to-capture.

  void resubmit() {
    emit(state.copyWith(
      step: KycWizardStep.schema,
      submission: const KycSubmission(status: KycStatus.notSubmitted),
      tosAccepted: false,
      clearCapturing: true,
      clearError: true,
      clearSubmitFieldError: true,
      clearTosVersion: true,
      justSubmitted: false,
    ));
    loadSchema();
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  // The signature pad was replaced by a single ToS-acceptance checkbox on the
  // identity screen (JM-040). The mock K1 `sign` endpoint still wants a
  // non-empty signature_blob, so we send a deterministic acceptance marker.
  static const String _tosAcceptanceBlob = 'tos-accepted';

  Future<void> _capture(KycCaptureSlot slot) async {
    if (state.isCapturing) return;
    emit(state.copyWith(capturing: slot, clearError: true));
    try {
      final raw = await _pickerService.pickFromCamera();
      final compressed = await _compressor.compress(raw.bytes);
      if (compressed.length > PhotoCompressor.maxSizeBytes) {
        emit(state.copyWith(
          clearCapturing: true,
          error: KycWizardError.compressionFailed,
        ));
        return;
      }
      final attachment = PhotoAttachment(
        id: 'kyc-${slot.name}-${_nextId++}',
        bytes: compressed,
        originalSizeBytes: raw.bytes.length,
        source: raw.source,
      );
      emit(state.copyWith(
        submission: _applySlot(slot, attachment),
        clearCapturing: true,
      ));
    } on PhotoPickException catch (e) {
      emit(state.copyWith(
        clearCapturing: true,
        error: _mapPickFailure(e.failure),
      ));
    } catch (_) {
      emit(state.copyWith(
        clearCapturing: true,
        error: KycWizardError.unavailable,
      ));
    }
  }

  KycSubmission _applySlot(KycCaptureSlot slot, PhotoAttachment photo) {
    switch (slot) {
      case KycCaptureSlot.idFront:
        return state.submission.copyWith(idFront: photo);
      case KycCaptureSlot.idBack:
        return state.submission.copyWith(idBack: photo);
      case KycCaptureSlot.selfie:
        return state.submission.copyWith(selfie: photo);
    }
  }

  KycWizardError _mapPickFailure(PhotoPickFailure failure) {
    switch (failure) {
      case PhotoPickFailure.cancelled:
        return KycWizardError.pickCancelled;
      case PhotoPickFailure.permissionDenied:
        return KycWizardError.permissionDenied;
      case PhotoPickFailure.unavailable:
        return KycWizardError.unavailable;
    }
  }
}

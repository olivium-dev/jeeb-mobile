import 'package:flutter_bloc/flutter_bloc.dart';

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

  // ── Capture ──────────────────────────────────────────────────────────────

  Future<void> captureIdFront() => _capture(KycCaptureSlot.idFront);
  Future<void> captureIdBack() => _capture(KycCaptureSlot.idBack);
  Future<void> captureSelfie() => _capture(KycCaptureSlot.selfie);

  // ── Identity fields (inline on the identity screen) ───────────────────────

  /// Records the national-ID number typed on the identity screen. Sent as the
  /// REQUIRED `id_number` on submit (E3/JEBV4-197); the live BFF enforces
  /// `^\d{12}$` for `national_id`.
  void setIdNumber(String value) {
    final trimmed = value.trim();
    if (trimmed == (state.submission.idNumber ?? '')) return;
    emit(state.copyWith(
      submission: state.submission.copyWith(idNumber: trimmed),
      clearError: true,
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
  /// camera evidence is optional client-side). Only an in-flight submit is
  /// guarded to prevent double-posting.
  Future<void> submit() async {
    if (state.step == KycWizardStep.submitting) return;
    emit(state.copyWith(step: KycWizardStep.submitting, clearError: true));
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
        justSubmitted: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        step: KycWizardStep.identity,
        error: KycWizardError.submitFailed,
      ));
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

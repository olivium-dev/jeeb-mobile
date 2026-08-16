import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diagnostics.dart';
import '../../../core/text/digit_normalization.dart';
import '../../photo_attachment/domain/photo_attachment.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/kyc_contract_template.dart';
import '../domain/kyc_gateway.dart';
import '../domain/kyc_submission.dart';
import 'kyc_wizard_state.dart';

/// KYC identity wizard: schema load → capture → submit.
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

  /// Must clear loadingStatus; fresh jeeber entering identity wizard.
  Future<void> loadSchema() async {
    emit(state.copyWith(
      step: KycWizardStep.schema,
      isLoadingStatus: false,
      clearError: true,
    ));
    try {
      final schema = await _gateway.fetchFormSchema();
      emit(state.copyWith(formSchema: schema, step: KycWizardStep.identity));
    } catch (_) {
      emit(state.copyWith(error: KycWizardError.schemaLoadFailed));
    }
  }

  Future<void> loadStatus() async {
    emit(state.copyWith(isLoadingStatus: true, clearError: true));
    final snapshot = await _gateway.fetchStatus();
    Diag.event('kyc_load_status', {'status': snapshot.status.name});
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

  /// JEBV4-259/271: safety-net for stalled submit (half-open socket, etc).
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

  /// OUT-OF-BAND signal: jeeber role granted (GET /v1/users/me shows jeeber).
  void onJeeberRoleGranted() {
    final step = state.step;
    if (step != KycWizardStep.submitting && step != KycWizardStep.status) {
      return;
    }
    final status = state.submission.status;
    if (status == KycStatus.approved || status == KycStatus.rejected) return;
    emit(state.copyWith(
      step: KycWizardStep.status,
      submission: state.submission.copyWith(status: KycStatus.approved),
      justSubmitted: false,
    ));
  }

  Future<void> captureIdFront() => _capture(KycCaptureSlot.idFront);
  Future<void> captureIdBack() => _capture(KycCaptureSlot.idBack);
  Future<void> captureSelfie() => _capture(KycCaptureSlot.selfie);

  void setIdType(KycIdType type) {
    if (type == state.submission.idType) return;
    emit(state.copyWith(
      submission: state.submission.copyWith(idType: type),
      clearError: true,
      clearSubmitFieldError: true,
    ));
  }

  void setIdNumber(String value) {
    final trimmed = normalizeArabicIndicDigits(value).trim();
    if (trimmed == (state.submission.idNumber ?? '')) return;
    emit(state.copyWith(
      submission: state.submission.copyWith(idNumber: trimmed),
      clearError: true,
      clearSubmitFieldError: true,
    ));
  }

  void setTosAccepted(bool accepted) {
    if (accepted == state.tosAccepted) return;
    emit(state.copyWith(tosAccepted: accepted, clearError: true));
  }

  /// Sign ToS, POST KYC submission. Fetches contract template lazily if needed.
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
    // D17: the three submit phases fail for different reasons and must say so.
    // Collapsing them blamed the user's connection for a server-side missing
    // ToS template, and left contractLoadFailed/signFailed unreachable.
    final KycContractTemplate template;
    try {
      template =
          state.contractTemplate ?? await _gateway.fetchContractTemplate();
    } catch (_) {
      Diag.event('kyc_contract_template_error');
      emit(state.copyWith(
        step: KycWizardStep.identity,
        error: KycWizardError.contractLoadFailed,
      ));
      return;
    }

    final KycSignStamp stamp;
    try {
      stamp = await _gateway.signContract(
        templateId: template.templateId,
        tosVersion: template.tosVersion,
        signatureBlob: _tosAcceptanceBlob,
      );
    } catch (_) {
      Diag.event('kyc_tos_sign_error');
      emit(state.copyWith(
        step: KycWizardStep.identity,
        contractTemplate: template,
        error: KycWizardError.signFailed,
      ));
      return;
    }

    try {
      final updated = await _gateway.submit(
        state.submission.copyWith(
          status: KycStatus.notSubmitted,
          tosAcceptedVersion: stamp.tosAcceptedVersion,
        ),
      );
      Diag.event('kyc_submit_success', {
        'status': updated.status.name,
        'isLoadingStatus': state.isLoadingStatus,
      });
      emit(state.copyWith(
        step: KycWizardStep.status,
        submission: updated,
        contractTemplate: template,
        tosAcceptedVersion: stamp.tosAcceptedVersion,
        // approved must NOT chain to onboarding-funding; stays in status.
        justSubmitted: updated.status != KycStatus.approved,
      ));
    } on KycSubmitFieldException catch (e) {
      final fieldError = _mapFieldError(e.field);
      emit(state.copyWith(
        step: KycWizardStep.identity,
        submitFieldError: fieldError,
        error: fieldError == null
            ? KycWizardError.submitValidationFailed
            : null,
      ));
    } catch (_) {
      Diag.event('kyc_submit_error');
      if (await _reconcileTerminalStatus()) return;
      emit(state.copyWith(
        step: KycWizardStep.identity,
        error: KycWizardError.submitFailed,
      ));
    }
  }

  /// Re-read status after failed submit; if server recorded it, reconcile state.
  Future<bool> _reconcileTerminalStatus() async {
    final KycSubmission snapshot;
    try {
      snapshot = await _gateway.fetchStatus();
    } catch (_) {
      return false;
    }
    if (snapshot.status == KycStatus.notSubmitted) return false;
    emit(state.copyWith(
      step: KycWizardStep.status,
      submission: snapshot,
      justSubmitted: false,
    ));
    return true;
  }

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

  void acknowledgeNavigation() {
    if (!state.justSubmitted) return;
    emit(state.copyWith(justSubmitted: false));
  }

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

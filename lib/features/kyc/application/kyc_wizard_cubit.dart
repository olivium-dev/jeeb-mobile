import 'package:flutter_bloc/flutter_bloc.dart';

import '../../photo_attachment/domain/photo_attachment.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/kyc_gateway.dart';
import '../domain/kyc_submission.dart';
import '../domain/vehicle_type.dart';
import 'kyc_wizard_state.dart';

/// Drives the KYC wizard: schema load → ID → selfie → vehicle → ToS → submit.
///
/// On construction the cubit starts in [KycWizardStep.schema] and immediately
/// kicks off [_loadSchema]. If the schema load fails the user is shown an error
/// with a retry button.
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
      emit(state.copyWith(formSchema: schema, step: KycWizardStep.id));
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

  // ── Navigation ───────────────────────────────────────────────────────────

  void goToSelfie() {
    if (!state.canAdvanceFromId) return;
    emit(state.copyWith(step: KycWizardStep.selfie, clearError: true));
  }

  void goToVehicle() {
    if (!state.canAdvanceFromSelfie) return;
    emit(state.copyWith(step: KycWizardStep.vehicle, clearError: true));
  }

  void goToTos() {
    if (!state.canAdvanceFromVehicle) return;
    _loadContractTemplate();
  }

  void goBack() {
    switch (state.step) {
      case KycWizardStep.schema:
      case KycWizardStep.id:
      case KycWizardStep.submitting:
      case KycWizardStep.status:
        return;
      case KycWizardStep.selfie:
        emit(state.copyWith(step: KycWizardStep.id, clearError: true));
        break;
      case KycWizardStep.vehicle:
        emit(state.copyWith(step: KycWizardStep.selfie, clearError: true));
        break;
      case KycWizardStep.tos:
        emit(state.copyWith(step: KycWizardStep.vehicle, clearError: true));
        break;
    }
  }

  // ── Vehicle fields ───────────────────────────────────────────────────────

  void setVehicleType(VehicleType type) {
    emit(state.copyWith(
      submission: state.submission.copyWith(vehicleType: type),
      clearError: true,
    ));
  }

  void setVehicleRegistration(String value) {
    emit(state.copyWith(
      submission: state.submission.copyWith(vehicleRegistration: value),
      clearError: state.error == KycWizardError.vehicleRegistrationRequired,
    ));
  }

  // ── ToS contract ─────────────────────────────────────────────────────────

  Future<void> _loadContractTemplate() async {
    emit(state.copyWith(step: KycWizardStep.tos, clearError: true));
    if (state.contractTemplate != null) return;
    try {
      final template = await _gateway.fetchContractTemplate();
      emit(state.copyWith(contractTemplate: template));
    } catch (_) {
      emit(state.copyWith(error: KycWizardError.contractLoadFailed));
    }
  }

  Future<void> signAndSubmit(String signatureBlob) async {
    final template = state.contractTemplate;
    if (template == null) return;
    if (state.step == KycWizardStep.submitting) return;
    emit(state.copyWith(step: KycWizardStep.submitting, clearError: true));
    try {
      final stamp = await _gateway.signContract(
        templateId: template.templateId,
        tosVersion: template.tosVersion,
        signatureBlob: signatureBlob,
      );
      final updated = await _gateway.submit(
        state.submission.copyWith(status: KycStatus.notSubmitted),
      );
      emit(state.copyWith(
        step: KycWizardStep.status,
        submission: updated,
        tosAcceptedVersion: stamp.tosAcceptedVersion,
      ));
    } catch (_) {
      emit(state.copyWith(
        step: KycWizardStep.tos,
        error: KycWizardError.submitFailed,
      ));
    }
  }

  // ── Legacy submit (vehicle step) ─────────────────────────────────────────

  Future<void> submit() async {
    if (state.step == KycWizardStep.submitting) return;
    if (!state.canAdvanceFromId || !state.canAdvanceFromSelfie) return;
    if (state.submission.vehicleType == null) return;
    if (state.submission.vehicleRegistration.trim().isEmpty) {
      emit(state.copyWith(error: KycWizardError.vehicleRegistrationRequired));
      return;
    }
    goToTos();
  }

  // ── Resubmit after rejection ─────────────────────────────────────────────

  void resubmit() {
    emit(state.copyWith(
      step: KycWizardStep.schema,
      submission: const KycSubmission(status: KycStatus.notSubmitted),
      clearCapturing: true,
      clearError: true,
      clearTosVersion: true,
    ));
    loadSchema();
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  // ── Private helpers ──────────────────────────────────────────────────────

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

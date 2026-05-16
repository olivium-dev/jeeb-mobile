import 'package:flutter_bloc/flutter_bloc.dart';

import '../../photo_attachment/domain/photo_attachment.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/kyc_gateway.dart';
import '../domain/kyc_submission.dart';
import '../domain/vehicle_type.dart';
import 'kyc_wizard_state.dart';

/// Drives the three-step KYC wizard (ID → selfie → vehicle), the optional
/// review step, and the final status screen.
///
/// One [KycPhotoCompressor]-respecting compressor is shared by all three
/// capture slots — there's no need for the per-slot cap that
/// [PhotoAttachmentCubit] enforces because each slot only holds a single
/// photo. The cubit refuses to advance until the prior step's photos have
/// been captured (T-mobile-006 AC).
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

  /// Monotonic counter shared by all three slots — keeps every captured
  /// attachment id unique so consumers can compare by id.
  int _nextId = 0;

  Future<void> captureIdFront() => _capture(KycCaptureSlot.idFront);
  Future<void> captureIdBack() => _capture(KycCaptureSlot.idBack);
  Future<void> captureSelfie() => _capture(KycCaptureSlot.selfie);

  /// Advances from step 1 → step 2 once both ID sides are captured. No-op
  /// otherwise so the view doesn't have to gate the call itself.
  void goToSelfie() {
    if (!state.canAdvanceFromId) return;
    emit(state.copyWith(step: KycWizardStep.selfie, clearError: true));
  }

  /// Advances from step 2 → step 3 once the selfie is captured.
  void goToVehicle() {
    if (!state.canAdvanceFromSelfie) return;
    emit(state.copyWith(step: KycWizardStep.vehicle, clearError: true));
  }

  /// Returns to the immediately-previous capture step. The status screen
  /// goes back to vehicle so the user can re-capture if needed.
  void goBack() {
    switch (state.step) {
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
    }
  }

  void setVehicleType(VehicleType type) {
    emit(state.copyWith(
      submission: state.submission.copyWith(vehicleType: type),
      clearError: true,
    ));
  }

  void setVehicleRegistration(String value) {
    emit(state.copyWith(
      submission: state.submission.copyWith(vehicleRegistration: value),
      // Clear the inline required-field error as soon as the user types.
      clearError: state.error == KycWizardError.vehicleRegistrationRequired,
    ));
  }

  /// Submits the captured data to the gateway. Validates the vehicle step
  /// inline before kicking off the request — a missing registration produces
  /// a one-shot [KycWizardError.vehicleRegistrationRequired].
  Future<void> submit() async {
    if (state.step == KycWizardStep.submitting) return;
    if (!state.canAdvanceFromId ||
        !state.canAdvanceFromSelfie ||
        state.submission.vehicleType == null) {
      return;
    }
    if (state.submission.vehicleRegistration.trim().isEmpty) {
      emit(state.copyWith(error: KycWizardError.vehicleRegistrationRequired));
      return;
    }
    emit(state.copyWith(step: KycWizardStep.submitting, clearError: true));
    try {
      final updated = await _gateway.submit(state.submission);
      emit(state.copyWith(
        step: KycWizardStep.status,
        submission: updated,
      ));
    } on Object {
      emit(state.copyWith(
        step: KycWizardStep.vehicle,
        error: KycWizardError.submitFailed,
      ));
    }
  }

  /// Resets the wizard back to step 1 so the user can re-capture after a
  /// rejection. Keeps the previously rejected status until the user actually
  /// resubmits.
  void resubmit() {
    emit(state.copyWith(
      step: KycWizardStep.id,
      submission: const KycSubmission(status: KycStatus.notSubmitted),
      clearCapturing: true,
      clearError: true,
    ));
  }

  /// Cold-load entry point used by the status screen. Pulls the most recent
  /// decision so the screen renders pending/approved/rejected across restarts.
  Future<void> loadStatus() async {
    emit(state.copyWith(isLoadingStatus: true, clearError: true));
    final snapshot = await _gateway.fetchStatus();
    emit(state.copyWith(
      isLoadingStatus: false,
      submission: snapshot,
      step: snapshot.status == KycStatus.notSubmitted
          ? KycWizardStep.id
          : KycWizardStep.status,
    ));
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

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

import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../photo_attachment/domain/photo_attachment.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/dm_onboarding_gateway.dart';
import 'dm_onboarding_state.dart';

/// Drives the three-step delivery-man onboarding wizard
/// (photo → address → service area) and the final submission.
///
/// Reuses the shared [PhotoPickerService] + [PhotoCompressor] that the KYC
/// wizard already binds, so the photo step doesn't introduce a second camera
/// stack. Each transition is a no-op when its precondition isn't met, so the
/// view never has to gate the call itself.
class DmOnboardingCubit extends Cubit<DmOnboardingState> {
  DmOnboardingCubit({
    required PhotoPickerService pickerService,
    required DmOnboardingGateway gateway,
    PhotoCompressor compressor = const HalvingPhotoCompressor(),
    DmOnboardingStep initialStep = DmOnboardingStep.photo,
  })  : _pickerService = pickerService,
        _gateway = gateway,
        _compressor = compressor,
        super(DmOnboardingState(step: initialStep));

  final PhotoPickerService _pickerService;
  final DmOnboardingGateway _gateway;
  final PhotoCompressor _compressor;
  int _nextId = 0;

  Future<void> pickFromCamera() => _pick(fromCamera: true);
  Future<void> pickFromGallery() => _pick(fromCamera: false);

  void setStateField(String value) =>
      emit(state.copyWith(state: value, clearError: true));
  void setCountry(String value) =>
      emit(state.copyWith(country: value, clearError: true));
  void setStreet(String value) =>
      emit(state.copyWith(street: value, clearError: true));
  void setVehicleNumber(String value) =>
      emit(state.copyWith(vehicleNumber: value, clearError: true));
  void setAddress(String value) =>
      emit(state.copyWith(address: value, clearError: true));

  void setPrimaryLocation(String value) =>
      emit(state.copyWith(primaryLocation: value, clearError: true));

  void setDistanceKm(int km) =>
      emit(state.copyWith(distanceKm: km.clamp(
        DmOnboardingState.minDistanceKm,
        DmOnboardingState.maxDistanceKm,
      )));

  /// Advances to the next step, or submits when on the final step.
  Future<void> next() async {
    switch (state.step) {
      case DmOnboardingStep.photo:
        emit(state.copyWith(step: DmOnboardingStep.address, clearError: true));
      case DmOnboardingStep.address:
        emit(state.copyWith(
          step: DmOnboardingStep.serviceArea,
          clearError: true,
        ));
      case DmOnboardingStep.serviceArea:
        await _submit();
    }
  }

  /// Returns to the previous step. Photo is the first step → no-op.
  void back() {
    switch (state.step) {
      case DmOnboardingStep.photo:
        return;
      case DmOnboardingStep.address:
        emit(state.copyWith(step: DmOnboardingStep.photo, clearError: true));
      case DmOnboardingStep.serviceArea:
        emit(state.copyWith(step: DmOnboardingStep.address, clearError: true));
    }
  }

  Future<void> _submit() async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _gateway.submit(_draft());
      emit(state.copyWith(isSubmitting: false, isSubmitted: true));
    } on Object {
      emit(state.copyWith(
        isSubmitting: false,
        error: DmOnboardingError.submitFailed,
      ));
    }
  }

  DmOnboardingSubmission _draft() => DmOnboardingSubmission(
        state: state.state,
        country: state.country,
        street: state.street,
        vehicleNumber: state.vehicleNumber,
        address: state.address,
        primaryLocation: state.primaryLocation,
        distanceKm: state.distanceKm,
      );

  Future<void> _pick({required bool fromCamera}) async {
    try {
      final raw = fromCamera
          ? await _pickerService.pickFromCamera()
          : await _pickerService.pickFromGallery();
      final compressed = await _compressor.compress(raw.bytes);
      emit(state.copyWith(photo: _attachmentFrom(raw, compressed)));
    } on PhotoPickException catch (e) {
      _surfacePickFailure(e.failure);
    } catch (_) {
      emit(state.copyWith(error: DmOnboardingError.photoPickFailed));
    }
  }

  PhotoAttachment _attachmentFrom(RawPhoto raw, Uint8List compressed) {
    return PhotoAttachment(
      id: 'dm-onboarding-photo-${_nextId++}',
      bytes: compressed,
      originalSizeBytes: raw.bytes.length,
      source: raw.source,
    );
  }

  void _surfacePickFailure(PhotoPickFailure failure) {
    if (failure == PhotoPickFailure.cancelled) return;
    emit(state.copyWith(error: DmOnboardingError.photoPickFailed));
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }
}

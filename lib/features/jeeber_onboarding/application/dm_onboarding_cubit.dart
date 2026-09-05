import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../../kyc/domain/cdn_asset_gateway.dart';
import '../../photo_attachment/domain/photo_attachment.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/dm_onboarding_gateway.dart';
import 'dm_onboarding_state.dart';

class DmOnboardingCubit extends Cubit<DmOnboardingState> {
  DmOnboardingCubit({
    required PhotoPickerService pickerService,
    required DmOnboardingGateway gateway,
    CdnAssetGateway? cdn,
    PhotoCompressor compressor = const HalvingPhotoCompressor(),
    DmOnboardingStep initialStep = DmOnboardingStep.photo,
  })  : _pickerService = pickerService,
        _gateway = gateway,
        _cdn = cdn,
        _compressor = compressor,
        super(DmOnboardingState(step: initialStep));

  final PhotoPickerService _pickerService;
  final DmOnboardingGateway _gateway;

  /// UX-06: uploads the portrait so it reaches the DTO. Null in a bare
  /// harness, where the upload is skipped.
  final CdnAssetGateway? _cdn;

  final PhotoCompressor _compressor;
  int _nextId = 0;

  /// One idempotency scope per submission attempt chain.
  String? _submitOperationId;

  Future<void> pickFromCamera() => _pick(fromCamera: true);
  Future<void> pickFromGallery() => _pick(fromCamera: false);

  void setStateField(String value) =>
      emit(state.copyWith(state: value, clearError: true));
  void setCountry(String value) =>
      emit(state.copyWith(country: value, clearError: true));
  void setStreet(String value) =>
      emit(state.copyWith(street: value, clearError: true));
  void setAddress(String value) =>
      emit(state.copyWith(address: value, clearError: true));

  void setHomeBase(DmOnboardingHomeBase homeBase) => emit(
        state.copyWith(homeBase: homeBase, clearError: true),
      );

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
        await _confirmCoverage();
    }
  }

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

  Future<void> _confirmCoverage() async {
    final homeBase = state.homeBase;
    if (homeBase == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    final String operationId =
        _submitOperationId ??= newOperationId();
    final String? portraitRef;
    try {
      portraitRef = await _uploadPortrait(operationId);
    } on CdnUploadException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: DmOnboardingError.photoUploadFailed,
        failure: e.failure ?? const UnknownFailure(),
      ));
      return;
    }
    try {
      await _gateway.submit(_draft(homeBase, portraitRef, operationId));
      // A landed submit closes the scope: a later resubmission must not be
      // replayed against it.
      _submitOperationId = null;
      emit(state.copyWith(isSubmitting: false, coverageReady: true));
    } on DmOnboardingOutOfCoverageException {
      emit(state.copyWith(
        isSubmitting: false,
        error: DmOnboardingError.outOfCoverage,
      ));
    } on DmOnboardingGatewayException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: DmOnboardingError.submitFailed,
        failure: e.failure,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        error: DmOnboardingError.submitFailed,
        failure: AppFailure.of(e),
      ));
    }
  }

  Future<String?> _uploadPortrait(String operationId) async {
    final cdn = _cdn;
    final photo = state.photo;
    if (cdn == null || photo == null) return null;
    return cdn is IdempotentCdnAssetGateway
        ? cdn.uploadAssetIdempotent(
            slot: CdnUploadSlot.avatar,
            bytes: photo.bytes,
            operationId: operationId,
          )
        : cdn.uploadAsset(slot: CdnUploadSlot.avatar, bytes: photo.bytes);
  }

  DmOnboardingSubmission _draft(
    DmOnboardingHomeBase homeBase,
    String? portraitObjectRef,
    String operationId,
  ) =>
      DmOnboardingSubmission(
        state: state.state,
        country: state.country,
        street: state.street,
        address: state.address,
        homeBaseLat: homeBase.lat,
        homeBaseLng: homeBase.lng,
        homeBaseLabel: homeBase.label,
        portraitObjectRef: portraitObjectRef,
        operationId: operationId,
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
    } catch (e) {
      emit(state.copyWith(
        error: DmOnboardingError.photoPickFailed,
        failure: AppFailure.of(e),
      ));
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

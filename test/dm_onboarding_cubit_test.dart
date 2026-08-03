import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

Uint8List _bytes(int length, [int fill = 0x42]) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = fill;
  }
  return out;
}

DmOnboardingCubit _buildCubit({
  PhotoPickerService? picker,
  DmOnboardingGateway? gateway,
  DmOnboardingStep initialStep = DmOnboardingStep.photo,
}) {
  final cubit = DmOnboardingCubit(
    pickerService:
        picker ?? StubPhotoPickerService(cameraPayload: _bytes(100 * 1024)),
    gateway: gateway ?? FakeDmOnboardingGateway(),
    initialStep: initialStep,
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('DmOnboardingCubit', () {
    test('starts on the photo step with no photo or home base', () {
      final cubit = _buildCubit();
      expect(cubit.state.step, DmOnboardingStep.photo);
      expect(cubit.state.hasPhoto, isFalse);
      expect(cubit.state.hasHomeBase, isFalse);
    });

    test('initialStep seeds the starting step (dev-seam deep link)', () {
      final cubit = _buildCubit(initialStep: DmOnboardingStep.serviceArea);
      expect(cubit.state.step, DmOnboardingStep.serviceArea);
      expect(cubit.state.currentStepNumber, 3);
    });

    test('camera pick stores a compressed photo', () async {
      final cubit = _buildCubit();
      await cubit.pickFromCamera();
      expect(cubit.state.hasPhoto, isTrue);
      expect(cubit.state.photo!.id, startsWith('dm-onboarding-photo-'));
    });

    test('cancelled pick surfaces no error', () async {
      final cubit = _buildCubit(
        picker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.cancelled,
        ),
      );
      await cubit.pickFromCamera();
      expect(cubit.state.error, isNull);
      expect(cubit.state.hasPhoto, isFalse);
    });

    test('camera failure surfaces a one-shot error then acknowledges', () async {
      final cubit = _buildCubit(
        picker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.unavailable,
        ),
      );
      await cubit.pickFromCamera();
      expect(cubit.state.error, DmOnboardingError.photoPickFailed);
      cubit.acknowledgeError();
      expect(cubit.state.error, isNull);
    });

    test('next advances photo → address → serviceArea', () async {
      final cubit = _buildCubit();
      await cubit.next();
      expect(cubit.state.step, DmOnboardingStep.address);
      await cubit.next();
      expect(cubit.state.step, DmOnboardingStep.serviceArea);
    });

    test('back returns to the previous step; no-op on the first step', () {
      final cubit = _buildCubit(initialStep: DmOnboardingStep.serviceArea);
      cubit.back();
      expect(cubit.state.step, DmOnboardingStep.address);
      cubit.back();
      expect(cubit.state.step, DmOnboardingStep.photo);
      cubit.back();
      expect(cubit.state.step, DmOnboardingStep.photo);
    });

    test('a pinned home base enables service-area continue gating (D51)', () {
      final cubit = _buildCubit();
      expect(cubit.state.hasHomeBase, isFalse);
      cubit.setHomeBase(
        const DmOnboardingHomeBase(lat: 33.89, lng: 35.50, label: 'Beirut'),
      );
      expect(cubit.state.hasHomeBase, isTrue);
      expect(cubit.state.homeBase!.label, 'Beirut');
    });

    test('service-area continue is a no-op until a home base is pinned',
        () async {
      final gateway = FakeDmOnboardingGateway();
      final cubit = _buildCubit(
        gateway: gateway,
        initialStep: DmOnboardingStep.serviceArea,
      );
      await cubit.next();
      expect(cubit.state.coverageReady, isFalse);
      expect(gateway.lastSubmission, isNull);
    });

    test(
        'service-area continue confirms coverage with the home base and flags '
        'coverageReady (chains to KYC, not Fake-submit)', () async {
      final gateway = FakeDmOnboardingGateway();
      final cubit = _buildCubit(
        gateway: gateway,
        initialStep: DmOnboardingStep.serviceArea,
      );
      cubit
        ..setStateField('Mount Lebanon')
        ..setAddress('12 Hamra St')
        ..setHomeBase(
          const DmOnboardingHomeBase(lat: 33.89, lng: 35.50, label: 'Beirut'),
        );
      await cubit.next();
      expect(cubit.state.coverageReady, isTrue);
      // The DTO forwards the pinned home base as the matching origin (D51).
      expect(gateway.lastSubmission!.state, 'Mount Lebanon');
      expect(gateway.lastSubmission!.address, '12 Hamra St');
      expect(gateway.lastSubmission!.homeBaseLat, 33.89);
      expect(gateway.lastSubmission!.homeBaseLng, 35.50);
    });

    test('coverage failure surfaces submitFailed and stays on the step',
        () async {
      final cubit = _buildCubit(
        gateway: FakeDmOnboardingGateway(shouldFail: true),
        initialStep: DmOnboardingStep.serviceArea,
      );
      cubit.setHomeBase(
        const DmOnboardingHomeBase(lat: 0, lng: 0, label: 'Base'),
      );
      await cubit.next();
      expect(cubit.state.coverageReady, isFalse);
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.error, DmOnboardingError.submitFailed);
    });
  });
}

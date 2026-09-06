// UX-05/UX-06/UX-40: the cubit half. The portrait was never uploaded and never
// reached the DTO, and every failure collapsed into `submitFailed`.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// Records what reached the DTO.
class _RecordingGateway implements DmOnboardingGateway {
  _RecordingGateway({this.throws});

  final Object? throws;
  DmOnboardingSubmission? last;
  final List<String?> operationIds = <String?>[];

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {
    last = submission;
    operationIds.add(submission.operationId);
    final Object? error = throws;
    if (error != null) throw error;
  }
}

/// Counts uploads and reports the operation ids it was handed.
class _RecordingCdn implements IdempotentCdnAssetGateway {
  _RecordingCdn({this.throws = false});

  final bool throws;
  final List<String> operationIds = <String>[];
  int uploads = 0;

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      uploadAssetIdempotent(
        slot: slot,
        bytes: bytes,
        operationId: 'plain',
        contentType: contentType,
      );

  @override
  Future<String> uploadAssetIdempotent({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    required String operationId,
    String contentType = 'image/jpeg',
  }) async {
    uploads++;
    operationIds.add(operationId);
    if (throws) {
      throw const CdnUploadException(
        'cdn_signed_put',
        failure: ServerFailure(status: 500),
        status: 500,
      );
    }
    return 'cdn/objects/portrait';
  }

  @override
  Future<Uint8List> fetchAsset(String objectRef) async => Uint8List(0);
}

DmOnboardingCubit _cubit(
  DmOnboardingGateway gateway, {
  CdnAssetGateway? cdn,
}) =>
    DmOnboardingCubit(
      pickerService: StubPhotoPickerService(
        cameraPayload: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
      gateway: gateway,
      cdn: cdn,
      initialStep: DmOnboardingStep.serviceArea,
    );

void _seed(DmOnboardingCubit cubit) {
  cubit
    ..setStateField('Mount Lebanon')
    ..setCountry('Lebanon')
    ..setStreet('Main St')
    ..setAddress('Bldg 4')
    ..setHomeBase(
      const DmOnboardingHomeBase(lat: 33.8938, lng: 35.5018, label: 'Beirut'),
    );
}

void main() {
  test('the portrait is uploaded ONCE and its ref reaches the DTO', () async {
    final gateway = _RecordingGateway();
    final cdn = _RecordingCdn();
    final cubit = _cubit(gateway, cdn: cdn);
    addTearDown(cubit.close);
    await cubit.pickFromCamera();
    _seed(cubit);

    await cubit.next();

    expect(cdn.uploads, 1);
    expect(gateway.last!.portraitObjectRef, 'cdn/objects/portrait');
    expect(cubit.state.coverageReady, isTrue);
  });

  test('a failed portrait upload is photoUploadFailed, never submitFailed',
      () async {
    final gateway = _RecordingGateway();
    final cubit = _cubit(gateway, cdn: _RecordingCdn(throws: true));
    addTearDown(cubit.close);
    await cubit.pickFromCamera();
    _seed(cubit);

    await cubit.next();

    expect(cubit.state.error, DmOnboardingError.photoUploadFailed);
    expect(cubit.state.error, isNot(DmOnboardingError.submitFailed));
    expect(cubit.state.failure, isA<ServerFailure>());
    expect(gateway.last, isNull, reason: 'nothing was submitted');
    expect(cubit.state.isSubmitting, isFalse);
  });

  test('out_of_coverage is its own error, not a generic submit failure',
      () async {
    final cubit = _cubit(
      _RecordingGateway(throws: const DmOnboardingOutOfCoverageException()),
    );
    addTearDown(cubit.close);
    _seed(cubit);

    await cubit.next();

    expect(cubit.state.error, DmOnboardingError.outOfCoverage);
    expect(cubit.state.coverageReady, isFalse);
  });

  test('a classified gateway failure carries its kind onto the state',
      () async {
    final cubit = _cubit(
      _RecordingGateway(
        throws: const DmOnboardingGatewayException(ServerFailure(status: 500)),
      ),
    );
    addTearDown(cubit.close);
    _seed(cubit);

    await cubit.next();

    expect(cubit.state.error, DmOnboardingError.submitFailed);
    expect(cubit.state.failure!.kind, AppFailureKind.server);
  });

  test('with NO cdn the upload is skipped and the DTO carries no ref',
      () async {
    final gateway = _RecordingGateway();
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);
    await cubit.pickFromCamera();
    _seed(cubit);

    await cubit.next();

    expect(gateway.last!.portraitObjectRef, isNull);
    expect(cubit.state.coverageReady, isTrue);
  });

  test('a retried submit reuses the SAME operation id', () async {
    final cdn = _RecordingCdn();
    final gateway = _RecordingGateway(
      throws: const DmOnboardingGatewayException(ServerFailure(status: 500)),
    );
    final cubit = _cubit(gateway, cdn: cdn);
    addTearDown(cubit.close);
    await cubit.pickFromCamera();
    _seed(cubit);

    await cubit.next();
    await cubit.next();

    expect(cdn.operationIds, hasLength(2));
    expect(cdn.operationIds.toSet(), hasLength(1));
  });

  test('the SUBMIT carries the same idempotency scope across both attempts',
      () async {
    final gateway = _RecordingGateway(
      throws: const DmOnboardingGatewayException(ServerFailure(status: 500)),
    );
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);
    _seed(cubit);

    await cubit.next();
    await cubit.next();

    expect(gateway.operationIds, hasLength(2));
    expect(gateway.operationIds.first, isNotNull);
    expect(gateway.operationIds.toSet(), hasLength(1));
  });

  test('a landed submit closes the scope — a later resubmit mints a new one',
      () async {
    final gateway = _RecordingGateway();
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);
    _seed(cubit);

    await cubit.next();
    await cubit.next();

    expect(gateway.operationIds, hasLength(2));
    expect(gateway.operationIds.toSet(), hasLength(2));
  });
}

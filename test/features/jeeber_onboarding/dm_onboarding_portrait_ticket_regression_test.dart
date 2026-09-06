import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

class _RecordingGateway implements DmOnboardingGateway {
  int submissions = 0;

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {
    submissions++;
  }
}

class _HealingCdn implements IdempotentCdnAssetGateway {
  final List<String> operationIds = <String>[];

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) => uploadAssetIdempotent(
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
    operationIds.add(operationId);
    if (operationIds.length == 1) throw StateError('ticket parser');
    return 'cdn/objects/portrait';
  }

  @override
  Future<Uint8List> fetchAsset(String objectRef) async => Uint8List(0);
}

DmOnboardingCubit _cubit(DmOnboardingGateway gateway, CdnAssetGateway cdn) =>
    DmOnboardingCubit(
      pickerService: StubPhotoPickerService(
        cameraPayload: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
      gateway: gateway,
      cdn: cdn,
      initialStep: DmOnboardingStep.serviceArea,
    );

Future<void> _prepare(DmOnboardingCubit cubit) async {
  await cubit.pickFromCamera();
  cubit.setHomeBase(
    const DmOnboardingHomeBase(lat: 33.8, lng: 35.5, label: 'Beirut'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'malformed portrait ticket releases busy and allows another attempt',
    () async {
      var brokerCalls = 0;
      final broker = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              brokerCalls++;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'upload_url': 123,
                    'object_ref': 'profile_avatar/photo.jpg',
                  },
                ),
              );
            },
          ),
        );
      final upload = Dio();
      addTearDown(broker.close);
      addTearDown(upload.close);
      final gateway = _RecordingGateway();
      final cubit = _cubit(
        gateway,
        DioCdnAssetGateway(broker, uploadDio: upload),
      );
      addTearDown(cubit.close);
      await _prepare(cubit);

      await cubit.next();

      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.error, DmOnboardingError.photoUploadFailed);
      expect(cubit.state.failure, isA<UnknownFailure>());
      expect(cubit.state.failure!.isRetryable, isTrue);
      expect(gateway.submissions, 0);

      cubit.acknowledgeError();
      await cubit.next();

      expect(brokerCalls, 2);
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.error, DmOnboardingError.photoUploadFailed);
      expect(gateway.submissions, 0);
    },
  );

  test(
    'healed portrait upload submits in the original idempotency scope',
    () async {
      final gateway = _RecordingGateway();
      final cdn = _HealingCdn();
      final cubit = _cubit(gateway, cdn);
      addTearDown(cubit.close);
      await _prepare(cubit);

      await cubit.next();

      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.error, DmOnboardingError.photoUploadFailed);
      expect(cubit.state.failure, isA<UnknownFailure>());
      expect(gateway.submissions, 0);

      await cubit.next();

      expect(cdn.operationIds, hasLength(2));
      expect(cdn.operationIds.toSet(), hasLength(1));
      expect(gateway.submissions, 1);
      expect(cubit.state.coverageReady, isTrue);
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.error, isNull);
    },
  );
}

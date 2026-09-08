// F25: a CDN rejection inside `submit` used to land on `submitFailed` — a
// "check your connection"-class message for a 413. NET-13: one operation id
// per submit, so a retried submit replays the same key per slot.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';

/// A CDN that always rejects with [status].
class _RejectingCdn implements CdnAssetGateway {
  const _RejectingCdn(this.status);

  final int status;

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async =>
      throw CdnUploadException(
        'cdn_signed_put',
        failure: status >= 500
            ? ServerFailure(status: status)
            : const ValidationFailure(),
        status: status,
      );

  @override
  Future<Uint8List> fetchAsset(String objectRef) async =>
      throw const CdnFetchException('cdn_fetch');
}

/// A KYC gateway whose submit runs the real upload chain.
class _UploadingGateway extends FakeKycGateway {
  _UploadingGateway(this._cdn);

  final CdnAssetGateway _cdn;

  @override
  Future<KycSubmission> submit(KycSubmission draft) async {
    await _cdn.uploadAsset(
      slot: CdnUploadSlot.idDocumentFront,
      bytes: draft.idFront!.bytes,
    );
    return super.submit(draft);
  }
}

PhotoAttachment _photo(String id) => PhotoAttachment(
      id: id,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      originalSizeBytes: 4,
      source: PhotoSource.camera,
    );

KycSubmission _readyDraft() => KycSubmission(
      status: KycStatus.notSubmitted,
      idNumber: '123456789012',
      idFront: _photo('front'),
      idBack: _photo('back'),
      selfie: _photo('selfie'),
    );

Future<KycWizardCubit> _submitted(int status) async {
  final cubit = KycWizardCubit(
    pickerService: StubPhotoPickerService(),
    gateway: _UploadingGateway(_RejectingCdn(status)),
  );
  cubit.emit(
    KycWizardState(
      step: KycWizardStep.identity,
      submission: _readyDraft(),
      tosAccepted: true,
    ),
  );
  await cubit.submit();
  return cubit;
}

void main() {
  test('a 413 is fileTooLarge, not a generic submit failure', () async {
    final cubit = await _submitted(413);
    addTearDown(cubit.close);

    expect(cubit.state.error, KycWizardError.fileTooLarge);
    expect(cubit.state.step, KycWizardStep.identity);
  });

  test('a 415 is fileTypeNotAllowed', () async {
    final cubit = await _submitted(415);
    addTearDown(cubit.close);

    expect(cubit.state.error, KycWizardError.fileTypeNotAllowed);
  });

  test('a 500 stays submitFailed but carries the SERVER kind', () async {
    final cubit = await _submitted(500);
    addTearDown(cubit.close);

    expect(cubit.state.error, KycWizardError.submitFailed);
    expect(cubit.state.failure!.kind, AppFailureKind.server);
  });

  test('one operationId is reused across the four slot uploads', () async {
    final keys = <String>[];
    final broker = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
    broker.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/cdn/assets') {
            keys.add(options.headers['Idempotency-Key'] as String);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'upload_url': 'https://cdn.test/put',
                  'object_ref': 'kyc/objects/${keys.length}',
                },
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{'state': 'Submitted'},
            ),
          );
        },
      ),
    );
    final upload = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(requestOptions: options, statusCode: 200),
          ),
        ),
      );

    final gateway = DioKycGateway(
      broker,
      DioCdnAssetGateway(broker, uploadDio: upload),
    );
    await gateway.submit(_readyDraft());

    expect(keys, hasLength(3));
    expect(keys.map((k) => k.split(':').first).toSet(), hasLength(1));
    expect(
      keys.map((k) => k.split(':').last).toSet(),
      <String>{'id_document_front', 'id_document_back', 'selfie_with_liveness'},
    );
  });
}

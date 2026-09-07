// NET-21: four of five methods let a raw DioException escape to the cubit,
// which then had nothing but `catch (_)` to classify it.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';

DioKycGateway _gatewayAnswering(int status, {Map<String, dynamic>? body}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: body,
        );
        if (status >= 200 && status < 300) {
          handler.resolve(response);
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      },
    ),
  );
  return DioKycGateway(dio, DioCdnAssetGateway(dio, uploadDio: dio));
}

void main() {
  test('fetchFormSchema throws KycGatewayException, never a DioException',
      () async {
    await expectLater(
      _gatewayAnswering(503).fetchFormSchema(),
      throwsA(
        isA<KycGatewayException>().having(
          (e) => e.failure.kind,
          'kind',
          AppFailureKind.server,
        ),
      ),
    );
  });

  test('fetchContractTemplate throws KycGatewayException', () async {
    await expectLater(
      _gatewayAnswering(500).fetchContractTemplate(),
      throwsA(isA<KycGatewayException>()),
    );
  });

  test('signContract throws KycGatewayException', () async {
    await expectLater(
      _gatewayAnswering(500).signContract(
        templateId: 't',
        tosVersion: 'v1',
        signatureBlob: 'sig',
      ),
      throwsA(isA<KycGatewayException>()),
    );
  });

  test('fetchStatus throws KycGatewayException on anything but a 404',
      () async {
    await expectLater(
      _gatewayAnswering(500).fetchStatus(),
      throwsA(isA<KycGatewayException>()),
    );
  });

  test('fetchStatus 404 still resolves to notSubmitted (unchanged)', () async {
    final KycSubmission submission = await _gatewayAnswering(404).fetchStatus();

    expect(submission.status, KycStatus.notSubmitted);
  });

  test('a 401 keeps its UNAUTHORIZED kind through the wrapper', () async {
    await expectLater(
      _gatewayAnswering(401).fetchStatus(),
      throwsA(
        isA<KycGatewayException>().having(
          (e) => e.failure.kind,
          'kind',
          AppFailureKind.unauthorized,
        ),
      ),
    );
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/masked_call/application/masked_call_cubit.dart';

void main() {
  test('posts delivery id to masked-call session endpoint', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const <String, dynamic>{
                  'sessionId': 'call-session-1',
                  'proxyNumber': '+1000000000',
                  'expiresAt': '2026-06-20T12:00:00Z',
                },
              ),
            );
          },
        ),
      );
    final cubit = MaskedCallCubit(dio: dio);
    addTearDown(cubit.close);

    await cubit.initiateCall(' delivery-123 ');

    expect(requests.single.path, '/api/calls/session');
    expect(requests.single.data, <String, dynamic>{
      'deliveryId': 'delivery-123',
    });
    expect(cubit.state.sessionId, 'call-session-1');
    expect(cubit.state.proxyNumber, '+1000000000');
    expect(cubit.state.error, isNull);
  });

  test('keeps a local no-Dio seam for widget tests', () async {
    final cubit = MaskedCallCubit();
    addTearDown(cubit.close);

    await cubit.initiateCall('delivery-123');

    expect(cubit.state.sessionId, 'session-delivery-123');
    expect(cubit.state.error, isNull);
  });
}

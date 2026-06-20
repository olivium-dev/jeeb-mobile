import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';

void main() {
  test('posts prohibited-item reports to the gateway endpoint', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 202),
            );
          },
        ),
      );
    final service = ProhibitedItemReportService(dio);

    await service.report(
      requestId: ' req-123 ',
      reason: ' Client requested a prohibited item. ',
    );

    expect(requests.single.path, '/prohibited-items/reports');
    expect(requests.single.data, <String, dynamic>{
      'requestId': 'req-123',
      'reason': 'Client requested a prohibited item.',
    });
  });
}

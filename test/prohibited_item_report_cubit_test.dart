// Tests for ProhibitedItemReportCubit (orders-prohibited-item-report).
//
// Verifies the report submission flow: the typed reason (+ optional photo) is
// sent to the gateway via ProhibitedItemReportService; success → submitted;
// failures map to the localized error keys; empty description blocks submit.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/prohibited_item_report/application/prohibited_item_report_cubit.dart';

class _FakeService implements ProhibitedItemReportService {
  _FakeService({this.failure});

  final ProhibitedReportFailure? failure;
  String? reqId;
  String? reason;
  String? photoUrl;

  @override
  Future<void> report({
    required String requestId,
    required String reason,
    String? photoUrl,
  }) async {
    reqId = requestId;
    this.reason = reason;
    this.photoUrl = photoUrl;
    final f = failure;
    if (f != null) throw ProhibitedReportException(f);
  }
}

void main() {
  test('empty description blocks submit', () async {
    final service = _FakeService();
    final cubit = ProhibitedItemReportCubit(
      service: service,
      requestId: 'req-1',
    );

    await cubit.submit();

    expect(service.reqId, isNull);
    expect(cubit.state.phase, ProhibitedReportPhase.editing);
    await cubit.close();
  });

  test('success: submits reason + photo, lands submitted', () async {
    final service = _FakeService();
    final cubit = ProhibitedItemReportCubit(
      service: service,
      requestId: 'req-7',
    )
      ..setDescription('weapons in the box')
      ..attachPhoto('pending-capture://1');

    await cubit.submit();

    expect(service.reqId, 'req-7');
    expect(service.reason, 'weapons in the box');
    expect(service.photoUrl, 'pending-capture://1');
    expect(cubit.state.phase, ProhibitedReportPhase.submitted);
    await cubit.close();
  });

  test('network failure maps to network error key', () async {
    final service = _FakeService(failure: ProhibitedReportFailure.network);
    final cubit = ProhibitedItemReportCubit(
      service: service,
      requestId: 'req-1',
    )..setDescription('drugs');

    await cubit.submit();

    expect(cubit.state.phase, ProhibitedReportPhase.error);
    expect(cubit.state.errorKey, 'jeeberRequestDetailReportErrorNetwork');
    await cubit.close();
  });

  test('unknown failure maps to generic error key', () async {
    final service = _FakeService(failure: ProhibitedReportFailure.unknown);
    final cubit = ProhibitedItemReportCubit(
      service: service,
      requestId: 'req-1',
    )..setDescription('hazardous');

    await cubit.submit();

    expect(cubit.state.errorKey, 'jeeberRequestDetailReportErrorGeneric');
    await cubit.close();
  });
}

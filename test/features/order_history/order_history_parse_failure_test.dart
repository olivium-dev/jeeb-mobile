// ORDH-03: a numeric `id` used to throw TypeError past BOTH catches and leave
// the tab stuck in `loadingFirstPage` for ever. Now the read is guarded and any
// decode failure that does escape is classified as a parse failure.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_state.dart';
import 'package:jeeb_mobile/features/order_history/data/dio_order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

/// Answers every GET with [body], so the decode path is the only thing tested.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.body);

  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

DioOrderRepository _repo(Object body) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  dio.httpClientAdapter = _ScriptedAdapter(body);
  return DioOrderRepository(dio);
}

final Object _numericId = <String, Object>{
  'items': <Object>[
    <String, Object>{'id': 42, 'status': 'picked_up', 'tier': 7},
  ],
};

/// `items` present but not a list — the shape guard's own FormatException.
final Object _malformed = <String, Object>{'items': 'nope'};

void main() {
  test('a numeric id no longer throws past the catches', () async {
    await _repo(_numericId).fetchPage(
      tab: OrderHistoryTab.active,
      page: 1,
      pageSize: 20,
    );
  });

  test('the tab never stays in loadingFirstPage on a numeric id', () async {
    final OrderHistoryCubit cubit = OrderHistoryCubit(
      repository: _repo(_numericId),
    );
    addTearDown(cubit.close);
    await cubit.initialLoad();

    expect(cubit.state.currentTab.status, isNot(OrderTabStatus.loadingFirstPage));
    expect(cubit.state.currentTab.status, OrderTabStatus.ready);
  });

  test('a malformed payload classifies as a PARSE failure', () async {
    await expectLater(
      _repo(_malformed).fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 20,
      ),
      throwsA(
        isA<OrderRepositoryException>()
            .having(
              (OrderRepositoryException e) => e.kind,
              'kind',
              OrderRepositoryErrorKind.parse,
            )
            .having(
              (OrderRepositoryException e) => e.failure,
              'failure',
              isA<UnknownFailure>().having(
                (UnknownFailure f) => f.parse,
                'parse',
                isTrue,
              ),
            ),
      ),
    );
  });

  test('a malformed payload reaches the ERROR rung, not a hang', () async {
    final OrderHistoryCubit cubit = OrderHistoryCubit(
      repository: _repo(_malformed),
    );
    addTearDown(cubit.close);
    await cubit.initialLoad();

    expect(cubit.state.currentTab.status, OrderTabStatus.error);
    expect(cubit.state.currentTab.failure, isA<UnknownFailure>());
    expect((cubit.state.currentTab.failure! as UnknownFailure).parse, isTrue);
  });
}

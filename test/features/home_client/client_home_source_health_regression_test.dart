import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';

enum _Source { deliveries, role, active }

class _HomeApi {
  _HomeApi() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final source = options.path == '/deliveries'
              ? _Source.deliveries
              : options.queryParameters['status'] == 'active'
              ? _Source.active
              : _Source.role;
          if (!healthy.contains(source)) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  if (includeRow)
                    <String, dynamic>{
                      'id': rowId,
                      'status': 'accepted',
                      'stage': 'accepted',
                      'title': 'Accepted request',
                      'conversationId': 'conversation-good',
                      'amount': <String, dynamic>{
                        'value': 8,
                        'currency': 'USD',
                      },
                    },
                ],
              },
            ),
          );
        },
      ),
    );
  }

  final Dio dio = Dio();
  Set<_Source> healthy = <_Source>{};
  bool includeRow = true;
  String rowId = 'accepted-good-row';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final source in _Source.values) {
    for (final includeRow in <bool>[false, true]) {
      test(
        'surviving ${source.name} source (rows=$includeRow) keeps home ready',
        () async {
          final api = _HomeApi()
            ..healthy = <_Source>{source}
            ..includeRow = includeRow;
          addTearDown(api.dio.close);
          final repository = DioClientHomeRepository(api.dio);
          final snapshot = await repository.loadSnapshot();

          expect(snapshot.allPrimaryFailed, isFalse);
          if (includeRow) {
            expect(
              snapshot.inProgress.map((row) => row.id),
              contains(api.rowId),
            );
            expect(snapshot.inProgressFailure, isNull);
          }
          if (source == _Source.role) expect(snapshot.requestsFailure, isNull);

          final cubit = ClientHomeCubit(
            repository: repository,
            greetingNameProvider: () => 'User',
          );
          addTearDown(cubit.close);
          await cubit.load();

          expect(cubit.state.status, ClientHomeStatus.ready);
          if (includeRow) {
            expect(
              cubit.state.inProgress.map((row) => row.id),
              contains(api.rowId),
            );
            expect(cubit.state.inProgressError, isNull);
          }
        },
      );
    }
  }

  test(
    'all source failures stay failed and a recovered role read clears it',
    () async {
      final api = _HomeApi();
      addTearDown(api.dio.close);
      final cubit = ClientHomeCubit(
        repository: DioClientHomeRepository(api.dio),
        greetingNameProvider: () => 'User',
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, ClientHomeStatus.failed);
      expect(cubit.state.error, isA<NetworkFailure>());

      api.healthy = <_Source>{_Source.role};
      await cubit.load();
      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.inProgress.map((row) => row.id), contains(api.rowId));
      expect(cubit.state.inProgressError, isNull);
      expect(cubit.state.error, isNull);

      api.rowId = 'new-accepted-row';
      await cubit.refresh();
      expect(cubit.state.inProgress.map((row) => row.id), contains(api.rowId));
    },
  );
}

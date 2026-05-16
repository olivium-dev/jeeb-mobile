import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../features/order_history/data/dio_order_repository.dart';
import '../../features/order_history/domain/order_repository.dart';
import '../network/dio_client.dart';

final sl = GetIt.instance;

void configureDependencies() {
  // Core
  sl.registerLazySingleton<Dio>(() => DioClient.createDio());

  // Repositories
  sl.registerLazySingleton<OrderRepository>(
    () => DioOrderRepository(sl<Dio>()),
  );

  // Use Cases
  // TODO: Register feature use cases here.

  // BLoCs
  // TODO: Register feature BLoCs here.
}

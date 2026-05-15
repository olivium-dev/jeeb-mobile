import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../network/dio_client.dart';

final sl = GetIt.instance;

void configureDependencies() {
  // Core
  sl.registerLazySingleton<Dio>(() => DioClient.createDio());

  // Repositories
  // TODO: Register feature repositories here.

  // Use Cases
  // TODO: Register feature use cases here.

  // BLoCs
  // TODO: Register feature BLoCs here.
}

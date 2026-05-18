import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/order_history/data/dio_order_repository.dart';
import '../../features/order_history/domain/order_repository.dart';
import '../network/dio_client.dart';
import '../observability/crash_reporter.dart';

final sl = GetIt.instance;

void configureDependencies({
  required SharedPreferences sharedPreferences,
  required CrashReporter crashReporter,
}) {
  // Runtime singletons resolved during Bootstrap.minimal — must register
  // before any dependent registration so lazy resolutions can pull them.
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  sl.registerSingleton<CrashReporter>(crashReporter);

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

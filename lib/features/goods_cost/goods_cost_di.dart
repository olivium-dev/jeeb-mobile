import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'data/dio_goods_cost_repository.dart';
import 'domain/goods_cost_repository.dart';

/// Stage-2 calls this from `injection_container.dart`; until then the screen's
/// `_resolveRepository()` seam falls back to a Dio-built instance.
void registerGoodsCostDependencies(GetIt getIt) {
  if (getIt.isRegistered<GoodsCostRepository>()) return;
  getIt.registerLazySingleton<GoodsCostRepository>(
    () => DioGoodsCostRepository(getIt<Dio>()),
  );
}

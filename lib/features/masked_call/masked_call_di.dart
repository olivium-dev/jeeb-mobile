import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'data/dio_masked_call_repository.dart';
import 'domain/masked_call_repository.dart';

/// Stage 2 calls this from `injection_container.dart` (R2 rule b).
void registerMaskedCallDependencies(GetIt getIt) {
  if (getIt.isRegistered<MaskedCallRepository>()) return;
  getIt.registerLazySingleton<MaskedCallRepository>(
    () => DioMaskedCallRepository(getIt<Dio>()),
  );
}

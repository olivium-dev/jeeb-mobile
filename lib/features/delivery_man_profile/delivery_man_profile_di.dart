import 'package:get_it/get_it.dart';

import '../../core/di/injection_container.dart' show resolveGatewayDio;
import '../reviews/domain/reviews_repository.dart';
import 'data/dio_delivery_man_profile_repository.dart';
import 'data/reviews_backed_delivery_man_profile_repository.dart';
import 'domain/delivery_man_profile_repository.dart';

/// Stage 2 calls this from `injection_container.dart`; the adapter branch is
/// the live path because `ReviewsRepository` is already registered.
void registerDeliveryManProfileDependencies(GetIt getIt) {
  if (getIt.isRegistered<DeliveryManProfileRepository>()) return;
  getIt.registerLazySingleton<DeliveryManProfileRepository>(
    () => getIt.isRegistered<ReviewsRepository>()
        ? ReviewsBackedDeliveryManProfileRepository(getIt<ReviewsRepository>())
        : DioDeliveryManProfileRepository(resolveGatewayDio()),
  );
}

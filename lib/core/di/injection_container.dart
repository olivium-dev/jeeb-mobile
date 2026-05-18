import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/earnings/data/dio_earnings_repository.dart';
import '../../features/earnings/domain/earnings_repository.dart';
import '../../features/home_client/data/dio_client_home_repository.dart';
import '../../features/home_client/domain/client_home_repository.dart';
import '../../features/live_tracking/data/dio_live_tracking_repository.dart';
import '../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../features/notification_prefs/data/notification_prefs_store.dart';
import '../../features/order_history/data/dio_order_repository.dart';
import '../../features/order_history/domain/order_repository.dart';
import '../../features/otp_handover/data/dio_otp_handover_repository.dart';
import '../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../features/registration/data/dio_otp_service.dart';
import '../../features/registration/domain/otp_service.dart';
import '../network/auth_token_store.dart';
import '../network/mock_gateway_client.dart';
import '../observability/crash_reporter.dart';

final sl = GetIt.instance;

void configureDependencies({
  required SharedPreferences sharedPreferences,
  required CrashReporter crashReporter,
}) {
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  sl.registerSingleton<CrashReporter>(crashReporter);

  sl.registerLazySingleton<Dio>(() => MockGatewayClient.createDio());
  sl.registerLazySingleton<AuthTokenStore>(() => AuthTokenStore());

  sl.registerLazySingleton<OtpService>(() => DioOtpService(sl<Dio>()));

  sl.registerLazySingleton<OrderRepository>(
    () => DioOrderRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<ClientHomeRepository>(
    () => DioClientHomeRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<EarningsRepository>(
    () => DioEarningsRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<OtpHandoverRepository>(
    () => DioOtpHandoverRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<LiveTrackingRepository>(
    () => DioLiveTrackingRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<NotificationPrefsStore>(
    () => NotificationPrefsStore(sl<SharedPreferences>()),
  );
}

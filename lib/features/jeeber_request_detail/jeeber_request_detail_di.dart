import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'data/dio_prohibited_item_report_service.dart';
import 'domain/services/prohibited_item_report_service.dart';

/// Stage 2 calls this from `injection_container.dart` after the existing
/// `ProhibitedItemReportService` registration; with no Dio the const no-op stands.
void registerJeeberRequestDetailDependencies(GetIt getIt) {
  if (!getIt.isRegistered<Dio>()) return;
  if (getIt.isRegistered<ProhibitedItemReportService>()) {
    getIt.unregister<ProhibitedItemReportService>();
  }
  getIt.registerLazySingleton<ProhibitedItemReportService>(
    () => DioProhibitedItemReportService(getIt<Dio>()),
  );
}

import 'package:get_it/get_it.dart';

import 'application/cancelled_request_signals.dart';

/// The cancel bus is process-wide: the sheet that cancels and the list that
/// must shrink live on different routes.
void registerCancelRequestDependencies(GetIt getIt) {
  if (getIt.isRegistered<CancelledRequestSignals>()) return;
  getIt.registerLazySingleton<CancelledRequestSignals>(
    CancelledRequestSignals.new,
    dispose: (bus) => bus.dispose(),
  );
}

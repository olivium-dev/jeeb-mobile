import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/observability/crash_reporter.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockCrashReporter extends Mock implements CrashReporter {}

// Contract under test (JEB-3 / T-MOB-FIX-003, Path B per LEAD pin JEB-3#14895):
//
//   void configureDependencies({
//     required SharedPreferences sharedPreferences,
//     required CrashReporter crashReporter,
//   })
//
// These tests intentionally fail on `main` (current signature is no-arg) and
// will pass once ENG (JEB-233) extends the signature and registers the two
// runtime singletons before dependents. QA-POST (JEB-232) consumes this file
// as the unit gate.
void main() {
  late SharedPreferences mockPrefs;
  late CrashReporter mockReporter;

  setUp(() {
    GetIt.I.reset();
    mockPrefs = _MockSharedPreferences();
    mockReporter = _MockCrashReporter();
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  test(
    'registers SharedPreferences and CrashReporter as singletons that resolve from GetIt',
    () {
      configureDependencies(
        sharedPreferences: mockPrefs,
        crashReporter: mockReporter,
      );

      expect(GetIt.I.isRegistered<SharedPreferences>(), isTrue);
      expect(GetIt.I.isRegistered<CrashReporter>(), isTrue);
      expect(identical(GetIt.I<SharedPreferences>(), mockPrefs), isTrue);
      expect(identical(GetIt.I<CrashReporter>(), mockReporter), isTrue);
    },
  );

  test(
    'downstream dependents (Dio, OrderRepository) resolve without throwing after configureDependencies',
    () {
      configureDependencies(
        sharedPreferences: mockPrefs,
        crashReporter: mockReporter,
      );

      expect(() => GetIt.I<Dio>(), returnsNormally);
      expect(() => GetIt.I<OrderRepository>(), returnsNormally);
      expect(GetIt.I<Dio>(), isA<Dio>());
      expect(GetIt.I<OrderRepository>(), isA<OrderRepository>());
    },
  );

  // Contract decision (LEAD pin asked QA to pick + document): the production
  // call site is `Bootstrap.minimal` which runs exactly once on cold start.
  // Duplicate registration is therefore a bug, not a feature, and must
  // surface immediately rather than silently swap a live singleton mid-app.
  // We adopt the "fail loudly" contract: the second call MUST throw, mirroring
  // the default GetIt 8.x behaviour (StateError / ArgumentError). If ENG
  // decides to make this idempotent instead, the assertion below must be
  // flipped together with that decision.
  test(
    'calling configureDependencies twice on the same GetIt fails loudly (fail-fast contract)',
    () {
      configureDependencies(
        sharedPreferences: mockPrefs,
        crashReporter: mockReporter,
      );

      expect(
        () => configureDependencies(
          sharedPreferences: mockPrefs,
          crashReporter: mockReporter,
        ),
        throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())),
      );
    },
  );

  // P1, 2026-08-01 — the jeeber GPS uploader must OUTLIVE the screen.
  //
  // It was a `registerFactory`, so the active-delivery route handed a brand new
  // cubit to every build and `ActiveDeliveryCubit` closed it on dispose. The
  // pipeline's lifetime was therefore the widget's: pop the route (open chat,
  // back out to the feed) and the courier silently stopped reporting position
  // for the rest of the delivery, freezing the customer's map.
  //
  // Resolving twice is the whole test. Under a factory these are two different
  // objects and the assertion fails; under the lazy singleton they are one.
  test(
    'BackgroundGpsCubit resolves as ONE shared instance, not a per-screen factory',
    () {
      configureDependencies(
        sharedPreferences: mockPrefs,
        crashReporter: mockReporter,
      );

      final first = GetIt.I<BackgroundGpsCubit>();
      final second = GetIt.I<BackgroundGpsCubit>();

      expect(
        identical(first, second),
        isTrue,
        reason: 'A fresh uploader per screen is the P1: the delivery, not the '
            'route, owns the upload window.',
      );
      // A singleton that has been closed cannot emit again, so the second
      // delivery of the session would get a dead pipeline. Nothing may close it.
      expect(first.isClosed, isFalse);
    },
  );
}

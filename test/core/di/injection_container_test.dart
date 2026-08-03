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
      expect(first.isClosed, isFalse);
    },
  );
}

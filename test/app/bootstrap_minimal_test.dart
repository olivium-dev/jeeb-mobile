import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/bootstrap.dart';
import 'package:jeeb_mobile/core/observability/crash_reporter.dart';
import 'package:jeeb_mobile/core/observability/swappable_crash_reporter.dart';

/// Sprint 5 — cold-start ANR regression guard.
/// `Bootstrap.minimal()` must resolve the first-frame critical path WITHOUT
/// awaiting `Firebase.initializeApp()` (which hangs ~40s on a dev build with no
class _RecordingCrashReporter implements CrashReporter {
  int errors = 0;
  int logs = 0;
  String? userId;

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {
    errors++;
  }

  @override
  void setUserId(String userId) {
    this.userId = userId;
  }

  @override
  void log(String message) {
    logs++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await GetIt.I.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  test(
      'minimal() resolves quickly without awaiting Firebase even when no '
      'backend is reachable (cold-start ANR guard)', () async {
    // The whole point: minimal must not block on a native initializer. If it
    final result = await Bootstrap.minimal().timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail(
        'Bootstrap.minimal() did not resolve within 2s — boot is blocking on '
        'I/O/native init again (cold-start ANR regression).',
      ),
    );

    // The first-frame reporter is the Noop-backed swappable; the real
    expect(result.crashReporter, isA<SwappableCrashReporter>());
    // DI is wired so the app can resolve its singletons on first build.
    expect(GetIt.I.isRegistered<SharedPreferences>(), isTrue);
  });

  test(
      'deferred() upgrades the SwappableCrashReporter delegate to the real '
      'reporter post-first-frame', () async {
    final swappable = SwappableCrashReporter();
    final real = _RecordingCrashReporter();

    // Before the deferred upgrade, the delegate is Noop — records are swallowed.
    swappable.recordError('pre', StackTrace.current);
    expect(real.errors, 0);

    await Bootstrap.deferred(
      crashReporter: swappable,
      crashReporterFactory: () async => real,
    ).timeout(const Duration(seconds: 2));

    // After the upgrade, the same stable instance forwards to the real reporter.
    swappable.recordError('post', StackTrace.current);
    swappable.log('breadcrumb');
    swappable.setUserId('user-1');
    expect(real.errors, 1);
    expect(real.logs, 1);
    expect(real.userId, 'user-1');
  });

  test('deferred() is a no-op on the reporter when given a non-swappable one',
      () async {
    final fixed = _RecordingCrashReporter();
    // Should simply skip the swap path and not throw.
    await Bootstrap.deferred(
      crashReporter: fixed,
      crashReporterFactory: () async => _RecordingCrashReporter(),
    ).timeout(const Duration(seconds: 2));
    expect(fixed.errors, 0);
  });
}

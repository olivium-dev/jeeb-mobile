import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/observability/crash_reporter.dart';
import 'package:jeeb_mobile/core/observability/crash_reporting_initializer.dart';

class _RecordedError {
  const _RecordedError(this.error, this.fatal);

  final Object error;
  final bool fatal;
}

class _RecordingCrashReporter implements CrashReporter {
  final List<_RecordedError> errors = <_RecordedError>[];

  @override
  void log(String message) {}

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {
    errors.add(_RecordedError(error, fatal));
  }

  @override
  void setUserId(String userId) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uncaught Flutter and platform errors are reported as fatal', () {
    final originalFlutterHandler = FlutterError.onError;
    final originalPlatformHandler = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = originalFlutterHandler;
      PlatformDispatcher.instance.onError = originalPlatformHandler;
    });

    final reporter = _RecordingCrashReporter();
    CrashReportingInitializer(reporter).install();
    final flutterError = StateError('flutter failure');
    final platformError = StateError('platform failure');

    FlutterError.reportError(
      FlutterErrorDetails(exception: flutterError, stack: StackTrace.current),
    );
    final handled = PlatformDispatcher.instance.onError!(
      platformError,
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(reporter.errors, hasLength(2));
    expect(reporter.errors[0].error, same(flutterError));
    expect(reporter.errors[0].fatal, isTrue);
    expect(reporter.errors[1].error, same(platformError));
    expect(reporter.errors[1].fatal, isTrue);
  });
}

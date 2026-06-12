import 'package:flutter/foundation.dart';
import 'crash_reporter.dart';

class CrashReportingInitializer {

  CrashReportingInitializer(this._reporter);
  final CrashReporter _reporter;

  void install() {
    FlutterError.onError = (details) {
      _reporter.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: false,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _reporter.recordError(error, stack, fatal: true);
      return true;
    };
  }
}

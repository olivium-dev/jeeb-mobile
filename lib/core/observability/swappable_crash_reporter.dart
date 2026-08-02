import 'crash_reporter.dart';

class SwappableCrashReporter implements CrashReporter {
  SwappableCrashReporter([CrashReporter delegate = const NoopCrashReporter()])
      : _delegate = delegate;

  CrashReporter _delegate;

  void setDelegate(CrashReporter delegate) => _delegate = delegate;

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) =>
      _delegate.recordError(error, stackTrace, fatal: fatal);

  @override
  void setUserId(String userId) => _delegate.setUserId(userId);

  @override
  void log(String message) => _delegate.log(message);
}

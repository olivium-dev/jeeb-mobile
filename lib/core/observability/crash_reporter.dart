abstract class CrashReporter {
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false});
  void setUserId(String userId);
  void log(String message);
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {}

  @override
  void setUserId(String userId) {}

  @override
  void log(String message) {}
}

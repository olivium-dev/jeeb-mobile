import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'crash_reporter.dart';

class FirebaseCrashlyticsReporter implements CrashReporter {
  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: fatal);
  }

  @override
  void setUserId(String userId) {
    FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  @override
  void log(String message) {
    FirebaseCrashlytics.instance.log(message);
  }
}

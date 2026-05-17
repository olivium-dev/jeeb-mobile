import 'dart:async';
import 'package:flutter/foundation.dart';

class CrashReporter {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FlutterError.onError = (details) {
      _reportFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _reportError(error, stack);
      return true;
    };
  }

  static void _reportFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  static void _reportError(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Uncaught error: $error');
      debugPrint('$stack');
    }
  }

  static void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (kDebugMode) {
      debugPrint('${fatal ? "FATAL" : "NON-FATAL"} error: $error');
    }
  }

  static void setUserIdentifier(String userId) {
    if (kDebugMode) {
      debugPrint('CrashReporter: user=$userId');
    }
  }

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('CrashReporter: $message');
    }
  }
}

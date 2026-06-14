import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dev_seam_config.dart';

/// A single resolution input for the dev seam. Sources are tried in priority
/// order by [DevSeam.resolve]; the first one that yields a non-empty config
/// wins. Each source is independently testable (no platform channel required).
abstract class DevSeamSource {
  /// Returns the config this source carries, or [DevSeamConfig.empty] when it
  /// has nothing to contribute. Must never throw — a failing dev source must
  /// degrade to empty, never crash startup.
  FutureOr<DevSeamConfig> read();
}

/// Reads Android intent extras via a [MethodChannel] into [MainActivity].
/// Enables: `adb shell am start -n app.jeeb.mobile.dev/app.jeeb.mobile.MainActivity \
///   -e jeeb.route /chat -e jeeb.state broadcasting -e jeeb.locale ar`.
///
/// This is the standard Flutter↔native interop pattern for reading launch
/// intent state; chosen over a plugin to keep the seam self-contained and
/// release-inert (the native handler returns null when no extras are present).
class IntentExtrasSource implements DevSeamSource {
  const IntentExtrasSource({this.channel = _defaultChannel});

  static const MethodChannel _defaultChannel =
      MethodChannel('app.jeeb.mobile/dev_seam');

  final MethodChannel channel;

  @override
  Future<DevSeamConfig> read() async {
    try {
      final result =
          await channel.invokeMapMethod<String, Object?>('readSeamExtras');
      if (result == null || result.isEmpty) return DevSeamConfig.empty;
      final flat = result.map((k, v) => MapEntry(k, '${v ?? ''}'));
      return DevSeamConfig.fromMap(flat);
    } on MissingPluginException {
      // Non-Android or handler absent — fall through to the next source.
      return DevSeamConfig.empty;
    } catch (error) {
      debugPrint('DevSeam: intent-extras read failed: $error');
      return DevSeamConfig.empty;
    }
  }
}

/// Reads a JSON file pushed to the device (default `/data/local/tmp/`):
/// `adb push jeeb-dev-seam.json /data/local/tmp/jeeb-dev-seam.json`.
/// Read through a [MethodChannel] because Flutter has no direct access to the
/// shell-owned `/data/local/tmp` path; the native side does the file read.
class DeviceFileSource implements DevSeamSource {
  const DeviceFileSource({this.channel = IntentExtrasSource._defaultChannel});

  final MethodChannel channel;

  @override
  Future<DevSeamConfig> read() async {
    try {
      final raw = await channel.invokeMethod<String>('readSeamFile');
      if (raw == null || raw.trim().isEmpty) return DevSeamConfig.empty;
      return DevSeamConfig.fromJsonString(raw);
    } on MissingPluginException {
      return DevSeamConfig.empty;
    } catch (error) {
      debugPrint('DevSeam: device-file read failed: $error');
      return DevSeamConfig.empty;
    }
  }
}

/// Compile-time fallback: the original `--dart-define` values. Keeps every
/// existing `flutter build … --dart-define=JEEB_DEV_*` flow working unchanged
/// (pilot in-flight flows must not break).
class DartDefineSource implements DevSeamSource {
  const DartDefineSource();

  static const String _devHomeRoute =
      bool.fromEnvironment('JEEB_DEV_HOME') ? '/' : '';
  static const String _devChat = String.fromEnvironment('JEEB_DEV_CHAT');
  static const String _forcedLocale =
      String.fromEnvironment('JEEB_FORCE_LOCALE');
  static const bool _holdSplash = bool.fromEnvironment('JEEB_HOLD_SPLASH');

  /// Opt-in for letting the route pin skip first-run. Deliberately a SEPARATE
  /// dart-define from `JEEB_DEV_HOME` so `JEEB_DEV_HOME=true` alone no longer
  /// silently bypasses onboarding/login (FR-P0-1). Default false.
  static const bool _skipOnboarding =
      bool.fromEnvironment('JEEB_DEV_SKIP_ONBOARDING');

  @override
  DevSeamConfig read() => const DevSeamConfig(
        route: _devHomeRoute,
        chatSelector: _devChat,
        forcedLocale: _forcedLocale,
        holdSplash: _holdSplash,
        skipOnboarding: _skipOnboarding,
      );
}

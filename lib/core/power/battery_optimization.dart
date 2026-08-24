import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android battery-restriction seam (`MainActivity`'s `power` channel): Samsung
/// app-sleep withholds FCM, and only the OS list can lift it.
class BatteryOptimization {
  const BatteryOptimization({MethodChannel channel = _defaultChannel})
    : _channel = channel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.olivium.jeeb/power',
  );

  /// One prompt per install; a declined prompt must not nag on every shift.
  static const String promptedPrefsKey = 'power.batteryPromptShown.v1';

  final MethodChannel _channel;

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isExempt() async {
    if (!isSupported) return true;
    try {
      final value = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return value ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  Future<bool> openSettings() async {
    if (!isSupported) return false;
    try {
      final value = await _channel.invokeMethod<bool>(
        'openBatteryOptimizationSettings',
      );
      return value ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// True when the jeeber should see the one-time prompt now.
  Future<bool> shouldPrompt(SharedPreferences prefs) async {
    if (!isSupported) return false;
    if (prefs.getBool(promptedPrefsKey) ?? false) return false;
    return !await isExempt();
  }

  Future<void> markPrompted(SharedPreferences prefs) =>
      prefs.setBool(promptedPrefsKey, true);
}

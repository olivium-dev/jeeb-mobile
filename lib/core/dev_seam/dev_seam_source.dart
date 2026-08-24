import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dev_seam_config.dart';

abstract class DevSeamSource {
  FutureOr<DevSeamConfig> read();
}

class IntentExtrasSource implements DevSeamSource {
  const IntentExtrasSource({this.channel = _defaultChannel});

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.olivium.jeeb/dev_seam',
  );

  final MethodChannel channel;

  @override
  Future<DevSeamConfig> read() async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'readSeamExtras',
      );
      if (result == null || result.isEmpty) return DevSeamConfig.empty;
      final flat = result.map((k, v) => MapEntry(k, '${v ?? ''}'));
      return DevSeamConfig.fromMap(flat);
    } on MissingPluginException {
      return DevSeamConfig.empty;
    } catch (error) {
      debugPrint('DevSeam: intent-extras read failed: $error');
      return DevSeamConfig.empty;
    }
  }
}

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

class DartDefineSource implements DevSeamSource {
  const DartDefineSource();

  static const String _devHomeRoute = bool.fromEnvironment('JEEB_DEV_HOME')
      ? '/'
      : '';
  static const String _devChat = String.fromEnvironment('JEEB_DEV_CHAT');
  static const String _forcedLocale = String.fromEnvironment(
    'JEEB_FORCE_LOCALE',
  );
  static const bool _holdSplash = bool.fromEnvironment('JEEB_HOLD_SPLASH');

  static const bool _skipOnboarding = bool.fromEnvironment(
    'JEEB_DEV_SKIP_ONBOARDING',
  );

  @override
  DevSeamConfig read() => const DevSeamConfig(
    route: _devHomeRoute,
    chatSelector: _devChat,
    forcedLocale: _forcedLocale,
    holdSplash: _holdSplash,
    skipOnboarding: _skipOnboarding,
  );
}

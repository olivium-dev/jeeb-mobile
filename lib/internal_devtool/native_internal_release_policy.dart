import 'package:flutter/services.dart';

import '../core/config/internal_release_policy.dart';

abstract final class NativeInternalReleasePolicyReader {
  static const MethodChannel _channel = MethodChannel(
    'com.olivium.jeeb/internal_release',
  );

  static Future<NativeInternalReleasePolicy> read() async {
    final values = await _channel.invokeMapMethod<String, Object?>(
      'readPolicy',
    );
    if (values == null) throw StateError('Native policy is unavailable.');
    return NativeInternalReleasePolicy(
      releaseBuild: values['releaseBuild'] == true,
      internalFlavor: values['internalFlavor'] == true,
      internalResource: values['internalResource'] == true,
      dedicatedLauncher: values['dedicatedLauncher'] == true,
    );
  }
}

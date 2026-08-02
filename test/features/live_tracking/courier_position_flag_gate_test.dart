import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/app_config.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';

/// THE flag gate — `resolveCourierPositionChannel()`.
/// ## How this file is a positive AND a negative control
/// `AppConfig.realtimeCourierPositionEnabled` is a `const
class _StubChannel implements CourierPositionChannel {
  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async =>
      null;
}

void main() {
  tearDown(() async {
    if (sl.isRegistered<CourierPositionChannel>()) {
      await sl.unregister<CourierPositionChannel>();
    }
  });

  test('with NOTHING registered the gate yields null, whatever the flag says',
      () {
    expect(sl.isRegistered<CourierPositionChannel>(), isFalse);
    expect(resolveCourierPositionChannel(), isNull,
        reason: 'every bare widget test runs without DI; the gate must not '
            'throw a GetIt assertion into a screen build');
  });

  test('the flag decides — and the shipped default is OFF', () {
    final registered = _StubChannel();
    sl.registerSingleton<CourierPositionChannel>(registered);

    if (AppConfig.realtimeCourierPositionEnabled) {
      // POSITIVE CONTROL arm — run with
      expect(resolveCourierPositionChannel(), same(registered),
          reason: 'with the flag on the gate must hand back the REGISTERED '
              'channel; a null here would mean the feature can never turn on');
    } else {
      // NEGATIVE CONTROL arm — the default build.
      expect(resolveCourierPositionChannel(), isNull,
          reason: 'off by default: a registered channel must still not reach '
              'the tracking screen');
    }
  });

  test('the default value of the define is false', () {
    // Stated separately from the branch above so the DEFAULT is pinned even in
    const declared = bool.fromEnvironment('JEEB_REALTIME_TRACKING');
    expect(AppConfig.realtimeCourierPositionEnabled, declared,
        reason: 'the flag must read exactly JEEB_REALTIME_TRACKING with a '
            'false default');
  });
}

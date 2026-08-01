import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/app_config.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';

/// THE flag gate — `resolveCourierPositionChannel()`.
///
/// ## How this file is a positive AND a negative control
///
/// `AppConfig.realtimeCourierPositionEnabled` is a `const
/// bool.fromEnvironment`, so it cannot be varied at runtime. Rather than assert
/// only the default (which would prove "off by default" and nothing else), this
/// file BRANCHES on the flag and asserts the matching arm, so the same file run
/// twice covers both:
///
/// ```
/// flutter test test/features/live_tracking/courier_position_flag_gate_test.dart
///   → the flag is false → asserts the gate yields NOTHING even with a channel
///     registered  (the negative control, and the shipped default)
///
/// flutter test --dart-define=JEEB_REALTIME_TRACKING=true \
///   test/features/live_tracking/courier_position_flag_gate_test.dart
///   → the flag is true → asserts the gate yields THE REGISTERED CHANNEL
///     (the positive control — proof the gate is wired to something real and
///      not merely returning null for all inputs)
/// ```
///
/// Without the second run, "returns null" is equally satisfied by a gate that
/// is broken.
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
      // --dart-define=JEEB_REALTIME_TRACKING=true.
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
    // a run that flips the define: `const bool.fromEnvironment` with no
    // `defaultValue` silently defaults to false, and someone "tidying" the
    // declaration into that shorter form would leave this green — but someone
    // changing the default to `true` would red it.
    const declared = bool.fromEnvironment('JEEB_REALTIME_TRACKING');
    expect(AppConfig.realtimeCourierPositionEnabled, declared,
        reason: 'the flag must read exactly JEEB_REALTIME_TRACKING with a '
            'false default');
  });
}

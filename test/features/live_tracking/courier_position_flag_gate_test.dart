import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/app_config.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';

/// THE flag gate — `resolveCourierPositionChannel()`.
///
/// ## D14 inverted the default, and this file had to stop branching on it
/// The old version wrapped its real assertion in
/// `if (AppConfig.realtimeCourierPositionEnabled) … else …`, so whichever way
/// the default went, ONE arm passed. It could not go red, and the default it
/// claimed to pin ("OFF") was the mobile half of D14: the define lived in two
/// dev scripts and nowhere else, so no build any device ever ran subscribed to
/// courier position. The assertions below are unconditional on a build that
/// supplies no define — which is every build a device runs.
class _StubChannel implements CourierPositionChannel {
  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async =>
      null;
}

/// True only when someone passed `--dart-define=JEEB_REALTIME_TRACKING=…`.
const bool _defineSupplied = bool.hasEnvironment('JEEB_REALTIME_TRACKING');

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

  test('a build with NO define subscribes — the shipped default is ON', () {
    if (_defineSupplied) {
      markTestSkipped('a define was supplied; the DEFAULT is not under test');
      return;
    }
    sl.registerSingleton<CourierPositionChannel>(_StubChannel());

    // Unconditional: this is precisely what `flutter build apk --flavor dev`
    // produces, and it is the assertion that was red before D14's fix.
    expect(AppConfig.realtimeCourierPositionEnabled, isTrue,
        reason: 'an OFF default means no shipped build ever opens the position '
            'channel, which is D14: the map only moves on push or re-open');
    expect(resolveCourierPositionChannel(), isNotNull,
        reason: 'and the gate must actually hand the channel to the screen');
  });

  test('the define is still the ONE gate, and it can still withhold', () {
    sl.registerSingleton<CourierPositionChannel>(_StubChannel());

    // The gate tracks the flag in BOTH directions — this is what keeps
    // `--dart-define=JEEB_REALTIME_TRACKING=false` a working kill switch.
    expect(
      resolveCourierPositionChannel() != null,
      AppConfig.realtimeCourierPositionEnabled,
      reason: 'resolve must mirror the flag exactly; a gate that ignores it is '
          'either an unkillable feature or a permanently dead one',
    );

    // POSITIVE CONTROL that the flag is READ FROM THE DEFINE and is not a
    // hardcoded `true`: with no define supplied, the same expression declared
    // with the OLD default must disagree with the shipped value. If these ever
    // agree on an undefined build, AppConfig stopped reading the environment.
    if (!_defineSupplied) {
      const asOldDefault =
          bool.fromEnvironment('JEEB_REALTIME_TRACKING', defaultValue: false);
      expect(AppConfig.realtimeCourierPositionEnabled, isNot(asOldDefault),
          reason: 'the value must come from bool.fromEnvironment with a true '
              'default — not from a literal');
    }
  });
}

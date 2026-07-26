import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/core/lifecycle/lifecycle_poller.dart';

const _interval = Duration(seconds: 5);
const _twoIntervals = Duration(seconds: 10);

void main() {
  tearDown(AppLifecycleGate.debugReset);

  test('E10: a plain fake-time poller works with no root gate install', () {
    AppLifecycleGate.debugReset();

    FakeAsync().run((async) {
      var ticks = 0;
      final ambientBeforeStart = AppLifecycleGate.instance;
      final poller = LifecyclePoller(interval: _interval, onTick: () => ticks++)
        ..start();

      expect(AppLifecycleGate.instance, same(ambientBeforeStart));
      expect(poller.isForeground, isTrue);
      expect(poller.isRunning, isTrue);
      expect(ticks, isZero, reason: 'start must not fetch');

      async.elapse(_twoIntervals);

      expect(ticks, 2);
      expect(poller.debugTickCount, 2);
      poller.dispose();
      expect(AppLifecycleGate.debugListenerCount, isZero);
      expect(async.periodicTimerCount, isZero);
    });
  });
}

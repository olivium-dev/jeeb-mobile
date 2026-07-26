import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_poll_schedule.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_status_poll_controller.dart';

KycStatusPollController _controller({
  required Future<bool> Function() probe,
  KycPollSchedule schedule = KycPollSchedule.standard,
}) {
  return KycStatusPollController(
    intervalAt: schedule.intervalAt,
    maxResumeProbes: schedule.maxResumeProbes,
    probe: probe,
  );
}

void _elapse(FakeAsync async, Duration duration) {
  async.elapse(duration);
  async.flushMicrotasks();
}

void main() {
  test('FM5-F11-C1: the controller probes at 3s and not at 2.999s', () {
    fakeAsync((async) {
      var calls = 0;
      final controller = _controller(
        probe: () async {
          calls++;
          return true;
        },
      )..start();

      _elapse(async, const Duration(milliseconds: 2999));
      expect(calls, 0);
      _elapse(async, const Duration(milliseconds: 1));
      expect(calls, 1);
      controller.dispose();
    });
  });

  test('FM5-F11-C2: the controller re-arms after every completed probe', () {
    fakeAsync((async) {
      var calls = 0;
      final controller = _controller(
        probe: () async {
          calls++;
          return true;
        },
      )..start();

      _elapse(async, const Duration(seconds: 3));
      expect(calls, 1);
      _elapse(async, const Duration(seconds: 3));
      expect(calls, 2);
      _elapse(async, const Duration(seconds: 3));
      expect(calls, 3);
      controller.dispose();
    });
  });

  test('FM5-F11-C3: slow requests never overlap', () {
    fakeAsync((async) {
      final firstProbe = Completer<bool>();
      var calls = 0;
      final controller = _controller(
        probe: () {
          calls++;
          return calls == 1 ? firstProbe.future : Future<bool>.value(true);
        },
      )..start();

      _elapse(async, const Duration(seconds: 3));
      _elapse(async, const Duration(seconds: 57));
      expect(calls, 1);
      controller.pause();
      controller.resume();
      unawaited(controller.checkNow());
      expect(calls, 1);
      expect(controller.resumeProbes, 0);

      firstProbe.complete(true);
      async.flushMicrotasks();
      _elapse(async, const Duration(milliseconds: 2999));
      expect(calls, 1);
      _elapse(async, const Duration(milliseconds: 1));
      expect(calls, 2);
      controller.dispose();
    });
  });

  test('FM5-F11-C4: a terminal result cancels every timer', () {
    fakeAsync((async) {
      var calls = 0;
      final controller = _controller(
        probe: () async {
          calls++;
          return false;
        },
      )..start();

      _elapse(async, const Duration(seconds: 3));
      expect(calls, 1);
      _elapse(async, const Duration(hours: 1));
      expect(calls, 1);
      expect(controller.isExpired, isFalse);
      controller.dispose();
    });
  });

  test(
    'FM5-F11-C5: pause issues no probe and resume checks immediately without resetting the tier',
    () {
      fakeAsync((async) {
        var calls = 0;
        final controller = _controller(
          probe: () async {
            calls++;
            return true;
          },
        )..start();

        for (var probe = 0; probe < 10; probe++) {
          _elapse(async, const Duration(seconds: 3));
        }
        expect(calls, 10);
        controller.pause();
        _elapse(async, const Duration(minutes: 5));
        expect(calls, 10);

        controller.resume();
        async.flushMicrotasks();
        expect(calls, 11);
        _elapse(async, const Duration(milliseconds: 14999));
        expect(calls, 11);
        _elapse(async, const Duration(milliseconds: 1));
        expect(calls, 12);
        controller.dispose();
      });
    },
  );

  test(
    'FM5-F11-C6: a duplicate resumed without an intervening pause issues nothing',
    () {
      fakeAsync((async) {
        var calls = 0;
        final controller = _controller(
          probe: () async {
            calls++;
            return true;
          },
        )..start();

        controller.pause();
        controller.resume();
        async.flushMicrotasks();
        expect(calls, 1);
        controller.resume();
        async.flushMicrotasks();
        expect(calls, 1);
        expect(controller.resumeProbes, 1);
        controller.dispose();
      });
    },
  );

  test('FM5-F11-C7: resume probes stop after the resume budget is spent', () {
    fakeAsync((async) {
      var calls = 0;
      final controller = _controller(
        probe: () async {
          calls++;
          return true;
        },
      )..start();

      controller.pause();
      for (var cycle = 0; cycle < 12; cycle++) {
        controller.resume();
        async.flushMicrotasks();
        controller.pause();
      }
      expect(calls, 8);
      expect(controller.resumeProbes, 8);
      expect(controller.scheduledProbes, 0);
      controller.dispose();
    });
  });

  test(
    'FM5-F11-C8: dispose cancels every timer and a late completion cannot reschedule',
    () {
      fakeAsync((async) {
        var cancelledTimerCalls = 0;
        final timerController = _controller(
          probe: () async {
            cancelledTimerCalls++;
            return true;
          },
        )..start();
        timerController.dispose();
        _elapse(async, const Duration(seconds: 3));
        expect(cancelledTimerCalls, 0);

        final lateProbe = Completer<bool>();
        var lateCalls = 0;
        final lateController = _controller(
          probe: () {
            lateCalls++;
            return lateProbe.future;
          },
        )..start();
        _elapse(async, const Duration(seconds: 3));
        expect(lateCalls, 1);
        lateController.dispose();
        lateProbe.complete(true);
        async.flushMicrotasks();
        _elapse(async, const Duration(minutes: 1));
        expect(lateCalls, 1);
      });
    },
  );

  test(
    'FM5-F11-C9: a probe that never completes leaves the poller quiescent and in flight',
    () {
      fakeAsync((async) {
        final neverCompletes = Completer<bool>();
        var calls = 0;
        final controller = _controller(
          probe: () {
            calls++;
            return neverCompletes.future;
          },
        )..start();

        _elapse(async, const Duration(seconds: 3));
        expect(calls, 1);
        expect(controller.isInFlight, isTrue);
        _elapse(async, const Duration(hours: 1));
        expect(calls, 1);
        expect(controller.scheduledProbes, 1);
        expect(controller.isInFlight, isTrue);
        controller.dispose();
      });
    },
  );
}

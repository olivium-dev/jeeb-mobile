import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_poll_schedule.dart';

const _schedule = KycPollSchedule.standard;

Duration? _intervalAt(int seconds, {int scheduledProbes = 0}) {
  return _schedule.intervalAt(
    elapsed: Duration(seconds: seconds),
    scheduledProbes: scheduledProbes,
  );
}

Duration? _walkInterval(
  KycPollSchedule schedule,
  Duration elapsed,
  int probes,
) => schedule.intervalAt(elapsed: elapsed, scheduledProbes: probes);

_ScheduleWalk _walk(KycPollSchedule schedule) {
  var elapsed = Duration.zero;
  var probes = 0;
  var probesAtOneMinute = 0;
  var probesAtTenMinutes = 0;
  while (true) {
    final interval = _walkInterval(schedule, elapsed, probes);
    if (interval == null) break;
    elapsed += interval;
    probes++;
    if (elapsed <= const Duration(minutes: 1)) probesAtOneMinute = probes;
    if (elapsed <= const Duration(minutes: 10)) probesAtTenMinutes = probes;
  }
  return _ScheduleWalk(
    elapsed: elapsed,
    probes: probes,
    probesAtOneMinute: probesAtOneMinute,
    probesAtTenMinutes: probesAtTenMinutes,
  );
}

class _ScheduleWalk {
  const _ScheduleWalk({
    required this.elapsed,
    required this.probes,
    required this.probesAtOneMinute,
    required this.probesAtTenMinutes,
  });

  final Duration elapsed;
  final int probes;
  final int probesAtOneMinute;
  final int probesAtTenMinutes;
}

void main() {
  test('FM5-F11-P1: tier 1 probes every 3s for the first 30 seconds', () {
    expect(_intervalAt(0), const Duration(seconds: 3));
    expect(_intervalAt(3), const Duration(seconds: 3));
    expect(_intervalAt(27), const Duration(seconds: 3));
  });

  test('FM5-F11-P2: tier 2 probes every 15s from 30s to 5 minutes', () {
    expect(_intervalAt(30), const Duration(seconds: 15));
    expect(_intervalAt(45), const Duration(seconds: 15));
    expect(_intervalAt(285), const Duration(seconds: 15));
  });

  test('FM5-F11-P3: the tail cadence is 60s from 5 minutes onward', () {
    expect(_intervalAt(300), const Duration(seconds: 60));
    expect(_intervalAt(600), const Duration(seconds: 60));
    expect(_intervalAt(899), const Duration(seconds: 60));
  });

  test('FM5-F11-P4: tier boundaries are half-open', () {
    expect(_intervalAt(29), const Duration(seconds: 3));
    expect(_intervalAt(30), const Duration(seconds: 15));
    expect(_intervalAt(299), const Duration(seconds: 15));
    expect(_intervalAt(300), const Duration(seconds: 60));
    expect(_intervalAt(899), const Duration(seconds: 60));
    expect(_intervalAt(900), isNull);
  });

  test(
    'FM5-F11-P5: the schedule expires at exactly 15 minutes of accumulated foreground polling',
    () {
      expect(_intervalAt(899), isNotNull);
      expect(_intervalAt(900), isNull);
      expect(_intervalAt(901), isNull);
    },
  );

  test(
    'FM5-F11-P6: the shipped policy issues exactly 38 scheduled probes over exactly 900s',
    () {
      final walk = _walk(_schedule);
      expect(walk.probesAtOneMinute, 12);
      expect(walk.probesAtTenMinutes, 33);
      expect(walk.probes, 38);
      expect(walk.elapsed, const Duration(seconds: 900));
    },
  );

  test(
    'FM5-F11-P7: the probe tripwire expires the schedule independently of elapsed time',
    () {
      const schedule = KycPollSchedule(
        tiers: [
          KycPollTier(until: Duration(days: 1), interval: Duration(seconds: 1)),
        ],
        tailInterval: Duration(seconds: 1),
        maxElapsed: Duration(days: 2),
        maxScheduledProbes: 2,
        maxResumeProbes: 1,
      );
      expect(
        schedule.intervalAt(elapsed: Duration.zero, scheduledProbes: 1),
        const Duration(seconds: 1),
      );
      expect(
        schedule.intervalAt(elapsed: Duration.zero, scheduledProbes: 2),
        isNull,
      );
    },
  );

  test(
    'FM5-F11-P8: the first probe is scheduled 3s after mount, identical to the pre-back-off poller',
    () {
      expect(_intervalAt(0), const Duration(seconds: 3));
    },
  );
}

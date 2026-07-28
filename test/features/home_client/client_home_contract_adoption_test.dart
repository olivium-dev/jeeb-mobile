// N3 (b02 polling→push). This file used to be titled "AC1: ClientHomeCubit
// adopts LifecyclePoller lifecycle gating" and proved that the 10 s home poll
// paused on background and re-armed on foreground.
//
// `ClientHomeCubit` no longer adopts `LifecyclePoller` — there is no poll to
// gate. The contract that replaces it is stronger and is what this file now
// pins: the cubit reads on a PUSH and on nothing else, so an
// `AppLifecycleGate` transition — the thing the old poll needed a latch for —
// cannot produce a read at all.
//
// The old test's own foreground CONTROL is kept in spirit: a case that only
// asserted "zero reads while backgrounded" would pass identically against a
// cubit nobody wired, so a push is fired in the same window and MUST read.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';

/// Thirty times the retired 10 s cadence.
const _idleWindow = Duration(minutes: 5);

class _CountingClientHomeRepository implements ClientHomeRepository {
  int fetchCount = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    fetchCount++;
    return const ClientHomeSnapshot();
  }
}

void main() {
  tearDown(AppLifecycleGate.debugReset);

  test('AC1: ClientHomeCubit reads on a push and on NOTHING else — a lifecycle '
      'transition produces no read because there is no poll to gate', () {
    FakeAsync().run((async) {
      final repository = _CountingClientHomeRepository();
      final bus = StreamController<void>.broadcast();
      final gate = ManualAppLifecycleGate();
      AppLifecycleGate.install(gate);
      final cubit = ClientHomeCubit(
        repository: repository,
        greetingNameProvider: () => 'Sami',
        refreshSignals: bus.stream,
      );

      async.elapse(_idleWindow);
      async.flushMicrotasks();
      expect(
        repository.fetchCount,
        isZero,
        reason: 'a cubit nobody loaded and nobody pushed to reads nothing, '
            'five minutes of wall clock notwithstanding',
      );

      // POSITIVE CONTROL: the wiring is live.
      bus.add(null);
      async.flushMicrotasks();
      expect(repository.fetchCount, 1, reason: 'push drives exactly one read');

      // The transitions the old poll latch existed for are now inert.
      gate.setForeground(false);
      async.elapse(_idleWindow);
      async.flushMicrotasks();
      expect(repository.fetchCount, 1);

      gate.setForeground(true);
      async.elapse(_idleWindow);
      async.flushMicrotasks();
      expect(
        repository.fetchCount,
        1,
        reason: 'foregrounding re-arms nothing; the RESUME one-shot lives in '
            'client_home_screen, not in a lifecycle gate on the cubit',
      );

      // …and the bus still works after all of that (second control).
      bus.add(null);
      async.flushMicrotasks();
      expect(repository.fetchCount, 2);

      unawaited(cubit.close());
      bus.close();
      async.flushMicrotasks();
    });
  });
}

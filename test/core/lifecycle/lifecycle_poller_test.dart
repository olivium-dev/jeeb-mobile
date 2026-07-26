import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/core/lifecycle/lifecycle_poller.dart';
import 'package:jeeb_mobile/core/lifecycle/polling_visibility.dart';
import 'package:jeeb_mobile/core/lifecycle/polling_visibility_gate.dart';

const _interval = Duration(seconds: 10);
const _shortOfInterval = Duration(seconds: 9);
const _twoIntervals = Duration(seconds: 20);
const _threeIntervals = Duration(seconds: 30);
const _replacementInterval = Duration(seconds: 4);
const _shortOfReplacementInterval = Duration(seconds: 3);

void main() {
  tearDown(AppLifecycleGate.debugReset);

  test('start is idempotent, never fetches, and schedules one timer', () {
    FakeAsync().run((async) {
      var ticks = 0;
      final poller = LifecyclePoller(
        interval: _interval,
        onTick: () => ticks++,
        gate: ManualAppLifecycleGate(),
      );

      poller
        ..start()
        ..start();

      expect(ticks, isZero);
      expect(poller.isStarted, isTrue);
      expect(poller.isVisible, isTrue);
      expect(poller.isForeground, isTrue);
      expect(poller.isRunning, isTrue);

      async.elapse(_twoIntervals);

      expect(ticks, 2);
      expect(poller.debugTickCount, 2);
      expect(async.periodicTimerCount, 1);
      poller.dispose();
      expect(async.periodicTimerCount, isZero);
    });
  });

  test('visible and foreground latches independently cancel and re-arm', () {
    FakeAsync().run((async) {
      var ticks = 0;
      final gate = ManualAppLifecycleGate();
      final poller = LifecyclePoller(
        interval: _interval,
        onTick: () => ticks++,
        gate: gate,
      )..start();

      async.elapse(_interval);
      expect(ticks, 1);

      poller.setPollingVisible(false);
      expect(poller.isRunning, isFalse);
      async.elapse(_twoIntervals);
      expect(ticks, 1);

      gate.setForeground(false);
      poller.setPollingVisible(true);
      expect(poller.isRunning, isFalse);

      gate.setForeground(true);
      expect(poller.isRunning, isTrue);
      async.elapse(_shortOfInterval);
      expect(ticks, 1, reason: 'resume must arm a fresh full interval');
      async.elapse(const Duration(seconds: 1));
      expect(ticks, 2);

      poller.dispose();
    });
  });

  test('terminal stop is sticky and safe before start or after dispose', () {
    FakeAsync().run((async) {
      var ticks = 0;
      final gate = ManualAppLifecycleGate();
      final poller = LifecyclePoller(
        interval: _interval,
        onTick: () => ticks++,
        gate: gate,
      );

      poller
        ..stop()
        ..start()
        ..stop()
        ..stop()
        ..setPollingVisible(false)
        ..setPollingVisible(true);
      gate
        ..setForeground(false)
        ..setForeground(true);
      async.elapse(_twoIntervals);

      expect(ticks, isZero);
      expect(poller.isStarted, isFalse);
      expect(poller.isRunning, isFalse);

      poller
        ..dispose()
        ..dispose()
        ..stop()
        ..start()
        ..restart()
        ..setInterval(_replacementInterval)
        ..setPollingVisible(false);
      expect(poller.isDisposed, isTrue);
      expect(poller.isRunning, isFalse);
    });
  });

  test('restart and interval changes arm a fresh full interval', () {
    FakeAsync().run((async) {
      var ticks = 0;
      final poller = LifecyclePoller(
        interval: _interval,
        onTick: () => ticks++,
        gate: ManualAppLifecycleGate(),
      )..start();

      async.elapse(_shortOfInterval);
      poller.restart();
      async.elapse(_shortOfInterval);
      expect(ticks, isZero);
      async.elapse(const Duration(seconds: 1));
      expect(ticks, 1);

      poller.setInterval(_replacementInterval);
      expect(poller.interval, _replacementInterval);
      async.elapse(_shortOfReplacementInterval);
      expect(ticks, 1);
      async.elapse(const Duration(seconds: 1));
      expect(ticks, 2);

      poller.setInterval(_replacementInterval);
      async.elapse(_replacementInterval);
      expect(ticks, 3, reason: 'same interval must not churn the timer');

      poller
        ..stop()
        ..restart()
        ..setInterval(_interval)
        ..start();
      async.elapse(_shortOfInterval);
      expect(ticks, 3);
      async.elapse(const Duration(seconds: 1));
      expect(ticks, 4);
      poller.dispose();
    });
  });

  test(
    'tickOnResume fires for gate changes but never for start or restart',
    () {
      FakeAsync().run((async) {
        var ticks = 0;
        final gate = ManualAppLifecycleGate();
        final poller = LifecyclePoller(
          interval: _interval,
          onTick: () => ticks++,
          gate: gate,
          tickOnResume: true,
        )..start();

        expect(ticks, isZero);
        poller.restart();
        expect(ticks, isZero);

        poller.setPollingVisible(false);
        poller.setPollingVisible(true);
        expect(ticks, 1);

        gate.setForeground(false);
        gate.setForeground(true);
        expect(ticks, 2);

        poller.setInterval(_replacementInterval);
        expect(ticks, 2);
        poller.dispose();
      });
    },
  );

  test('a hung tick blocks overlap and background clears the latch', () {
    FakeAsync().run((async) {
      final completions = <Completer<void>>[];
      final gate = ManualAppLifecycleGate();
      final poller = LifecyclePoller(
        interval: _interval,
        onTick: () {
          final completion = Completer<void>();
          completions.add(completion);
          return completion.future;
        },
        gate: gate,
      )..start();

      async.elapse(_threeIntervals);
      expect(completions, hasLength(1));

      gate
        ..setForeground(false)
        ..setForeground(true);
      async.elapse(_interval);
      expect(completions, hasLength(2));

      completions.first.complete();
      async.flushMicrotasks();
      async.elapse(_interval);
      expect(
        completions,
        hasLength(2),
        reason: 'stale completion must not release the current generation',
      );

      completions.last.complete();
      async.flushMicrotasks();
      async.elapse(_interval);
      expect(completions, hasLength(3));
      poller.dispose();
    });
  });

  test('synchronous and asynchronous errors do not kill the schedule', () {
    FakeAsync().run((async) {
      var ticks = 0;
      final poller = LifecyclePoller(
        interval: _interval,
        onTick: () {
          ticks++;
          if (ticks == 1) throw StateError('sync');
          if (ticks == 2) return Future<void>.error(StateError('async'));
        },
        gate: ManualAppLifecycleGate(),
      )..start();

      async.elapse(_interval);
      async.elapse(_interval);
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(ticks, 3);
      expect(poller.isRunning, isTrue);
      poller.dispose();
    });
  });

  test('dispose cancels the timer and detaches the ambient listener', () {
    FakeAsync().run((async) {
      final poller = LifecyclePoller(interval: _interval, onTick: () {})
        ..start();

      expect(AppLifecycleGate.debugListenerCount, 1);
      expect(async.periodicTimerCount, 1);

      poller
        ..dispose()
        ..dispose();

      expect(AppLifecycleGate.debugListenerCount, isZero);
      expect(async.periodicTimerCount, isZero);
    });
  });

  testWidgets('visibility gate latches updates, swaps targets, and disposes', (
    tester,
  ) async {
    final first = _RecordingVisibility();
    final second = _RecordingVisibility();
    const childKey = Key('unchanged-child');

    await tester.pumpWidget(
      PollingVisibilityGate(
        target: first,
        isVisible: true,
        child: const SizedBox(key: childKey),
      ),
    );
    expect(first.values, <bool>[true]);
    expect(find.byKey(childKey), findsOneWidget);

    await tester.pumpWidget(
      PollingVisibilityGate(
        target: first,
        isVisible: true,
        child: const SizedBox(key: childKey),
      ),
    );
    expect(first.values, <bool>[true]);

    await tester.pumpWidget(
      PollingVisibilityGate(
        target: first,
        isVisible: false,
        child: const SizedBox(key: childKey),
      ),
    );
    expect(first.values, <bool>[true, false]);

    await tester.pumpWidget(
      PollingVisibilityGate(
        target: second,
        isVisible: true,
        child: const SizedBox(key: childKey),
      ),
    );
    expect(first.values, <bool>[true, false, false]);
    expect(second.values, <bool>[true]);

    await tester.pumpWidget(const SizedBox());
    expect(second.values, <bool>[true, false]);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingVisibility implements PollingVisibility {
  final List<bool> values = <bool>[];

  @override
  void setPollingVisible(bool visible) => values.add(visible);
}

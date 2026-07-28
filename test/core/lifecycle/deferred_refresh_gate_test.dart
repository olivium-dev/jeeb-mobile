// The gate's own contract, both directions, planted.
//
// Per I-14/G23.1 (`docs/batches/b02-20260726/TESTING-INSTRUMENTS.md`): a pair
// proves a test checks both directions; only a mutation proves it can fail. The
// mutation transcripts for the two ADOPTERS live beside this file's evidence
// (RED-01 client-home, RED-03 chat-summary). What is asserted here is the
// mechanism itself, so that a future change to an adopter cannot be blamed on
// mystery behaviour in the gate.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/deferred_refresh_gate.dart';

void main() {
  late StreamController<void> bus;
  late int refreshCount;

  setUp(() {
    bus = StreamController<void>.broadcast();
    refreshCount = 0;
  });

  tearDown(() async => bus.close());

  DeferredRefreshGate build({bool visible = true}) => DeferredRefreshGate(
    onRefresh: () => refreshCount++,
    signals: bus.stream,
    visible: visible,
    debugLabel: 'test',
  );

  test(
    'visible (the default): every signal reads — unchanged behaviour',
    () async {
      final gate = build();
      addTearDown(gate.dispose);

      bus.add(null);
      bus.add(null);
      await pumpEventQueue();

      expect(refreshCount, 2);
      expect(gate.debugDeferredCount, 0);
    },
  );

  test('hidden: a signal reads NOTHING and records a debt', () async {
    final gate = build()..setPollingVisible(false);
    addTearDown(gate.dispose);

    bus.add(null);
    await pumpEventQueue();

    expect(refreshCount, 0);
    expect(gate.debugPending, isTrue);
    expect(gate.debugDeferredCount, 1);
  });

  test('hidden: FIVE signals collapse to ONE debt, then ONE read', () async {
    final gate = build()..setPollingVisible(false);
    addTearDown(gate.dispose);

    for (var i = 0; i < 5; i++) {
      bus.add(null);
    }
    await pumpEventQueue();
    expect(refreshCount, 0);
    expect(gate.debugSignalCount, 5);
    expect(gate.debugDeferredCount, 1, reason: 'one debt, not five');

    gate.setPollingVisible(true);
    await pumpEventQueue();

    expect(refreshCount, 1);
    expect(gate.debugPending, isFalse);
  });

  test(
    'becoming visible with NO debt reads nothing — visibility is not an event',
    () async {
      final gate = build()..setPollingVisible(false);
      addTearDown(gate.dispose);

      gate.setPollingVisible(true);
      await pumpEventQueue();

      expect(refreshCount, 0);
    },
  );

  test('a repeated visibility value is idempotent', () async {
    final gate = build()..setPollingVisible(false);
    addTearDown(gate.dispose);
    bus.add(null);
    await pumpEventQueue();

    gate
      ..setPollingVisible(true)
      ..setPollingVisible(true)
      ..setPollingVisible(true);
    await pumpEventQueue();

    expect(refreshCount, 1, reason: 'the debt is paid once, not per rebuild');
  });

  test('hide → show → hide → show pays each cycle at most once', () async {
    final gate = build();
    addTearDown(gate.dispose);

    for (var cycle = 0; cycle < 3; cycle++) {
      gate.setPollingVisible(false);
      bus.add(null);
      bus.add(null);
      await pumpEventQueue();
      gate.setPollingVisible(true);
      await pumpEventQueue();
    }

    expect(
      refreshCount,
      3,
      reason: 'three exposures, three reads (six signals)',
    );
  });

  test('dispose abandons the debt and stops listening', () async {
    final gate = build()..setPollingVisible(false);
    bus.add(null);
    await pumpEventQueue();
    expect(gate.debugPending, isTrue);

    await gate.dispose();
    gate.setPollingVisible(true);
    bus.add(null);
    await pumpEventQueue();

    expect(
      refreshCount,
      0,
      reason: 'an unmounted surface has no pixels that could be stale',
    );
  });

  test('a null stream is inert, not a crash (bare test / no DI)', () async {
    final gate = DeferredRefreshGate(onRefresh: () => refreshCount++);
    addTearDown(gate.dispose);

    gate
      ..setPollingVisible(false)
      ..setPollingVisible(true);
    await pumpEventQueue();

    expect(refreshCount, 0);
  });

  test('bind is idempotent — a second bind cannot double-subscribe', () async {
    final gate = build();
    addTearDown(gate.dispose);

    gate
      ..bind(bus.stream)
      ..bind(bus.stream);
    bus.add(null);
    await pumpEventQueue();

    expect(refreshCount, 1, reason: 'one signal, one read');
  });
}

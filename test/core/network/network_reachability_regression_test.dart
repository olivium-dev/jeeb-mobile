import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/features/offline_mode/application/offline_cubit.dart';

void main() {
  late DateTime now;
  late NetworkReachabilitySignals bus;

  setUp(() {
    now = DateTime.utc(2026, 9, 6);
    bus = NetworkReachabilitySignals(clock: () => now);
  });
  tearDown(() => bus.dispose());

  test('the state channel deduplicates observations but never throttles', () {
    final states = <bool>[];
    final sub = bus.stateStream.listen(states.add);
    addTearDown(sub.cancel);
    bus.debugObserve(online: true);
    expect(states, isEmpty);
    bus.debugObserve(online: false);
    bus.debugObserve(online: false);
    bus.debugObserve(online: true);
    now = now.add(const Duration(milliseconds: 100));
    bus.debugObserve(online: false);
    bus.debugObserve(online: true);
    bus.debugObserve(online: true);
    expect(states, [false, true, false, true]);
    expect(bus.emitCount, 1);
    expect(bus.suppressedCount, 1);
  });

  for (final online in [true, false]) {
    test('a cold $online seed agrees with the state snapshot', () async {
      final states = <bool>[];
      final sub = bus.stateStream.listen(states.add);
      addTearDown(sub.cancel);
      bus.bindSource(const Stream<bool>.empty(), seed: Future.value(online));
      await Future<void>.delayed(Duration.zero);
      expect(bus.isOnline, online);
      expect(states, online ? <bool>[] : [false]);
    });
  }

  test('a late seed never replaces a live observation', () async {
    final source = StreamController<bool>(sync: true);
    final seed = Completer<bool>();
    addTearDown(source.close);
    final states = <bool>[];
    final sub = bus.stateStream.listen(states.add);
    addTearDown(sub.cancel);
    bus.bindSource(source.stream, seed: seed.future);
    source.add(false);
    seed.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(states, [false]);
    expect(bus.isOnline, isFalse);
  });

  test(
    'a rapid flap clears the offline cubit even when refresh is dropped',
    () {
      final cubit = OfflineCubit()..bindReachability(bus);
      addTearDown(cubit.close);
      bus.debugObserve(online: false);
      bus.debugObserve(online: true);
      now = now.add(const Duration(milliseconds: 100));
      bus.debugObserve(online: false);
      expect(cubit.state.status, ConnectivityStatus.offline);
      bus.debugObserve(online: true);
      expect(bus.suppressedCount, 1);
      expect(cubit.state.status, ConnectivityStatus.online);
      now = now.add(const Duration(minutes: 5));
      bus.debugObserve(online: true);
      expect(cubit.state.status, ConnectivityStatus.online);
    },
  );

  test('binding to an already-offline bus immediately seeds the cubit', () {
    bus.debugObserve(online: false);
    final cubit = OfflineCubit()..bindReachability(bus);
    addTearDown(cubit.close);
    expect(cubit.state.status, ConnectivityStatus.offline);
    bus.debugObserve(online: false);
    expect(cubit.state.status, ConnectivityStatus.offline);
    bus.debugObserve(online: true);
    expect(cubit.state.status, ConnectivityStatus.online);
  });

  test('rebinding replaces the earlier subscription and seeds its state', () {
    final other = NetworkReachabilitySignals();
    addTearDown(other.dispose);
    final cubit = OfflineCubit()..bindReachability(bus);
    addTearDown(cubit.close);
    expect(cubit.state.status, ConnectivityStatus.online);
    expect(cubit.state.bannerDismissed, isFalse);
    other.debugObserve(online: false);
    cubit.bindReachability(other);
    expect(cubit.state.status, ConnectivityStatus.offline);
    bus.debugObserve(online: false);
    bus.debugObserve(online: true);
    expect(cubit.state.status, ConnectivityStatus.offline);
    other.debugObserve(online: true);
    expect(cubit.state.status, ConnectivityStatus.online);
  });

  test(
    'closing cancels the subscription before a later state transition',
    () async {
      final cubit = OfflineCubit()..bindReachability(bus);
      await cubit.close();
      bus.debugObserve(online: false);
      expect(bus.isOnline, isFalse);
      expect(cubit.isClosed, isTrue);
    },
  );
}

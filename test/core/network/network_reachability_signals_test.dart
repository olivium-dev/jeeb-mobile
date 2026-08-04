// The reconnect bus: an EDGE detector, not a state mirror.
library;

import 'dart:async';

// The plugin import here is deliberate and is the ONLY one outside
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/connectivity_reachability_source.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';

void main() {
  late DateTime now;
  late NetworkReachabilitySignals bus;
  late List<void> received;
  late StreamSubscription<void> sub;

  setUp(() {
    now = DateTime(2026, 7, 28, 12);
    bus = NetworkReachabilitySignals(clock: () => now);
    received = <void>[];
    sub = bus.stream.listen(received.add);
  });

  tearDown(() async {
    await sub.cancel();
    await bus.dispose();
  });

  group('the edge filter', () {
    test('the FIRST observation is a baseline and never emits', () {
      bus.debugObserve(online: true);
      expect(bus.emitCount, 0);
      bus.debugObserve(online: false);
      expect(
        bus.emitCount,
        0,
        reason: 'going offline is not a reconnect either',
      );
    });

    test('a first observation of OFFLINE also never emits', () {
      bus.debugObserve(online: false);
      expect(
        bus.emitCount,
        0,
        reason:
            'the app opening while already offline is the exact scenario this '
            'bus exists for, and it is not itself a reconnect',
      );
    });

    test('offline -> online emits exactly once', () {
      bus.debugObserve(online: false);
      bus.debugObserve(online: true);
      expect(bus.emitCount, 1);
      expect(received, hasLength(1));
    });

    test('online -> online is deduped', () {
      bus.debugObserve(online: false);
      bus.debugObserve(online: true);
      now = now.add(kNetworkReachabilityMinInterval);
      bus.debugObserve(online: true);
      bus.debugObserve(online: true);
      expect(
        bus.emitCount,
        1,
        reason:
            'a transport swap that never passes through offline is not a '
            'reconnect — the network never went away',
      );
    });

    test('a full flap cycle emits once per genuine edge', () {
      for (var i = 0; i < 3; i++) {
        now = now.add(kNetworkReachabilityMinInterval);
        bus.debugObserve(online: false);
        bus.debugObserve(online: true);
      }
      expect(bus.emitCount, 3);
    });
  });

  group('the throttle', () {
    test('a second edge inside the window is suppressed, not queued', () {
      bus.debugObserve(online: false);
      bus.debugObserve(online: true);
      expect(bus.emitCount, 1);

      // A second genuine edge, well inside the floor.
      now = now.add(const Duration(milliseconds: 100));
      bus.debugObserve(online: false);
      bus.debugObserve(online: true);

      expect(bus.emitCount, 1, reason: 'throttled');
      expect(bus.suppressedCount, 1);

      // DROPPED, not deferred: nothing arrives later on its own. This is safe
      now = now.add(const Duration(minutes: 5));
      expect(bus.emitCount, 1);
    });

    test('an edge past the floor is accepted', () {
      bus.debugObserve(online: false);
      bus.debugObserve(online: true);
      now = now.add(kNetworkReachabilityMinInterval);
      bus.debugObserve(online: false);
      bus.debugObserve(online: true);
      expect(bus.emitCount, 2);
      expect(bus.suppressedCount, 0);
    });
  });

  group('bindSource', () {
    test('drives the bus from a plain Stream<bool>', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      bus.bindSource(controller.stream);

      controller.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(bus.emitCount, 0, reason: 'baseline');

      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(bus.emitCount, 1);
    });

    test('a source ERROR degrades to silence and keeps the subscription', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      bus.bindSource(controller.stream);

      controller.addError(Exception('platform channel unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(bus.emitCount, 0);

      // The subscription must survive: `cancelOnError: false`. Otherwise one
      controller.add(false);
      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(bus.emitCount, 1, reason: 'still live after an error');
    });

    test('the seed establishes the baseline so a cold-offline start still '
        'produces a real edge', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      // The app starts while ALREADY offline: the OS may never emit a `false`,
      bus.bindSource(controller.stream, seed: Future<bool>.value(false));
      await Future<void>.delayed(Duration.zero);
      expect(bus.debugOnline, isFalse);

      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(bus.emitCount, 1);
    });

    test('a seed that FAILS leaves the baseline unknown rather than guessing', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      bus.bindSource(
        controller.stream,
        seed: Future<bool>.error(Exception('MissingPluginException')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        bus.debugOnline,
        isNull,
        reason:
            'an unavailable platform channel must not be recorded as either '
            'state; the first real event becomes the baseline instead',
      );
    });

    test('a live event beats a late seed', () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final lateSeed = Completer<bool>();
      bus.bindSource(controller.stream, seed: lateSeed.future);

      controller.add(false);
      await Future<void>.delayed(Duration.zero);
      // The seed resolves AFTER a real observation already landed.
      lateSeed.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(
        bus.debugOnline,
        isFalse,
        reason: 'the stale seed must not clobber a newer real observation',
      );

      controller.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(bus.emitCount, 1, reason: 'the edge is still recognised');
    });
  });

  group('ConnectivityReachabilitySource mapping', () {
    test('`none` alone is offline', () {
      expect(
        ConnectivityReachabilitySource.isOnline(const [ConnectivityResult.none]),
        isFalse,
      );
    });

    test('any non-`none` transport is online', () {
      expect(
        ConnectivityReachabilitySource.isOnline(const [ConnectivityResult.wifi]),
        isTrue,
      );
      expect(
        ConnectivityReachabilitySource.isOnline(const [
          ConnectivityResult.mobile,
          ConnectivityResult.vpn,
        ]),
        isTrue,
      );
    });

    test('an empty list is treated as offline', () {
      expect(
        ConnectivityReachabilitySource.isOnline(const []),
        isFalse,
        reason:
            'the plugin documents that the list is never empty, but a mapper '
            'that answered "online" to "the OS told me nothing" would be '
            'inventing a reconnect out of a contract violation',
      );
    });
  });

  group('the ambient instance', () {
    tearDown(NetworkReachabilitySignals.debugReset);

    test('is created UNBOUND, so a host with no plugin never emits', () {
      final ambient = NetworkReachabilitySignals.instance;
      expect(
        identical(NetworkReachabilitySignals.instance, ambient),
        isTrue,
        reason: 'process-wide singleton',
      );
      expect(
        ambient.emitCount,
        0,
        reason:
            'a bare widget test with no DI and no platform channel must get a '
            'bus that is silent rather than one that throws',
      );
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

class _FakePositionRepo implements LiveTrackingRepository, LivePositionSource {
  /// Served on the next read. `null` models the case the gateway actually
  /// produced through two whole device rounds: HTTP 200 with `"position":null`
  DeliveryLivePosition? nextPosition;

  /// When set, `fetchLivePosition` THROWS instead of answering — the seam the
  /// cubit's catch arm exists for.
  Object? throwOnRead;

  int positionReads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.inTransit,
    stageTimestamps: const {},
    lifecycle: TrackingLifecycle.active,
  );

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    positionReads++;
    final boom = throwOnRead;
    if (boom != null) throw boom;
    return nextPosition;
  }
}

/// A repo that is deliberately NOT a [LivePositionSource] — the debug demo repo,
/// the devtool seams and the `:4010` mock are all this shape.
class _StatusOnlyRepo implements LiveTrackingRepository {
  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.inTransit,
    stageTimestamps: const {},
    lifecycle: TrackingLifecycle.active,
  );
}

/// Captures the `[jeeb-diag]` lines the cubit emits and decodes them back into
/// the records a device capture would carry.
class _DiagCapture {
  final List<Map<String, Object?>> records = [];

  void install() {
    Diag.enabledOverride = true;
    Diag.sink = (line) {
      final json = line.substring(line.indexOf('{'));
      records.add(jsonDecode(json) as Map<String, Object?>);
    };
  }

  void restore() => Diag.resetForTest();

  /// Only the `evt` records with [name], in emission order.
  List<Map<String, Object?>> named(String name) => records
      .where((r) => r['t'] == 'evt' && r['name'] == name)
      .map((r) => (r['data'] as Map).cast<String, Object?>())
      .toList();
}

const _lat = 33.8938;
const _lng = 35.5018;

DeliveryLivePosition _fix({double lat = _lat, double lng = _lng}) =>
    DeliveryLivePosition(
      jeeberPosition: GpsPoint(lat: lat, lng: lng),
      polyline: [
        GpsPoint(lat: lat, lng: lng),
        const GpsPoint(lat: 33.9, lng: 35.6),
      ],
    );

void main() {
  late _DiagCapture diag;

  setUp(() {
    diag = _DiagCapture()..install();
  });

  tearDown(() => diag.restore());

  group('MB1 W1.1b — tracking_screen_open is the DENOMINATOR', () {
    test(
      'exactly ONE per cubit construction, carrying the deliveryId',
      () async {
        final cubit = LiveTrackingCubit(
          repository: _FakePositionRepo()..nextPosition = _fix(),
          deliveryId: 'DLV-OPEN-1',
        );
        await pumpEventQueue();

        final opens = diag.named(kTrackingScreenOpenEvent);
        expect(
          opens,
          hasLength(1),
          reason:
              'V-2 divides the position count by this number. Two entries '
              'for one dwell silently halves the measurement; zero makes it '
              'undefined.',
        );
        expect(opens.single['deliveryId'], 'DLV-OPEN-1');
        await cubit.close();
      },
    );

    test(
      'a push, a resume and a retry do NOT mint additional entries',
      () async {
        final bus = StreamController<void>.broadcast();
        final repo = _FakePositionRepo()..nextPosition = _fix();
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: 'DLV-OPEN-2',
          refreshSignals: bus.stream,
        );
        await pumpEventQueue();

        bus.add(null);
        await pumpEventQueue();
        await cubit.refreshNow();
        cubit.retry();
        await pumpEventQueue();

        expect(
          diag.named(kTrackingScreenOpenEvent),
          hasLength(1),
          reason:
              'the denominator counts SCREEN ENTRIES, not reads — if a '
              'push minted one, three positions across three pushes would '
              'read as three separate dwells and prove nothing.',
        );
        // Positive control on the same run: the reads themselves DID happen.
        expect(
          diag.named(kTrackingPositionEvent).length,
          greaterThanOrEqualTo(4),
        );

        await bus.close();
        await cubit.close();
      },
    );

    test('two cubits = two entries (the counter is not pinned at 1)', () async {
      final a = LiveTrackingCubit(
        repository: _FakePositionRepo(),
        deliveryId: 'DLV-A',
      );
      final b = LiveTrackingCubit(
        repository: _FakePositionRepo(),
        deliveryId: 'DLV-B',
      );
      await pumpEventQueue();

      final opens = diag.named(kTrackingScreenOpenEvent);
      expect(opens, hasLength(2));
      expect(opens.map((o) => o['deliveryId']), ['DLV-A', 'DLV-B']);

      await a.close();
      await b.close();
    });
  });

  group('MB1 W1.1b — tracking_position fires on EVERY attempt', () {
    test(
      'a null read is STILL recorded, with applied:false and null lat/lng',
      () async {
        final cubit = LiveTrackingCubit(
          repository: _FakePositionRepo()..nextPosition = null,
          deliveryId: 'DLV-NULL',
        );
        await pumpEventQueue();

        final positions = diag.named(kTrackingPositionEvent);
        expect(positions, hasLength(1));
        expect(positions.single['applied'], isFalse);
        expect(positions.single['lat'], isNull);
        expect(positions.single['lng'], isNull);
        expect(positions.single['polyline'], 0);
        expect(
          positions.single.containsKey('error'),
          isFalse,
          reason:
              'a null answer is not an error — the key must be ABSENT so a '
              'parser can treat its presence as the failure signal.',
        );
        await cubit.close();
      },
    );

    test('an EMPTY overlay is recorded with applied:false', () async {
      final cubit = LiveTrackingCubit(
        repository: _FakePositionRepo()
          ..nextPosition = const DeliveryLivePosition(),
        deliveryId: 'DLV-EMPTY',
      );
      await pumpEventQueue();

      final positions = diag.named(kTrackingPositionEvent);
      expect(positions, hasLength(1));
      expect(
        positions.single['applied'],
        isFalse,
        reason:
            'a dropped merge never reached the map, so MB1 MARKER must '
            'not count its coordinates.',
      );
      await cubit.close();
    });

    test(
      'a THROWING read is recorded and NAMED, and does not fault the screen',
      () async {
        final cubit = LiveTrackingCubit(
          repository: _FakePositionRepo()
            ..throwOnRead = const FormatException(),
          deliveryId: 'DLV-THROW',
        );
        await pumpEventQueue();

        final positions = diag.named(kTrackingPositionEvent);
        expect(positions, hasLength(1));
        expect(positions.single['error'], 'FormatException');
        expect(positions.single['applied'], isFalse);
        expect(
          cubit.state.mode,
          LiveTrackingViewMode.ready,
          reason:
              'a dead position read must never fault a screen whose '
              'stepper and summary are fine.',
        );
        await cubit.close();
      },
    );

    test('a repo that is not a LivePositionSource emits NOTHING', () async {
      final cubit = LiveTrackingCubit(
        repository: _StatusOnlyRepo(),
        deliveryId: 'DLV-NOSRC',
      );
      await pumpEventQueue();

      expect(
        diag.named(kTrackingPositionEvent),
        isEmpty,
        reason:
            'no read was ATTEMPTED, so a record would be a phantom row '
            'in V-2 denominator for every devtool seam and demo repo.',
      );
      // Positive control: the screen-open record still fired, so the absence
      expect(diag.named(kTrackingScreenOpenEvent), hasLength(1));
      await cubit.close();
    });
  });

  group('MB1 W1.1b — `cause` names the real trigger, and none is a clock', () {
    test(
      'screen open -> open; push -> push; resume -> resume; retry -> retry',
      () async {
        final bus = StreamController<void>.broadcast();
        final repo = _FakePositionRepo()..nextPosition = _fix();
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: 'DLV-CAUSE',
          refreshSignals: bus.stream,
        );
        await pumpEventQueue();

        bus.add(null);
        await pumpEventQueue();
        await cubit.refreshNow();
        await pumpEventQueue();
        cubit.retry();
        await pumpEventQueue();

        final causes = diag
            .named(kTrackingPositionEvent)
            .map((p) => p['cause'])
            .toList();
        expect(
          causes,
          ['open', 'push', 'resume', 'retry'],
          reason:
              "V-2's WIRE leg requires at least one cause:'push'. If every "
              'record said "open" the push attribution leg would be '
              'unprovable, which is exactly what MB1 amendment 2 records.',
        );

        await bus.close();
        await cubit.close();
      },
    );

    test('the enum is EXHAUSTIVE — four causes, none of them a timer', () {
      expect(LivePositionReadCause.values.map((c) => c.wire).toList(), [
        'open',
        'push',
        'resume',
        'retry',
      ]);
      expect(
        LivePositionReadCause.values
            .map((c) => c.name.toLowerCase())
            .any(
              (n) =>
                  n.contains('tick') ||
                  n.contains('poll') ||
                  n.contains('timer'),
            ),
        isFalse,
        reason:
            'if a fifth arm ever appears, the reviewer question is '
            'whether it is a cadence in disguise. This assertion is the '
            'place that question gets asked.',
      );
    });
  });

  group('MB1 MARKER — distinct (lat,lng) survive to the capture', () {
    test(
      'two moves produce two DISTINCT applied:true coordinate pairs',
      () async {
        final bus = StreamController<void>.broadcast();
        final repo = _FakePositionRepo()..nextPosition = _fix();
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: 'DLV-MOVE',
          refreshSignals: bus.stream,
        );
        await pumpEventQueue();

        repo.nextPosition = _fix(lat: 33.9100, lng: 35.5300);
        bus.add(null);
        await pumpEventQueue();

        final applied = diag
            .named(kTrackingPositionEvent)
            .where((p) => p['applied'] == true)
            .map((p) => '${p['lat']},${p['lng']}')
            .toSet();
        expect(
          applied,
          hasLength(2),
          reason:
              'THE MARKER leg counts exactly this set. Two reads of the '
              'SAME fix are one point, which is why the R1 recipe requires '
              'the jeeber to move >=10 m between reads (distanceFilter: 10).',
        );

        await bus.close();
        await cubit.close();
      },
    );

    test('coordinates are NOT redacted on the way through Diag', () async {
      final cubit = LiveTrackingCubit(
        repository: _FakePositionRepo()..nextPosition = _fix(),
        deliveryId: 'DLV-REDACT',
      );
      await pumpEventQueue();

      final p = diag.named(kTrackingPositionEvent).single;
      expect(p['lat'], closeTo(_lat, 1e-9));
      expect(p['lng'], closeTo(_lng, 1e-9));
      expect(p['deliveryId'], 'DLV-REDACT');
      expect(
        p['lat'],
        isA<num>(),
        reason: 'a String here means scrubMap turned it into a tok: handle.',
      );
      await cubit.close();
    });
  });

  group('the non-claim, stated explicitly', () {
    test('this file issues NO network and constructs NO Firestore path', () {
      expect(_FakePositionRepo(), isA<LivePositionSource>());
      expect(_StatusOnlyRepo(), isNot(isA<LivePositionSource>()));
    });
  });
}

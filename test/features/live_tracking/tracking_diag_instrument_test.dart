// MB1 W1.1 — the DIAG INSTRUMENT for the tracking surface.
//
// Why this file exists at all. MB1's device contract asks a verifier to count
// three things on a phone: ≥3 distinct `jeeberPosition` values inside ONE
// continuous foreground dwell, a screen-entry count of exactly 1, and ≥1 update
// attributable to the push-refresh signal. Before W1.1, NONE of the three was
// observable:
//
//   git grep -nE "Diag\.event\([^)]*position" origin/main -- lib/   -> 0
//   git grep -n "screen_open|screen_entry|nav_enter"  origin/main -- lib/ -> 0
//
// `jeeberPosition` is a Dart field name, not a diag key — nothing emitted it.
// The only `Diag.event` call anywhere under lib/features/live_tracking/ lived in
// `sse_live_position_stream.dart` (2 hits, one file), and W1.1 DELETES that
// file. So without the two events asserted here, W1.1 would have left the
// feature emitting zero breadcrumbs and asked a verifier to count three things
// out of silence.
//
// These are the host-side POSITIVE controls for the device round: they prove the
// records are emitted, that they carry the fields a capture is parsed for, and
// that the screen-entry denominator is one-per-entry rather than one-per-read.
// They cannot and do not prove anything about a phone — that is `device` /
// `capture` class evidence and belongs to V-2 (GATE.md §3).
//
// Explicit NON-CLAIM (GATE.md §7): no Firestore path is exercised here.
// `Firebase.apps` is empty under `flutter test`, and this feature has no
// Firestore path in any case.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

const _id = 'DLV-MB1-DIAG';

class _Repo implements LiveTrackingRepository, LivePositionSource {
  _Repo(this._fixes);

  /// One entry consumed per read; the last repeats. `null` = no fix yet.
  final List<GpsPoint?> _fixes;
  int reads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      DeliveryTrackingInfo(
        deliveryId: deliveryId,
        currentStage: TrackingStage.inTransit,
        stageTimestamps: const {},
      );

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    final index = reads;
    reads++;
    final fix = _fixes[index < _fixes.length ? index : _fixes.length - 1];
    if (fix == null) return null;
    return DeliveryLivePosition(jeeberPosition: fix, polyline: [fix]);
  }
}

class _StageOnlyRepo implements LiveTrackingRepository {
  const _StageOnlyRepo();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      DeliveryTrackingInfo(
        deliveryId: deliveryId,
        currentStage: TrackingStage.inTransit,
        stageTimestamps: const {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> lines;

  Map<String, dynamic> decode(String line) =>
      jsonDecode(line.substring(Diag.prefix.length + 1))
          as Map<String, dynamic>;

  List<Map<String, dynamic>> named(String name) => lines
      .map(decode)
      .where((r) => r['t'] == 'evt' && r['name'] == name)
      .map((r) => (r['data'] as Map).cast<String, dynamic>())
      .toList();

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
  });

  tearDown(Diag.resetForTest);

  test('one screen entry emits exactly ONE tracking_screen_open', () async {
    final cubit = LiveTrackingCubit(
      repository: _Repo(const [GpsPoint(lat: 33.1, lng: 35.1)]),
      deliveryId: _id,
      refreshSignals: const Stream<void>.empty(),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    final opens = named(kTrackingScreenOpenEvent);
    expect(opens, hasLength(1),
        reason: 'the screen-entry DENOMINATOR. If this were emitted per read, '
            '"3 positions in one dwell" would be unfalsifiable.');
    expect(opens.single['deliveryId'], _id);
    expect(opens.single['positionSource'], isTrue);
  });

  test('a repo with no position capability says so in the open record',
      () async {
    final cubit = LiveTrackingCubit(
      repository: const _StageOnlyRepo(),
      deliveryId: _id,
      refreshSignals: const Stream<void>.empty(),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    expect(named(kTrackingScreenOpenEvent).single['positionSource'], isFalse,
        reason: 'a capture taken against the :4010 mock or a demo/seam repo '
            'must be readable as "no source", never as "broken marker"');
    expect(named(kTrackingPositionEvent), isEmpty,
        reason: 'no read was attempted, so no read may be reported');
  });

  test('three distinct fixes inside ONE entry are three distinct records',
      () async {
    final repo = _Repo(const [
      GpsPoint(lat: 33.1, lng: 35.1),
      GpsPoint(lat: 33.2, lng: 35.2),
      GpsPoint(lat: 33.3, lng: 35.3),
    ]);
    final bus = StreamController<void>.broadcast();
    addTearDown(bus.close);
    final cubit = LiveTrackingCubit(
      repository: repo,
      deliveryId: _id,
      refreshSignals: bus.stream,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    bus.add(null);
    await pumpEventQueue();
    bus.add(null);
    await pumpEventQueue();

    // The exact shape MB1's V-2 parses out of the on-device capture.
    expect(named(kTrackingScreenOpenEvent), hasLength(1));
    final positions = named(kTrackingPositionEvent);
    expect(positions, hasLength(3));
    expect(positions.map((r) => r['cause']).toList(),
        <String>['open', 'push', 'push']);
    expect(positions.map((r) => r['lat']).toSet(), <double>{33.1, 33.2, 33.3},
        reason: 'THREE DISTINCT jeeberPosition values, one screen entry — the '
            'exact predicate, expressed in the records a capture carries');
    expect(positions.every((r) => r['applied'] == true), isTrue);
    expect(
      positions.where((r) => r['cause'] == 'push'),
      hasLength(2),
      reason: 'push-attribution: an update caused by the refresh signal is '
          'distinguishable from the screen-open read',
    );
  });

  test('a read with no fix is STILL reported (a frozen marker is never silent)',
      () async {
    final cubit = LiveTrackingCubit(
      repository: _Repo(const <GpsPoint?>[null]),
      deliveryId: _id,
      refreshSignals: const Stream<void>.empty(),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    final positions = named(kTrackingPositionEvent);
    expect(positions, hasLength(1));
    expect(positions.single['applied'], isFalse);
    expect(positions.single['lat'], isNull);
    expect(positions.single['polyline'], 0);
  });

  test('resume and retry are attributed distinctly', () async {
    final cubit = LiveTrackingCubit(
      repository: _Repo(const [
        GpsPoint(lat: 33.1, lng: 35.1),
        GpsPoint(lat: 33.2, lng: 35.2),
        GpsPoint(lat: 33.3, lng: 35.3),
      ]),
      deliveryId: _id,
      refreshSignals: const Stream<void>.empty(),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    await cubit.refreshNow();
    await pumpEventQueue();
    cubit.retry();
    await pumpEventQueue();

    expect(named(kTrackingPositionEvent).map((r) => r['cause']).toList(),
        <String>['open', 'resume', 'retry']);
    // Still ONE screen entry: retry re-reads, it does not re-enter.
    expect(named(kTrackingScreenOpenEvent), hasLength(1));
  });
}

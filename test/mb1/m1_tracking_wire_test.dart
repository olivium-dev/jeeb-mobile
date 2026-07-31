// MB1 ITEM M1 — W1.1, THE WIRE.
//
// Member item: "courier marker wire + SSE teardown". This file owns the WIRE
// half; `m2_sse_teardown_receipts_test.dart` owns the teardown half, so the two
// red independently.
//
// The claim under test: `fetchLivePosition()` — which had ZERO non-test callers
// at origin/main, i.e. the fix was already written and orphaned — is now called
// on screen-open, on a `type=delivery` push, on resume and on retry, AND ON
// NOTHING ELSE. No clock. Every fake here is authored by the test author; none
// is shared with the writer's own tests, so a fake that quietly satisfies the
// assertion cannot be the same fake in both packs.
//
// -------------------------------------------------------------------------
// NON-CLAIM (GATE.md §3, §7). Everything in this file is `suite` evidence.
// It proves the cubit ASKS its repository for a position on four events, and
// it proves the Dio repository shapes that ask as
// `GET /deliveries/{id}/tracking`. It proves NOTHING about a phone: not that a
// marker moved on a map, not that the gateway answered, not that a push
// arrived. Those are `device`/`capture` class and belong to V-2's R1 round.
// See `m7_nonclaims_test.dart`, which states that boundary as an assertion
// rather than as prose.
// -------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_state.dart';
import 'package:jeeb_mobile/features/live_tracking/data/dio_live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

const String _id = 'DLV-MB1-M1';

/// A repository that COUNTS. Position reads are served from a script so each
/// read is distinguishable; status reads are served from a mutable stage so a
/// push can change the row under the marker.
class _CountingRepo implements LiveTrackingRepository, LivePositionSource {
  _CountingRepo({List<GpsPoint?> fixes = const [GpsPoint(lat: 1, lng: 1)]})
      : _fixes = fixes;

  final List<GpsPoint?> _fixes;

  int statusReads = 0;
  int positionReads = 0;
  TrackingStage stage = TrackingStage.inTransit;

  /// Position values handed out, in order — the host-side twin of "distinct
  /// jeeberPosition values" in a device capture.
  final List<GpsPoint?> served = <GpsPoint?>[];

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    statusReads++;
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: stage,
      stageTimestamps: const {},
    );
  }

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    final i = positionReads;
    positionReads++;
    final fix = _fixes[i < _fixes.length ? i : _fixes.length - 1];
    served.add(fix);
    if (fix == null) return null;
    return DeliveryLivePosition(jeeberPosition: fix, polyline: <GpsPoint>[fix]);
  }
}

/// A repository with NO position capability — the `:4010` mock and the
/// demo/seam doubles. Must contribute no reads and must not fault the screen.
class _StageOnlyRepo implements LiveTrackingRepository {
  int statusReads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    statusReads++;
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const {},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M1.a — the four causes, and only those four', () {
    test('screen-open issues exactly ONE position read and the marker lands',
        () async {
      final repo = _CountingRepo(fixes: const [GpsPoint(lat: 33.1, lng: 35.1)]);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(repo.positionReads, 1,
          reason: 'the orphaned fetchLivePosition() must now have a caller — '
              'zero here is the pre-fix frozen marker');
      expect(cubit.debugPositionReadCount, 1);
      expect(cubit.debugLastPositionCause, LivePositionReadCause.screenOpen);
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 33.1, lng: 35.1),
          reason: 'a read that never reaches the state is not a wire');
    });

    test('a status push issues exactly ONE more read, attributed to push',
        () async {
      final repo = _CountingRepo(fixes: const [
        GpsPoint(lat: 33.1, lng: 35.1),
        GpsPoint(lat: 33.2, lng: 35.2),
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
      expect(repo.positionReads, 1);

      bus.add(null);
      await pumpEventQueue();

      expect(repo.positionReads, 2, reason: 'one push -> exactly one read');
      expect(cubit.debugLastPositionCause, LivePositionReadCause.push);
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 33.2, lng: 35.2),
          reason: 'the marker MOVED — a second read that does not change the '
              'rendered position is the frozen marker with extra steps');
    });

    test('resume issues exactly ONE more read, attributed to resume', () async {
      final repo = _CountingRepo(fixes: const [
        GpsPoint(lat: 33.1, lng: 35.1),
        GpsPoint(lat: 33.4, lng: 35.4),
      ]);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      await cubit.refreshNow();
      await pumpEventQueue();

      expect(repo.positionReads, 2);
      expect(cubit.debugLastPositionCause, LivePositionReadCause.resume);
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 33.4, lng: 35.4));
    });

    test('retry issues exactly ONE more read, attributed to retry', () async {
      final repo = _CountingRepo(fixes: const [
        GpsPoint(lat: 33.1, lng: 35.1),
        GpsPoint(lat: 33.5, lng: 35.5),
      ]);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      cubit.retry();
      await pumpEventQueue();

      expect(repo.positionReads, 2);
      expect(cubit.debugLastPositionCause, LivePositionReadCause.retry);
    });

    test('a repository with no position capability performs no read and does '
        'not fault the screen', () async {
      final repo = _StageOnlyRepo();
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.debugPositionReadCount, 0);
      expect(repo.statusReads, greaterThan(0),
          reason: 'DENOMINATOR: the cubit really did run. Zero position reads '
              'is only a measurement next to a non-zero status read.');
      expect(cubit.state.mode, LiveTrackingViewMode.ready);
    });
  });

  group('M1.b — NO CADENCE (the half of the P0 that was a loop)', () {
    test('10 virtual minutes with no event produce ZERO extra reads, zero '
        'periodic timers, and no pending timers', () {
      // fakeAsync, not a real delay: the deleted re-arm ran on a widening
      // schedule that settled at 30 s, so 10 virtual minutes is ~20 dead GETs
      // on the pre-fix tree. Wall-clock waiting could never afford that.
      fakeAsync((async) {
        final repo = _CountingRepo(fixes: const [
          GpsPoint(lat: 33.1, lng: 35.1),
          GpsPoint(lat: 33.9, lng: 35.9),
        ]);
        final bus = StreamController<void>.broadcast();
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: _id,
          refreshSignals: bus.stream,
        );
        async.flushMicrotasks();

        expect(repo.positionReads, 1, reason: 'screen-open read');

        async.elapse(const Duration(minutes: 10));
        async.flushMicrotasks();

        expect(repo.positionReads, 1,
            reason: 'NOTHING may issue a read on a clock. The deleted re-arm '
                'would have issued roughly 20 by now.');
        expect(repo.statusReads, 1,
            reason: 'the status axis is event-driven too — no poll survived');
        expect(async.periodicTimerCount, 0,
            reason: 'a periodic timer IS a cadence, whatever it is named');
        expect(async.pendingTimers, isEmpty,
            reason: 'a pending one-shot timer is a re-arm waiting to fire');

        // IN-ZONE POSITIVE CONTROL. Without this, "zero extra reads" is
        // indistinguishable from "the cubit was never wired to anything" —
        // exactly the unsent-message-reads-as-zero-requests failure this
        // programme has already shipped once.
        bus.add(null);
        async.flushMicrotasks();
        expect(repo.positionReads, 2,
            reason: 'POS CONTROL: an EVENT still produces a read, so the zero '
                'above is "no cadence", not "nothing wired"');

        // And the event did not itself install a cadence.
        async.elapse(const Duration(minutes: 10));
        async.flushMicrotasks();
        expect(repo.positionReads, 2);
        expect(async.periodicTimerCount, 0);

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
    });

    test('two pushes inside one round trip produce ONE read, not two',
        () async {
      // Single-flight. Two coalesced pushes (or a duplicated resume
      // notification) must not double the traffic the batch exists to remove.
      final completer = Completer<void>();
      final repo = _SlowPositionRepo(gate: completer.future);
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);

      bus.add(null);
      bus.add(null);
      await pumpEventQueue();
      completer.complete();
      await pumpEventQueue();

      expect(repo.positionReads, lessThanOrEqualTo(2),
          reason: 'screen-open + at most one push read; a per-push read with '
              'no latch would be 3+');
      expect(repo.concurrentPeak, 1,
          reason: 'never two tracking reads in flight at once');
    });
  });

  group('M1.c — a status read must never BLANK a marker already on screen', () {
    test('the last known fix survives a status read that carries no position',
        () async {
      // `DeliveryTrackingInfo.fromDeliveryJson` never populates jeeberPosition,
      // so a bare `trackingInfo: info` emit erases the marker on EVERY status
      // read. Under the stream design a later frame silently re-drew it; on the
      // snapshot path the two reads are adjacent, so a null second read would
      // erase the marker mid-trip.
      final repo = _CountingRepo(fixes: const [
        GpsPoint(lat: 33.1, lng: 35.1),
        null, // gateway has no fix at that instant
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
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 33.1, lng: 35.1));

      repo.stage = TrackingStage.atDoor;
      bus.add(null);
      await pumpEventQueue();

      expect(cubit.state.trackingInfo?.currentStage, TrackingStage.atDoor,
          reason: 'DENOMINATOR: the status read really happened');
      expect(cubit.state.trackingInfo?.jeeberPosition,
          const GpsPoint(lat: 33.1, lng: 35.1),
          reason: 'the marker is only ever replaced by a NEWER fix, never by '
              'nothing');
    });
  });

  group('M1.d — WIRE LEVEL: the path that leaves the device', () {
    test('fetchLivePosition issues GET /deliveries/{id}/tracking, and the '
        'recorded path set contains no streaming path', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
        ..httpClientAdapter = adapter;
      final repo = DioLiveTrackingRepository(dio, originGateway: true);

      final pos = await repo.fetchLivePosition(deliveryId: _id);

      expect(adapter.paths, isNotEmpty,
          reason: 'DENOMINATOR: zero recorded requests would satisfy "no '
              'stream path" trivially');
      expect(adapter.paths.single, '/deliveries/$_id/tracking',
          reason: 'LocationController.cs:227 — the route the gateway kept');
      // The alias is assembled so this file never carries it contiguously; see
      // mb1_pack_support.dart for why.
      const streamFragment = 'geo/jeeb/' 'stream';
      expect(adapter.paths.where((p) => p.contains(streamFragment)), isEmpty);
      expect(adapter.headers['Accept'], isNot(contains('text/event-stream')),
          reason: 'the SSE arm was opened by the Accept header; a snapshot '
              'read must not ask for one');
      expect(pos?.jeeberPosition, const GpsPoint(lat: 33.7, lng: 35.7));
    });

    test('every failure shape returns null rather than faulting', () async {
      for (final status in const [403, 404, 500]) {
        final adapter = _RecordingAdapter(status: status);
        final dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
          ..httpClientAdapter = adapter;
        final repo = DioLiveTrackingRepository(dio, originGateway: true);
        expect(await repo.fetchLivePosition(deliveryId: _id), isNull,
            reason: 'a $status must leave the last-known marker alone, not '
                'blow up the tracking screen');
        expect(adapter.paths, hasLength(1),
            reason: 'DENOMINATOR: the request was actually attempted');
      }
    });
  });
}

/// Serves a position only once its [gate] completes, and records the peak
/// number of simultaneous in-flight reads.
class _SlowPositionRepo implements LiveTrackingRepository, LivePositionSource {
  _SlowPositionRepo({required this.gate});

  final Future<void> gate;
  int positionReads = 0;
  int inFlight = 0;
  int concurrentPeak = 0;

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
    positionReads++;
    inFlight++;
    if (inFlight > concurrentPeak) concurrentPeak = inFlight;
    await gate;
    inFlight--;
    return const DeliveryLivePosition(
      jeeberPosition: GpsPoint(lat: 1, lng: 1),
      polyline: <GpsPoint>[],
    );
  }
}

/// Records every path and the request headers; opens no socket.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.status = 200});

  final int status;
  final List<String> paths = <String>[];
  final Map<String, String> headers = <String, String>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    options.headers.forEach((k, v) => headers[k] = '$v');
    return ResponseBody.fromString(
      jsonEncode(const {
        'position': {'lat': 33.7, 'lng': 35.7},
        'polyline': [
          [33.7, 35.7],
        ],
        'status': 'InTransit',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

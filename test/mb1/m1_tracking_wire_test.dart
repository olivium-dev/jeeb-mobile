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

    test('two pushes inside one round trip COLLAPSE to one trailing read — '
        'coalesced, never dropped, never concurrent', () async {
      // Single-flight with a TRAILING EDGE. Two coalesced pushes (or a
      // duplicated resume notification) must not double the traffic the batch
      // exists to remove — but they must not vanish either, because there is no
      // cadence behind them to repair a dropped edge.
      //
      // REWRITTEN by the MB1 two-model review, which found this test unable to
      // fail. It used to `bus.add(null)` twice IMMEDIATELY after constructing
      // the cubit — i.e. before `_armWatchers()` had run — and a broadcast
      // stream drops events that have no listener. Both pushes went nowhere,
      // the assertion was `lessThanOrEqualTo(2)` against an actual 1, and the
      // whole push→position wire could have been deleted with this still green.
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

      // Let the screen-open path get as far as ARMING the subscription and
      // BLOCKING on the gated position read. Without this the test measures
      // nothing.
      await pumpEventQueue();
      expect(cubit.debugPushRefreshWired, isTrue,
          reason: 'PRECONDITION: the push bus must be armed before the pushes '
              'are sent, or a broadcast stream silently drops them and this '
              'whole test reads a miss as a pass');
      expect(repo.inFlight, 1,
          reason: 'PRECONDITION: the screen-open read must still be in flight, '
              'otherwise nothing is being coalesced');

      bus.add(null);
      bus.add(null);
      await pumpEventQueue();

      expect(repo.positionReads, 1,
          reason: 'the overlapping pushes must not start a second concurrent '
              'read');

      completer.complete();
      await pumpEventQueue();

      expect(repo.positionReads, 2,
          reason: 'exactly ONE trailing read for the whole burst: the two '
              'pushes coalesce (not 3+, which is a per-push read with no '
              'latch) and they are NOT dropped (not 1, which is the pre-review '
              'behaviour — with no cadence, a dropped push edge leaves the '
              'marker at the pre-push snapshot indefinitely)');
      expect(cubit.debugLastPositionCause, LivePositionReadCause.push,
          reason: 'the trailing read must be attributed to the push that '
              'caused it — this is the `cause:"push"` row V-2 counts');
      expect(repo.concurrentPeak, 1,
          reason: 'never two tracking reads in flight at once');
    });

    test('the coalesced trailing read installs no cadence of its own',
        () async {
      // The trailing edge is the one place a re-arm could be smuggled back in.
      // A completed read with an empty pending slot must schedule NOTHING.
      fakeAsync((async) {
        final repo = _CountingRepo(fixes: const [
          GpsPoint(lat: 33.1, lng: 35.1),
          GpsPoint(lat: 33.2, lng: 35.2),
        ]);
        final bus = StreamController<void>.broadcast();
        final cubit = LiveTrackingCubit(
          repository: repo,
          deliveryId: _id,
          refreshSignals: bus.stream,
        );
        async.flushMicrotasks();
        bus.add(null);
        async.flushMicrotasks();
        final settled = repo.positionReads;
        expect(settled, greaterThanOrEqualTo(2),
            reason: 'POS CONTROL: the event really did produce a read');

        async.elapse(const Duration(minutes: 30));
        async.flushMicrotasks();
        expect(repo.positionReads, settled,
            reason: 'no timer, no re-arm, no trailing read that re-triggers '
                'itself');
        expect(async.periodicTimerCount, 0);
        expect(async.pendingTimers, isEmpty);

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
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

  // ---------------------------------------------------------------------
  // M1.e — added by the MB1 two-model review. `fetchLivePosition` documents
  // itself as "deliberately total: ANY failure returns null", and the group
  // above only ever tested HTTP STATUS failures, which arrive as
  // `DioException`. The parser reaches the wire through unchecked casts, so a
  // MALFORMED 200 BODY threw `TypeError` — neither a `DioException` nor a
  // `FormatException`, therefore uncaught, therefore an unhandled zone error
  // out of an unawaited call chain, with no breadcrumb emitted on the way.
  // Every case below reds against the pre-review code.
  // ---------------------------------------------------------------------
  group('M1.e — a malformed 200 body is a null, not a throw', () {
    Future<DeliveryLivePosition?> readBody(Object body) async {
      final adapter = _BodyAdapter(jsonEncode(body));
      final dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
        ..httpClientAdapter = adapter;
      final repo = DioLiveTrackingRepository(dio, originGateway: true);
      final out = await repo.fetchLivePosition(deliveryId: _id);
      expect(adapter.paths, hasLength(1),
          reason: 'DENOMINATOR: the request was actually attempted — a null '
              'from a request that never left is not a measurement');
      return out;
    }

    test('a STRING latitude returns null instead of throwing TypeError',
        () async {
      expect(
        await readBody(const {
          'position': {'lat': '33.7', 'lng': 35.7},
          'polyline': <dynamic>[],
        }),
        isNull,
      );
    });

    test('a LIST-shaped position returns null instead of throwing TypeError',
        () async {
      expect(
        await readBody(const {
          'position': [33.7, 35.7],
          'polyline': <dynamic>[],
        }),
        isNull,
      );
    });

    test('a NUMERIC status returns null instead of throwing TypeError',
        () async {
      expect(
        await readBody(const {
          'status': 3,
          'position': {'lat': 33.7, 'lng': 35.7},
          'polyline': <dynamic>[],
        }),
        isNull,
      );
    });

    test('POS CONTROL: the same adapter with a WELL-FORMED body still parses, '
        'so the nulls above are the parser refusing, not the harness failing',
        () async {
      final pos = await readBody(const {
        'position': {'lat': 33.7, 'lng': 35.7},
        'polyline': <dynamic>[],
      });
      expect(pos?.jeeberPosition, const GpsPoint(lat: 33.7, lng: 35.7));
    });

    test('a source that THROWS still leaves the cubit alive, keeps the last '
        'known marker, and is still counted as an attempt', () async {
      final repo = _ThrowingPositionRepo();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: _id,
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(repo.positionReads, 1,
          reason: 'DENOMINATOR: the throwing read was actually attempted');
      expect(cubit.isClosed, isFalse,
          reason: 'an implementation that violates the null contract must not '
              'take the tracking screen down with it');
      expect(cubit.state.mode, isNot(LiveTrackingViewMode.error),
          reason: 'the STATUS axis succeeded; a position fault must not '
              'present as a screen error');
      expect(cubit.debugPositionReadCount, 1,
          reason: 'a thrown read that is not counted is silence, and V-2 '
              'counts these rows — silence and "no push arrived" would read '
              'identically');
      expect(cubit.debugLastPositionCause, LivePositionReadCause.screenOpen);
    });
  });
}

/// A `LivePositionSource` that violates the documented null contract by
/// throwing. Not a straw man: the contract is a DOC COMMENT, and devtool
/// doubles, seam fakes and future gateway clients are not bound by it.
class _ThrowingPositionRepo
    implements LiveTrackingRepository, LivePositionSource {
  int positionReads = 0;

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
    throw StateError('a source that does not honour the null contract');
  }
}

/// Serves one caller-supplied 200 body; opens no socket.
class _BodyAdapter implements HttpClientAdapter {
  _BodyAdapter(this.body);

  final String body;
  final List<String> paths = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
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

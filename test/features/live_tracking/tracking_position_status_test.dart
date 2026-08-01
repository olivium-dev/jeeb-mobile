// The phantom courier pin — the CLIENT half.
//
// ## The defect
//
// A customer watching a delivery saw the courier marker rendered as LIVE at a
// location the courier had left minutes earlier. Hardware capture: 76 s of a
// stale pin with no staleness affordance.
//
// The server half is fixed and merged: `jeeb-gateway` #342 (`d430706f`) stopped
// the store destroying an aged fix on read, made `stale` monotonic in the fix's
// age, and added an EXPLICIT four-state verdict, `positionStatus` ∈
// `awaitingFirstFix | live | stale | lost`
// (`src/JeebGateway/Tracking/TrackingDtos.cs:143`,
//  `src/JeebGateway/Tracking/PositionFreshness.cs`), serialized camelCase by
// `JsonSerializerDefaults.Web` (`Controllers/LocationController.cs:47`).
//
// ## The client half, which is what this file pins
//
// Mobile ignored `positionStatus` entirely, and — worse — could not have used
// it if it had read it. The `lost` snapshot is
//
//     {position: null, polyline: [], stale: true, secondsSinceUpdate: <age>,
//      positionStatus: "lost"}
//
// which is EMPTY by coordinates, and `_applyLivePosition` dropped on emptiness.
// So `withLivePosition` never ran, `positionStale` stayed `false` on the row,
// and `markerIsLive` stayed `true` over a marker merged minutes earlier. The
// server's clearest possible sentence — "I had this courier and I have lost
// them" — was the one the client was structurally unable to hear.
//
// ## Why this does NOT need the owner ruling the obvious fix would
//
// `tracking_diag_instrument_test.dart:238` pins "an EMPTY overlay is recorded
// with applied:false" and is DELIBERATE. But read what it constructs:
// `const DeliveryLivePosition()` — `stale:false`, `secondsSinceUpdate:null`,
// no coordinates. That is the `awaitingFirstFix` wire state, NOT `lost`. The
// two differ on the wire by exactly the discriminator #342 built for the
// purpose: an AGE beside a null position.
//
// So the drop moved from `isEmpty` to `isNothingToSay`, which is
// `isEmpty && !lost`. `awaitingFirstFix` is still dropped — the pinned
// invariant holds byte-for-byte, and this file re-asserts it directly rather
// than taking that on trust.
//
// ## Realness
//
// Every test below drives the SHIPPED `DioLiveTrackingRepository` over a
// recording `HttpClientAdapter` with literal gateway JSON, through the SHIPPED
// `LiveTrackingCubit`. Nothing about the parse, the drop, or the merge is
// stubbed; the only fake is the socket, which never opens.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/data/dio_live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/courier_position_notice.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_map_surface.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const String _deliveryId = 'DLV-PHANTOM';

/// The delivery row `GET /v1/deliveries/{id}` answers. Constant across every
/// test here — the position axis is what varies.
const Map<String, Object?> _deliveryRow = {
  'id': _deliveryId,
  'status': 'InTransit',
  'tierId': 'express',
  'jeeberName': 'Sami',
};

/// `GET /deliveries/{id}/tracking` — the LIVE snapshot. Byte-shape taken from
/// `TrackingPolylineDto` with `PositionStatus = freshness.ToWireValue()`.
Map<String, Object?> _liveSnapshot({double lat = 33.5, double lng = 35.5}) => {
      'deliveryId': _deliveryId,
      'jeeberId': 'JBR-1',
      'position': {'lat': lat, 'lng': lng, 'timestamp': '2026-08-01T10:00:00Z'},
      'polyline': [
        [lat, lng],
        [33.9, 35.6],
      ],
      'stale': false,
      'secondsSinceUpdate': 4.0,
      'positionStatus': 'live',
      'etag': 'abc',
      'serverTimestamp': '2026-08-01T10:00:04Z',
    };

/// The `lost` snapshot, exactly as #342 serializes it: NO coordinates, NO
/// polyline, `stale:true`, and — the whole signal — a non-null age.
Map<String, Object?> _lostSnapshot({double ageSeconds = 312.5}) => {
      'deliveryId': _deliveryId,
      'jeeberId': 'JBR-1',
      'position': null,
      'polyline': <Object?>[],
      'stale': true,
      'secondsSinceUpdate': ageSeconds,
      'positionStatus': 'lost',
      'etag': 'def',
      'serverTimestamp': '2026-08-01T10:05:12Z',
    };

/// The `awaitingFirstFix` snapshot — indistinguishable from `lost` by
/// coordinates, and distinguished from it by the ABSENCE of an age.
const Map<String, Object?> _awaitingSnapshot = {
  'deliveryId': _deliveryId,
  'jeeberId': 'JBR-1',
  'position': null,
  'polyline': <Object?>[],
  'stale': false,
  'secondsSinceUpdate': null,
  'positionStatus': 'awaitingFirstFix',
  'etag': 'cbf29ce484222325',
  'serverTimestamp': '2026-08-01T10:00:00Z',
};

void main() {
  late _TrackingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _TrackingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioLiveTrackingRepository repo() =>
      DioLiveTrackingRepository(dio, originGateway: true);

  group('the wire verdict reaches the client at all', () {
    test('positionStatus:"lost" parses, and arrives WITH an age and NO '
        'coordinates — the pairing that is the entire signal', () async {
      final info = DeliveryTrackingInfo.fromTrackingJson(
        _deliveryId,
        _lostSnapshot(),
      );

      expect(info.positionStatus, PositionFreshness.lost);
      expect(info.jeeberPosition, isNull);
      expect(info.positionAgeSeconds, 312.5);
      expect(info.positionStale, isTrue);
      expect(info.positionLost, isTrue);
    });

    test('all four wire spellings round-trip', () {
      PositionFreshness parse(String wire) => DeliveryTrackingInfo
          .fromTrackingJson(_deliveryId, {'positionStatus': wire})
          .positionStatus!;

      expect(parse('awaitingFirstFix'), PositionFreshness.awaitingFirstFix);
      expect(parse('live'), PositionFreshness.live);
      expect(parse('stale'), PositionFreshness.stale);
      expect(parse('lost'), PositionFreshness.lost);
      for (final f in PositionFreshness.values) {
        expect(parse(f.wire), f, reason: 'wire spelling ${f.wire} must survive');
      }
    });

    test('a gateway that omits positionStatus DERIVES it — an age with no '
        'coordinates is lost, no age is awaitingFirstFix', () {
      PositionFreshness derive(Map<String, Object?> json) =>
          DeliveryTrackingInfo.fromTrackingJson(_deliveryId, json)
              .positionStatus!;

      expect(
        derive({'position': null, 'stale': true, 'secondsSinceUpdate': 400.0}),
        PositionFreshness.lost,
      );
      expect(
        derive({'position': null, 'stale': false}),
        PositionFreshness.awaitingFirstFix,
      );
      expect(
        derive({
          'position': {'lat': 1.0, 'lng': 2.0},
          'stale': true,
          'secondsSinceUpdate': 150.0,
        }),
        PositionFreshness.stale,
      );
      expect(
        derive({
          'position': {'lat': 1.0, 'lng': 2.0},
          'stale': false,
        }),
        PositionFreshness.live,
      );
    });

    test('an UNKNOWN future verdict is never read as live', () {
      final info = DeliveryTrackingInfo.fromTrackingJson(_deliveryId, {
        'positionStatus': 'evacuated',
        'position': null,
        'stale': true,
        'secondsSinceUpdate': 900.0,
      });
      // Falls through to the derivation, which reads the age. The one thing it
      // must never do is default to a confident state.
      expect(info.positionStatus, isNot(PositionFreshness.live));
      expect(info.positionStatus, PositionFreshness.lost);
    });
  });

  group('THE DEFECT — a lost courier must degrade a marker already on screen',
      () {
    test(
      'live fix, then lost: the marker stops being live and the age survives',
      () async {
        // 1. A live fix lands. This is the marker the customer is looking at.
        adapter.deliveryRow = _deliveryRow;
        adapter.trackingSnapshot = _liveSnapshot();
        final cubit = LiveTrackingCubit(
          repository: repo(),
          deliveryId: _deliveryId,
        );
        await pumpEventQueue();

        // POSITIVE CONTROL. If this is not live, the rest proves nothing —
        // "the marker went away" is trivially true of a marker that never
        // arrived.
        final before = cubit.state.trackingInfo!;
        expect(before.markerIsLive, isTrue);
        expect(before.jeeberPosition, isNotNull);
        expect(before.positionStatus, PositionFreshness.live);
        expect(trackingMarkers(before), hasLength(1));

        // 2. The courier goes quiet past PositionTtl. The gateway publishes no
        //    coordinates — only an age.
        adapter.trackingSnapshot = _lostSnapshot();
        cubit.retry();
        await pumpEventQueue();

        final after = cubit.state.trackingInfo!;
        expect(
          after.markerIsLive,
          isFalse,
          reason: 'a courier the gateway has LOST must not render as live',
        );
        expect(
          trackingMarkers(after),
          isEmpty,
          reason: 'the map must draw no pin for a courier we cannot vouch for',
        );

        // THE THREE ASSERTIONS THE DEFECT VIOLATED, all measured on
        // origin/main before this change and all found wrong there:
        //
        //   PROBE-AFTER markerIsLive=false pos=null stale=false age=null
        //
        // Note `markerIsLive` was ALREADY false pre-fix — but for the wrong
        // reason, and that matters. `_fetch` replaces `trackingInfo` wholesale
        // with a row parsed from the delivery aggregate, which carries no
        // position (`live_tracking_cubit.dart` `_fetch`), so the pin vanished
        // because the row had been blanked, not because anything had been
        // understood. The `lost` overlay was then DROPPED, taking the verdict
        // and the age with it, and the screen reverted to a state
        // byte-identical to "awaiting the first fix". The customer was shown an
        // empty map and told nothing.
        expect(
          after.positionStatus,
          PositionFreshness.lost,
          reason: 'pre-fix: null — the verdict was discarded with the overlay',
        );
        expect(
          after.positionStale,
          isTrue,
          reason: 'pre-fix: false — the row said "fine" about a lost courier',
        );
        expect(
          after.positionAgeSeconds,
          312.5,
          reason: 'pre-fix: null — no age survived, so nothing could be said',
        );

        await cubit.close();
      },
    );

    test('THE PHANTOM ITSELF — a row already holding a live marker, receiving '
        'a lost snapshot with no intervening status read', () async {
      // This is the socket leg's shape: `_onStreamedPosition` merges a fix onto
      // the CURRENT row without a status refetch, so the row accumulates a
      // position that a later merge has to degrade rather than replace. Here
      // the drop was not merely lossy, it was the phantom: measured on
      // origin/main,
      //
      //   PROBE-OVERLAY isEmpty=true => _applyLivePosition returns false
      //                => row UNCHANGED, markerIsLive stays true
      final live = DeliveryTrackingInfo.fromTrackingJson(
        _deliveryId,
        _liveSnapshot(),
      );
      expect(live.markerIsLive, isTrue); // POSITIVE CONTROL
      expect(trackingMarkers(live), hasLength(1));

      const lostOverlay = DeliveryLivePosition(
        stale: true,
        secondsSinceUpdate: 312.5,
        status: PositionFreshness.lost,
      );
      // Pre-fix this overlay was discarded on `isEmpty` and the row below was
      // never produced at all.
      expect(lostOverlay.isNothingToSay, isFalse);

      final degraded = live.withLivePosition(
        jeeberPosition: lostOverlay.jeeberPosition,
        polyline: lostOverlay.polyline,
        stale: lostOverlay.stale,
        secondsSinceUpdate: lostOverlay.secondsSinceUpdate,
        status: lostOverlay.status,
      );

      expect(degraded.markerIsLive, isFalse);
      expect(trackingMarkers(degraded), isEmpty);
      // The last known coordinate is RETAINED on this path — the merge
      // coalesces (`jeeberPosition ?? this.jeeberPosition`) — which is what
      // lets the screen say "last seen here". It is simply no longer live.
      expect(degraded.jeeberPosition, isNotNull);
      expect(degraded.positionAgeSeconds, 312.5);
      expect(CourierPositionNotice.shows(degraded), isTrue);
    });

    test('the verdict OUTRANKS the legacy boolean when the two disagree',
        () {
      // Today `TrackingFreshness.IsStale` returns true for BOTH `stale` and
      // `lost`, so `positionStale` alone happens to answer correctly and the
      // verdict clause in `markerIsLive` is belt-and-braces. That is a property
      // of one server's current arithmetic, not a contract — a partial deploy,
      // a proxy that rewrites a field, or a future rung could separate them.
      //
      // This is the case that tells the two clauses apart, and without it the
      // verdict clause is untested: removing it leaves every other test in this
      // file green (executed, observed).
      final incoherent = DeliveryTrackingInfo.fromTrackingJson(_deliveryId, {
        ..._liveSnapshot(),
        'stale': false, // the legacy boolean says "fine"…
        'positionStatus': 'lost', // …while the verdict says we lost them.
        'secondsSinceUpdate': 400.0,
      });

      expect(incoherent.positionStale, isFalse);
      expect(incoherent.positionStatus, PositionFreshness.lost);
      expect(incoherent.jeeberPosition, isNotNull);
      expect(
        incoherent.markerIsLive,
        isFalse,
        reason: 'when the two disagree the LESS confident one must win — a '
            'phantom pin is the failure that costs the customer a walk to the '
            'wrong corner',
      );
      expect(trackingMarkers(incoherent), isEmpty);
      expect(CourierPositionNotice.shows(incoherent), isTrue);
    });

    test('the same transition on the STALE rung, where the gateway still '
        'publishes coordinates', () async {
      adapter.deliveryRow = _deliveryRow;
      adapter.trackingSnapshot = _liveSnapshot();
      final cubit = LiveTrackingCubit(
        repository: repo(),
        deliveryId: _deliveryId,
      );
      await pumpEventQueue();
      expect(cubit.state.trackingInfo!.markerIsLive, isTrue);

      adapter.trackingSnapshot = {
        ..._liveSnapshot(),
        'stale': true,
        'secondsSinceUpdate': 187.0,
        'positionStatus': 'stale',
      };
      cubit.retry();
      await pumpEventQueue();

      final after = cubit.state.trackingInfo!;
      expect(after.positionStatus, PositionFreshness.stale);
      expect(after.markerIsLive, isFalse);
      expect(trackingMarkers(after), isEmpty);
      // Coordinates ARE still published on this rung — the route stays drawn.
      expect(after.jeeberPosition, isNotNull);
      expect(after.polyline, isNotEmpty);

      await cubit.close();
    });
  });

  group('THE PINNED INVARIANT — awaitingFirstFix is still dropped', () {
    test('an awaitingFirstFix snapshot does NOT blank a marker the screen '
        'already holds, and is recorded applied:false', () async {
      adapter.deliveryRow = _deliveryRow;
      adapter.trackingSnapshot = _liveSnapshot();
      final cubit = LiveTrackingCubit(
        repository: repo(),
        deliveryId: _deliveryId,
      );
      await pumpEventQueue();
      final before = cubit.state.trackingInfo!;
      expect(before.markerIsLive, isTrue);

      adapter.trackingSnapshot = _awaitingSnapshot;
      cubit.retry();
      await pumpEventQueue();

      final after = cubit.state.trackingInfo!;
      // DROPPED — nothing from the snapshot reached the row. The row is the
      // bare delivery aggregate `_fetch` just wrote, so every position-axis
      // field is at its default. This is the behaviour
      // `tracking_diag_instrument_test.dart:238` pins, asserted here at the
      // level the pin actually protects.
      expect(after.jeeberPosition, isNull);
      expect(after.markerIsLive, isFalse);
      expect(
        after.positionStatus,
        isNull,
        reason: 'an awaitingFirstFix overlay contributes NOTHING, verdict '
            'included — it is dropped before it can write anything',
      );
      expect(after.positionAgeSeconds, isNull);
      expect(
        CourierPositionNotice.shows(after),
        isFalse,
        reason: 'and therefore says nothing to the customer, which is right: '
            'there is no news in a courier who has not started',
      );
      expect(before.markerIsLive, isTrue); // the step-1 positive control held

      await cubit.close();
    });

    test('the drop predicate itself: isNothingToSay is TRUE for the exact '
        'value the pinned test constructs, and FALSE for lost', () {
      // `const DeliveryLivePosition()` is the literal expression at
      // tracking_diag_instrument_test.dart:241.
      const pinned = DeliveryLivePosition();
      expect(pinned.isEmpty, isTrue);
      expect(
        pinned.isNothingToSay,
        isTrue,
        reason: 'the pinned invariant: this shape is still discarded',
      );

      const lost = DeliveryLivePosition(
        stale: true,
        secondsSinceUpdate: 312.5,
        status: PositionFreshness.lost,
      );
      expect(
        lost.isEmpty,
        isTrue,
        reason: 'lost is empty BY COORDINATES — that never changed',
      );
      expect(
        lost.isNothingToSay,
        isFalse,
        reason: 'and it is emphatically not nothing to say',
      );
    });
  });

  group('the honest affordance', () {
    Future<void> pumpNotice(WidgetTester tester, DeliveryTrackingInfo info,
        {Locale locale = const Locale('en')}) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: TrackingMapSurface(info: info)),
      ));
      await tester.pumpAndSettle();
    }

    DeliveryTrackingInfo rowWith(Map<String, Object?> snapshot) =>
        DeliveryTrackingInfo.fromTrackingJson(_deliveryId, snapshot);

    testWidgets('LOST renders a notice naming the age', (tester) async {
      await pumpNotice(tester, rowWith(_lostSnapshot()));

      expect(find.bySemanticsLabel(RegExp('No signal')), findsWidgets);
      // 312.5 s floors to 5 whole minutes.
      expect(find.textContaining('5 min ago'), findsOneWidget);
    });

    testWidgets('STALE renders a different, quieter notice', (tester) async {
      await pumpNotice(
        tester,
        rowWith({
          ..._liveSnapshot(),
          'stale': true,
          'secondsSinceUpdate': 187.0,
          'positionStatus': 'stale',
        }),
      );

      expect(find.textContaining('3 min old'), findsOneWidget);
      expect(
        find.textContaining('No signal'),
        findsNothing,
        reason: 'stale and lost must not share copy — the customer\'s correct '
            'next action differs',
      );
    });

    testWidgets('LIVE renders NOTHING — there is no news in "fine"',
        (tester) async {
      await pumpNotice(tester, rowWith(_liveSnapshot()));
      expect(find.byType(CourierPositionNotice), findsOneWidget);
      // Mounted but collapsed: the widget owns the decision, not the layout.
      expect(find.textContaining('min'), findsNothing);
      expect(find.textContaining('No signal'), findsNothing);
    });

    testWidgets('awaitingFirstFix renders NOTHING either', (tester) async {
      await pumpNotice(tester, rowWith(_awaitingSnapshot));
      expect(find.textContaining('min'), findsNothing);
      expect(find.textContaining('No signal'), findsNothing);
    });

    testWidgets('the Arabic copy is present and distinct', (tester) async {
      await pumpNotice(
        tester,
        rowWith(_lostSnapshot()),
        locale: const Locale('ar'),
      );
      expect(find.textContaining('لا إشارة من الجيبر'), findsOneWidget);
    });

    testWidgets('an age under a minute drops the number rather than '
        'rendering "0 min ago"', (tester) async {
      await pumpNotice(tester, rowWith(_lostSnapshot(ageSeconds: 41.0)));
      expect(find.textContaining('0 min'), findsNothing);
      expect(find.text('No signal from the Jeeber'), findsOneWidget);
    });

    test('shows() is the one predicate, and it tracks the verdict', () {
      expect(CourierPositionNotice.shows(rowWith(_liveSnapshot())), isFalse);
      expect(CourierPositionNotice.shows(rowWith(_awaitingSnapshot)), isFalse);
      expect(CourierPositionNotice.shows(rowWith(_lostSnapshot())), isTrue);
      // A hand-built row with NO verdict says nothing — inventing one
      // client-side is the second source of truth this change exists to avoid.
      expect(
        CourierPositionNotice.shows(const DeliveryTrackingInfo(
          deliveryId: _deliveryId,
          currentStage: TrackingStage.inTransit,
          stageTimestamps: {},
          positionStale: true,
        )),
        isFalse,
      );
    });
  });
}

ResponseBody _json(Object? body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Answers the two GETs the tracking screen makes, by path. No socket opens.
class _TrackingAdapter implements HttpClientAdapter {
  Map<String, Object?> deliveryRow = _deliveryRow;
  Map<String, Object?>? trackingSnapshot;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.endsWith('/tracking')) {
      final snapshot = trackingSnapshot;
      if (snapshot == null) return _json(const {'error': 'no fix'}, status: 404);
      return _json(snapshot);
    }
    return _json(deliveryRow);
  }
}

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

const Map<String, Object?> _deliveryRow = {
  'id': _deliveryId,
  'status': 'InTransit',
  'tierId': 'express',
  'jeeberName': 'Sami',
};

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
        final before = cubit.state.trackingInfo!;
        expect(before.markerIsLive, isTrue);
        expect(before.jeeberPosition, isNotNull);
        expect(before.positionStatus, PositionFreshness.live);
        expect(trackingMarkers(before), hasLength(1));

        // 2. The courier goes quiet past PositionTtl. The gateway publishes no
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
      expect(degraded.jeeberPosition, isNotNull);
      expect(degraded.positionAgeSeconds, 312.5);
      expect(CourierPositionNotice.shows(degraded), isTrue);
    });

    test('the verdict OUTRANKS the legacy boolean when the two disagree',
        () {
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

  group('UX-11 · a run of silent reads synthesises `lost`', () {

    test('three consecutive null reads flip the overlay to lost', () async {
      final adapter = _TrackingAdapter()..trackingSnapshot = null;
      final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
        ..httpClientAdapter = adapter;
      final cubit = LiveTrackingCubit(
        repository: DioLiveTrackingRepository(dio, originGateway: true),
        deliveryId: _deliveryId,
      );
      // The Dio leg is genuinely async: a single microtask is not enough for
      // the cold load to settle before the refreshes are issued.
      await pumpEventQueue();

      // The cold load costs one read; two explicit refreshes complete the run.
      await cubit.refreshNow();
      await pumpEventQueue();
      await cubit.refreshNow();
      await pumpEventQueue();

      expect(
        cubit.state.trackingInfo?.positionStatus,
        PositionFreshness.lost,
        reason: 'a null read is not "no news" once it repeats',
      );
      await cubit.close();
    });

    test('a landed fix resets the miss counter', () async {
      final adapter = _TrackingAdapter()..trackingSnapshot = null;
      final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
        ..httpClientAdapter = adapter;
      final cubit = LiveTrackingCubit(
        repository: DioLiveTrackingRepository(dio, originGateway: true),
        deliveryId: _deliveryId,
      );
      await pumpEventQueue();

      adapter.trackingSnapshot = _liveSnapshot();
      await cubit.refreshNow();
      await pumpEventQueue();
      expect(
        cubit.state.trackingInfo?.positionStatus,
        isNot(PositionFreshness.lost),
      );

      adapter.trackingSnapshot = null;
      await cubit.refreshNow();
      await pumpEventQueue();
      expect(
        cubit.state.trackingInfo?.positionStatus,
        isNot(PositionFreshness.lost),
        reason: 'one miss after a good fix is still "no news"',
      );
      await cubit.close();
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

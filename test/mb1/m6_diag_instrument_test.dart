// MB1 ITEM M6 — the INSTRUMENT V-2 has to count with, and whether its
// predicate can be falsified.
//
// Recorded in OWNER-DECISIONS.md as one of MB1's two unsatisfiable verifier
// contracts: V-2's headline predicate asks a verifier to count "≥3 distinct
// jeeberPosition values within ONE continuous foreground dwell, screen-entry
// count == 1, ≥1 update attributable to the push-refresh signal", and before
// W1.1 NOTHING emitted any of the three. `jeeberPosition` is a Dart field name,
// not a diag key. Worse, W1.1 deletes `sse_live_position_stream.dart`, the only
// file under lib/features/live_tracking/ that called `Diag.event` at all — so
// the fix would have left the feature emitting zero breadcrumbs while a
// verifier was asked to count three things out of silence.
//
// The recorded remedy is `tracking_screen_open` + `tracking_position`. This
// item is the HOST-SIDE POSITIVE CONTROL for that instrument, and it adds the
// thing a bare "the events are emitted" test cannot give a verifier: a
// PREDICATE EVALUATOR, proven to return false on the shape that would otherwise
// launder a pass.
//
// The trap, stated plainly. W1.1 adds NO cadence by design, so three positions
// inside one dwell require three EVENTS in that dwell. A verifier who backs out
// of the screen and re-enters three times collects three positions from a
// marker that never moved — and the naive reading of "≥3 distinct positions"
// says PASS. The denominator (`tracking_screen_open` count == 1) is what makes
// that shape fail, and [evaluateDwellPredicate] below is the artefact that
// enforces it. Its falsifiability is asserted, not assumed.
//
// NON-CLAIM (GATE.md §3): `suite`. Emitting a record on a host VM is not a
// record in an on-device JSONL, and neither is a marker on a map. V-2 must
// re-derive all of this from a real capture; this file only proves the
// instrument exists, carries the fields, and cannot be satisfied by the
// re-entry shape.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_file_sink.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

const String _id = 'DLV-MB1-M6';

/// The verdict of MB1 V-2's headline predicate, evaluated over the records a
/// capture actually carries.
class DwellVerdict {
  const DwellVerdict({
    required this.screenEntries,
    required this.distinctPositions,
    required this.pushAttributed,
    required this.pass,
    required this.why,
  });

  final int screenEntries;
  final int distinctPositions;
  final int pushAttributed;
  final bool pass;
  final String why;

  @override
  String toString() => 'DwellVerdict(entries=$screenEntries, '
      'distinct=$distinctPositions, push=$pushAttributed, pass=$pass, $why)';
}

/// MB1 V-2's predicate, written down once so a verifier does not have to
/// re-invent it and get the denominator wrong.
///
/// [records] is the decoded `data` map of every `tracking_screen_open` /
/// `tracking_position` event in ONE capture window, in arrival order.
DwellVerdict evaluateDwellPredicate(
  List<({String name, Map<String, dynamic> data})> records,
) {
  final entries = records.where((r) => r.name == kTrackingScreenOpenEvent);
  final positions =
      records.where((r) => r.name == kTrackingPositionEvent).toList();
  final distinct = positions
      .where((r) => r.data['lat'] != null && r.data['lng'] != null)
      .map((r) => '${r.data['lat']},${r.data['lng']}')
      .toSet()
      .length;
  final push = positions.where((r) => r.data['cause'] == 'push').length;

  if (entries.length != 1) {
    return DwellVerdict(
      screenEntries: entries.length,
      distinctPositions: distinct,
      pushAttributed: push,
      pass: false,
      why: 'screen entries == ${entries.length}, not 1 — the positions were '
          'not collected inside ONE dwell. Re-entering the screen re-reads on '
          'open; that proves the screen reads on open, not that a marker moves.',
    );
  }
  if (distinct < 3) {
    return DwellVerdict(
      screenEntries: 1,
      distinctPositions: distinct,
      pushAttributed: push,
      pass: false,
      why: 'only $distinct distinct positions inside the dwell',
    );
  }
  if (push < 1) {
    return DwellVerdict(
      screenEntries: 1,
      distinctPositions: distinct,
      pushAttributed: push,
      pass: false,
      why: 'no update attributable to the push-refresh signal',
    );
  }
  return DwellVerdict(
    screenEntries: 1,
    distinctPositions: distinct,
    pushAttributed: push,
    pass: true,
    why: 'ok',
  );
}

class _ScriptedRepo implements LiveTrackingRepository, LivePositionSource {
  _ScriptedRepo(this._fixes);

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
    final i = reads;
    reads++;
    final fix = _fixes[i < _fixes.length ? i : _fixes.length - 1];
    if (fix == null) return null;
    return DeliveryLivePosition(jeeberPosition: fix, polyline: <GpsPoint>[fix]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> lines;

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
  });

  tearDown(Diag.resetForTest);

  /// Decodes the captured logcat lines the way a capture parser must: strip the
  /// `[jeeb-diag]` prefix, JSON-decode, keep the event records.
  List<({String name, Map<String, dynamic> data})> parsed() {
    final out = <({String name, Map<String, dynamic> data})>[];
    for (final line in lines) {
      final body = line.startsWith('${Diag.prefix} ')
          ? line.substring(Diag.prefix.length + 1)
          : line;
      final Map<String, dynamic> rec;
      try {
        rec = jsonDecode(body) as Map<String, dynamic>;
      } on FormatException {
        continue;
      }
      if (rec['t'] != 'evt') continue;
      out.add((
        name: rec['name'] as String,
        data: (rec['data'] as Map).cast<String, dynamic>(),
      ));
    }
    return out;
  }

  group('M6.a — the records exist and carry what a capture is parsed for', () {
    test('one screen entry emits exactly one open record; each read emits one '
        'position record with cause/lat/lng/applied/polyline', () async {
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: _ScriptedRepo(const [
          GpsPoint(lat: 33.1, lng: 35.1),
          GpsPoint(lat: 33.2, lng: 35.2),
        ]),
        deliveryId: _id,
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      bus.add(null);
      await pumpEventQueue();

      final records = parsed();
      expect(records, isNotEmpty,
          reason: 'DENOMINATOR: the parser saw records at all. Zero records '
              'and a green predicate is the silence W1.1 nearly shipped.');

      final opens =
          records.where((r) => r.name == kTrackingScreenOpenEvent).toList();
      expect(opens, hasLength(1));
      expect(opens.single.data['deliveryId'], _id);
      expect(opens.single.data['positionSource'], isTrue);

      final positions =
          records.where((r) => r.name == kTrackingPositionEvent).toList();
      expect(positions, hasLength(2));
      for (final field in const [
        'deliveryId',
        'cause',
        'applied',
        'lat',
        'lng',
        'polyline',
      ]) {
        expect(positions.first.data.containsKey(field), isTrue,
            reason: 'a capture parser reads `$field`; without it the '
                'predicate cannot be evaluated');
      }
      expect(positions.map((r) => r.data['cause']).toList(),
          <String>['open', 'push']);
    });

    test('a read that produced NO fix is still recorded', () async {
      final cubit = LiveTrackingCubit(
        repository: _ScriptedRepo(const <GpsPoint?>[null]),
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      final positions =
          parsed().where((r) => r.name == kTrackingPositionEvent).toList();
      expect(positions, hasLength(1),
          reason: 'a frozen marker with nothing in the journal is '
              'indistinguishable from a marker nobody looked at');
      expect(positions.single.data['applied'], isFalse);
      expect(positions.single.data['lat'], isNull);
    });
  });

  group('M6.b — the V-2 predicate, and PROOF that it can fail', () {
    test('POSITIVE: three pushes inside one dwell -> PASS', () async {
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: _ScriptedRepo(const [
          GpsPoint(lat: 33.1, lng: 35.1),
          GpsPoint(lat: 33.2, lng: 35.2),
          GpsPoint(lat: 33.3, lng: 35.3),
        ]),
        deliveryId: _id,
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      bus.add(null);
      await pumpEventQueue();
      bus.add(null);
      await pumpEventQueue();

      final verdict = evaluateDwellPredicate(parsed());
      expect(verdict.pass, isTrue, reason: verdict.toString());
      expect(verdict.screenEntries, 1);
      expect(verdict.distinctPositions, 3);
      expect(verdict.pushAttributed, 2);
    });

    test('NEGATIVE: three positions collected across THREE screen entries -> '
        'FAIL, and names the denominator', () async {
      // The exact laundering shape. Each entry reads on open, so a verifier who
      // backs out and re-enters three times sees three distinct positions from
      // a marker that never moved once.
      for (final fix in const [
        GpsPoint(lat: 33.1, lng: 35.1),
        GpsPoint(lat: 33.2, lng: 35.2),
        GpsPoint(lat: 33.3, lng: 35.3),
      ]) {
        final cubit = LiveTrackingCubit(
          repository: _ScriptedRepo(<GpsPoint?>[fix]),
          deliveryId: _id,
          refreshSignals: const Stream<void>.empty(),
        );
        await pumpEventQueue();
        await cubit.close();
      }

      final verdict = evaluateDwellPredicate(parsed());
      expect(verdict.distinctPositions, 3,
          reason: 'the naive reading of "≥3 distinct positions" IS satisfied '
              '— which is exactly why it is not the predicate');
      expect(verdict.screenEntries, 3);
      expect(verdict.pass, isFalse);
      expect(verdict.why, contains('not 1'));
    });

    test('NEGATIVE: one dwell, three reads, but the marker never moved -> FAIL',
        () async {
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: _ScriptedRepo(const [GpsPoint(lat: 33.1, lng: 35.1)]),
        deliveryId: _id,
        refreshSignals: bus.stream,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      bus.add(null);
      await pumpEventQueue();
      bus.add(null);
      await pumpEventQueue();

      final verdict = evaluateDwellPredicate(parsed());
      expect(verdict.screenEntries, 1);
      expect(verdict.distinctPositions, 1,
          reason: 'three reads of the same fix is a frozen marker — the P0');
      expect(verdict.pass, isFalse);
    });

    test('NEGATIVE: one dwell, three distinct positions, but NONE caused by a '
        'push -> FAIL', () async {
      final cubit = LiveTrackingCubit(
        repository: _ScriptedRepo(const [
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

      final verdict = evaluateDwellPredicate(parsed());
      expect(verdict.screenEntries, 1);
      expect(verdict.distinctPositions, 3);
      expect(verdict.pushAttributed, 0);
      expect(verdict.pass, isFalse,
          reason: 'resume+retry is not the push-refresh signal, and MB1 asks '
              'for ≥1 update attributable to a push');
    });
  });

  group('M6.c — the capture header V-1 reads buildSha off', () {
    test('the session header carries buildSha when the build defines it, and '
        'the event records land in the same file', () async {
      // V-1's contract: "reads buildSha off the on-device capture header and
      // matches it to the merged SHA". That row needs the header to actually
      // carry the key. `buildSha` is a compile-time
      // `String.fromEnvironment('JEEB_BUILD_SHA')`, so this assertion is only
      // meaningful under `--dart-define`; the pack runner runs this file BOTH
      // ways, and the branch below is what makes the un-defined run honest
      // rather than silently green.
      final tmp = await Directory.systemTemp.createTemp('mb1-diag-');
      addTearDown(() => tmp.delete(recursive: true));

      final sink = DiagFileSink(
        baseDirectoryProvider: () async => tmp,
        role: 'client',
      );
      await sink.start();
      Diag.persistentSink = sink;
      addTearDown(() => Diag.persistentSink = null);

      final cubit = LiveTrackingCubit(
        repository: _ScriptedRepo(const [GpsPoint(lat: 33.1, lng: 35.1)]),
        deliveryId: _id,
        refreshSignals: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      await sink.flush();

      final path = sink.sessionFilePath;
      expect(path, isNotNull, reason: 'the sink never opened a file');
      final fileLines = await File(path!).readAsLines();
      expect(fileLines, isNotEmpty);

      final header = jsonDecode(fileLines.first) as Map<String, dynamic>;
      expect(header['t'], 'session');

      if (DiagFileSink.buildSha.isEmpty) {
        // Honest: no define, so this leg proves nothing about V-1's row. The
        // runner's `--dart-define` pass is where it is actually exercised.
        expect(header.containsKey('buildSha'), isFalse,
            reason: 'with no JEEB_BUILD_SHA define the key must be OMITTED, '
                'not written empty — an empty buildSha in a capture is worse '
                'than none, because it looks like an answer');
      } else {
        expect(header['buildSha'], DiagFileSink.buildSha,
            reason: 'V-1 matches this value against the merged SHA');
      }

      // And the events V-2 counts are in the SAME file as that header, which is
      // the only reason the header can attribute them.
      final body = fileLines.skip(1).map(
            (l) => jsonDecode(l) as Map<String, dynamic>,
          );
      final names = body
          .where((r) => r['t'] == 'evt')
          .map((r) => r['name'] as String)
          .toSet();
      expect(names, contains(kTrackingScreenOpenEvent));
      expect(names, contains(kTrackingPositionEvent));
    });
  });
}

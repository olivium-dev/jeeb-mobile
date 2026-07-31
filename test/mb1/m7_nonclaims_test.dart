// MB1 ITEM M7 — THE NON-CLAIMS, written as assertions rather than as prose.
//
// MB1's test pack calls for "unit + widget coverage for the tracking wire, with
// the explicit non-claim that no Firestore path is exercised". A non-claim in a
// comment is a promise; a non-claim in a test is a fact that reds when it stops
// being true. So:
//
//   M7.a  no Firestore/Firebase path exists under the tracking feature at all,
//         so the suite's silence about Firestore is STRUCTURAL, not luck
//   M7.b  `Firebase.apps` is empty in this process — the documented reason a
//         green suite proves nothing about realtime transport (GATE.md §7).
//         A 473-test green in this programme was already proven worthless by
//         exactly this: setting the chat wrap to return the plain HTTP gateway
//         — the feature entirely off — produced an identical all-pass suite.
//   M7.c  the device-only rows are enumerated, and the pack runner is required
//         to report them BLOCKED rather than PASS. GATE.md §4: BLOCKED is VOID
//         and VOID counts as FAIL for closing a gate. A pack that could quietly
//         report a device row green is the failure mode this whole gate exists
//         to prevent.

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mb1_pack_support.dart';

/// The claims in MB1 that NO host test can settle, with the reason. Kept here
/// so the pack states its own boundary instead of leaving a verifier to infer
/// it from what is missing.
const Map<String, String> kDeviceOnlyClaims = <String, String>{
  'W1.4 / R1 — APK identity': 'the APK must be built from the MERGED sha and '
      'its buildSha matched on the handset; a host suite has no APK',
  'V-2 — ≥3 distinct positions in one dwell': 'requires a real foreground '
      'dwell with real gateway fixes. M6 proves the INSTRUMENT and the '
      'PREDICATE; only a capture proves the numbers',
  'V-2 — offer_accepted in the s24 shade': 'a shade is an OS surface. '
      'Firebase.apps is empty here, so no push transport is even constructed',
  'V-2 — user-switch push arrives for B and not for A': 'arrival is the '
      'predicate. M4 proves the client ISSUES the register hop; a registration '
      'row flip proves an upsert, not arrival',
  'V-2 — 6-min zero-stream window': 'M1 proves no cadence in a fakeAsync zone. '
      'Only a recorder capture proves nothing left the handset',
  'V-1 — recorder DB rows, and buildSha off the capture header':
      'there is no capture without a device round',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M7.a — the tracking feature has NO Firestore path to exercise', () {
    test('lib/features/live_tracking/** references no Firestore or Firebase '
        'symbol', () {
      const needles = <String>[
        'cloud_firestore',
        'FirebaseFirestore',
        'firebase_core',
        '.snapshots(',
      ];
      final offenders = <String>[];
      for (final needle in needles) {
        offenders.addAll(
          occurrences(needle, dirs: const ['lib/features/live_tracking']),
        );
      }
      expect(offenders, isEmpty,
          reason: 'MB1 claims no Firestore path is exercised. If one appears '
              'here, that claim becomes false AND untestable in the same '
              'moment, because Firebase.apps is empty under flutter test:\n'
              '${offenders.join('\n')}');
    });

    test('DENOMINATOR + SELF CONTROL: the scanner really read that directory',
        () {
      final files = dartSources(const ['lib/features/live_tracking']);
      expect(files.length, greaterThan(5),
          reason: 'only ${files.length} files scanned — the path is wrong and '
              'the clean bill above is meaningless');
      // A needle that IS present, through the same code path.
      expect(
        occurrences('fetchLivePosition', dirs: const ['lib/features/live_tracking']),
        isNotEmpty,
        reason: 'the scanner found nothing for a token that is certainly '
            'there, so its empty results prove nothing',
      );
    });

    test('the ONE Firestore-shaped thing nearby is chat, and it is not on the '
        'tracking path', () {
      // POS control for the needles themselves: they match somewhere in lib/,
      // so "0 hits under live_tracking" is a scoped absence and not a typo.
      final anywhere = occurrences('cloud_firestore', dirs: const ['lib']);
      expect(anywhere, isNotEmpty,
          reason: 'POS CONTROL FAILED: "cloud_firestore" matches nowhere in '
              'lib/, so M7.a\'s zero could be a broken needle rather than a '
              'clean feature');
    });
  });

  group('M7.b — Firebase.apps is empty here (why a green suite is not proof)',
      () {
    test('no Firebase app is initialised in the test process', () {
      expect(Firebase.apps, isEmpty,
          reason: 'if this ever becomes non-empty, every "the suite is green '
              'so transport works" argument in this repo needs re-examining — '
              'and until then, no suite result may be read as transport '
              'evidence (GATE.md §7)');
    });
  });

  group('M7.c — the pack states what it cannot settle, and the runner may not '
      'call those rows PASS', () {
    test('every device-only claim carries a reason', () {
      expect(kDeviceOnlyClaims, isNotEmpty);
      for (final entry in kDeviceOnlyClaims.entries) {
        expect(entry.value.length, greaterThan(30),
            reason: '"${entry.key}" is listed as device-only with no real '
                'reason; an unexplained exclusion is how scope quietly '
                'shrinks');
      }
    });

    test('the pack runner declares the device item and reports it BLOCKED, '
        'never PASS', () {
      const runner = 'tool/mb1/run-pack.sh';
      final src = File(runner);
      expect(src.existsSync(), isTrue,
          reason: '$runner is part of this pack; without it each item cannot '
              'be run as a separate process with a separate verdict');
      final text = src.readAsStringSync();
      expect(text, contains('M8'),
          reason: 'the device row must be an ITEM, so it is visible in the '
              'pack output rather than absent from it');
      expect(text, contains('BLOCKED'));
      expect(text, contains('exit 2'),
          reason: 'BLOCKED must have its own exit code. Folding it into 0 '
              'lets a caller read a device-less run as a clean pass — GATE.md '
              '§4: VOID counts as FAIL for closing a gate.');
    });
  });
}

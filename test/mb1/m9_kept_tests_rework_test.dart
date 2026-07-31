// MB1 ITEM M9 — W1.1c, THE TWO KEPT TEST FILES.
//
// Added by the MB1 TEST AUTHOR, because W1.1c is a MEMBER ITEM with 45 budgeted
// writer-minutes and the pack had no item that could red for it. MB1 states it
// in terms that are unusually specific, and every clause is a place the work
// can be faked:
//
//   "W1.1c -- rework of the two KEPT test files, NOT A COMPILE FIX.
//    `live_tracking_push_driven_test.dart` and
//    `tracking_live_position_overlay_test.dart` declare stream-shaped fakes
//    against the deleted type; 7 OF THEIR 13 CASES are position-stream cases
//    that must be RE-EXPRESSED against `fetchLivePosition`.
//    KEEP overlay :151 / :180 -- they are the payload-adequacy pack."
//
// THE SHORTCUT THIS ITEM EXISTS TO CATCH. A stream-shaped fake against a
// deleted type does not compile, so `flutter test` forces SOME response — and
// the cheapest response that makes the suite green is to DELETE the seven
// cases. That leaves a green suite, a clean `dart analyze`, five clean grep
// receipts in M2, and SEVEN FEWER ASSERTIONS ABOUT THE COURIER POSITION than
// the tree had before the batch that exists to fix the courier position. Every
// other item in this pack passes on that tree. Counting is the only thing that
// separates "re-expressed" from "removed", so this item counts.
//
// The counts below were derived first-hand at `kPreFixBase` on 2026-07-31:
//
//   $ git show 30d12f1a:<file> | grep -cE '^\s*test\('
//     live_tracking_push_driven_test.dart   8
//     tracking_live_position_overlay_test.dart   5     -> 13 total, MB1's "13"
//
//   $ git show 30d12f1a:live_tracking_push_driven_test.dart | grep -n implements
//     28:  implements LiveTrackingRepository, <the deleted STREAMING capability>
//     60:  Stream<DeliveryLivePosition> <the deleted watch-shaped read>({
//
// (The two deleted symbols are described rather than spelled. They are banned
// tokens: MB1's V-1 runs a repo-wide `git grep` for them, so a doc comment here
// would hand that contract a hit off the file that proves there are none. M2's
// receipts red on exactly this, which is how the first draft of this comment
// was caught.)
//
// NON-CLAIM (GATE.md §3): `static` for the shape, `suite` for the green. The
// pack runner executes BOTH kept files as part of this item, so "reworked" is
// not asserted from their source alone — they have to actually pass. Neither
// half says anything about a phone.

import 'package:flutter_test/flutter_test.dart';

import 'mb1_pack_support.dart';

const String _pushDriven =
    'test/features/live_tracking/live_tracking_push_driven_test.dart';
const String _overlay =
    'test/features/live_tracking/tracking_live_position_overlay_test.dart';

/// `test(` declarations on their own line — the same matcher used against the
/// base tree, so the two counts are comparable.
int _caseCount(String source) =>
    RegExp(r'^\s*test\(', multiLine: true).allMatches(source).length;

void main() {
  group('M9.a — both files are KEPT (not deleted, not emptied)', () {
    for (final path in const <String>[_pushDriven, _overlay]) {
      test('$path survives', () {
        // POS CONTROL: it existed at the base, so "present" is a keep and not
        // a file that was always there under a different name.
        expect(gitShow(path, ref: kPreFixBase), isNotNull,
            reason: 'POS CONTROL COULD NOT RUN: $path is not at $kPreFixBase, '
                'so MB1\'s "KEPT" claim is about a file this pack cannot '
                'locate (GATE.md §6.3 L3 — unverifiable is rejected)');
        expect(() => readSource(path), returnsNormally,
            reason: 'MB1 deletes two test files by name '
                '(sse_live_position_stream_test.dart, '
                'tracking_sse_rearm_regression_test.dart) and KEEPS these '
                'two. Deleting a kept file is the cheapest way to make a '
                'stream-shaped fake compile.');
      });
    }
  });

  group('M9.b — RE-EXPRESSED, not removed: the case count may not shrink', () {
    // The heart of the item. Every other assertion here can be satisfied by a
    // file that lost its position cases; this one cannot.
    const baseCounts = <String, int>{_pushDriven: 8, _overlay: 5};

    baseCounts.forEach((path, expectedBase) {
      test('$path: $expectedBase cases at the base, at least that many now',
          () {
        final base = gitShow(path, ref: kPreFixBase);
        expect(base, isNotNull, reason: 'POS CONTROL COULD NOT RUN');
        expect(_caseCount(base!), expectedBase,
            reason: 'POS CONTROL FAILED: counted ${_caseCount(base)} `test(` '
                'declarations at $kPreFixBase, not $expectedBase. Either the '
                'matcher is broken or this pack has the wrong base commit — '
                'and MB1\'s "13 cases" arithmetic would be wrong with it.');

        final now = _caseCount(readSource(path));
        expect(now, greaterThanOrEqualTo(expectedBase),
            reason: 'W1.1c is a REWORK, not a compile fix. $path went from '
                '$expectedBase cases to $now: the position-stream cases were '
                'DELETED to make the file compile, not re-expressed against '
                'fetchLivePosition. A green suite with fewer assertions about '
                'the thing the batch fixes is a regression that looks like '
                'progress.');
      });
    });

    test('the POSITION GROUP itself still carries at least the 4 cases the '
        'base had, so "re-expressed" is measured where it happened', () {
      // The file-level floor above catches wholesale deletion (8 -> 4) but not
      // a partial one, because the file grew. MB1's arithmetic is specific —
      // "7 of their 13 cases are position-stream cases" = the 4 in this file's
      // position group plus the 3 in the overlay — so the count is taken
      // INSIDE the group that had to change.
      //
      // Anchored on the substring 'position axis', which both the base group
      // title ("N7 position axis — SSE stream, not poll") and the reworked one
      // ("W1.1 position axis — one snapshot read per EVENT, never a cadence")
      // contain. It is the last group in the file, so the slice runs to EOF.
      const anchor = 'position axis';

      final base = gitShow(_pushDriven, ref: kPreFixBase);
      expect(base, isNotNull, reason: 'POS CONTROL COULD NOT RUN');
      final baseIdx = base!.indexOf(anchor);
      expect(baseIdx, greaterThan(-1),
          reason: 'POS CONTROL FAILED: the base file has no group anchored on '
              '"$anchor", so there was no position group to re-express');
      expect(_caseCount(base.substring(baseIdx)), 4,
          reason: 'POS CONTROL FAILED: the base position group held '
              '${_caseCount(base.substring(baseIdx))} cases, not the 4 that '
              'MB1\'s "7 of 13" arithmetic depends on');

      final now = readSource(_pushDriven);
      final idx = now.indexOf(anchor);
      expect(idx, greaterThan(-1),
          reason: 'the position group is GONE from the kept file. Deleting the '
              'group is the cheapest way to make a stream-shaped fake compile, '
              'and it leaves the file-level count above satisfied by the '
              'status-axis cases alone.');
      expect(_caseCount(now.substring(idx)), greaterThanOrEqualTo(4),
          reason: 'the position group holds ${_caseCount(now.substring(idx))} '
              'cases; the base had 4 and every one of them had to be '
              're-expressed, not dropped');
    });

    test('13 cases across the two files at the base, and no fewer today', () {
      // MB1's own number, stated as an assertion so a drift in either file
      // cannot be absorbed by the other.
      final base = _caseCount(gitShow(_pushDriven, ref: kPreFixBase)!) +
          _caseCount(gitShow(_overlay, ref: kPreFixBase)!);
      expect(base, 13,
          reason: 'POS CONTROL FAILED: MB1 says "7 of their 13 cases"; the '
              'base tree carries $base');
      final now = _caseCount(readSource(_pushDriven)) +
          _caseCount(readSource(_overlay));
      expect(now, greaterThanOrEqualTo(13), reason: 'now $now, was $base');
    });
  });

  group('M9.c — the fakes are declared against the SURVIVING capability', () {
    test('the push-driven fake implements LivePositionSource and serves '
        'fetchLivePosition', () {
      // At the base this same class implemented the deleted STREAMING
      // capability and served a `watch`-shaped read returning
      // `Stream<DeliveryLivePosition>`. Both names are banned tokens and are
      // therefore assembled below rather than written out. POS CONTROL first,
      // so "it is snapshot-shaped now" is a change and not a property it
      // always had.
      final base = gitShow(_pushDriven, ref: kPreFixBase);
      expect(base, isNotNull, reason: 'POS CONTROL COULD NOT RUN');
      expect(base!.contains('LivePositionStream' 'Source'), isTrue,
          reason: 'POS CONTROL FAILED: the base fake was NOT declared against '
              'the deleted streaming type, so MB1\'s premise for W1.1c is '
              'wrong and there was nothing to re-express');

      final code = stripDartComments(readSource(_pushDriven));
      expect(code, contains('implements LiveTrackingRepository, '
          'LivePositionSource'),
          reason: 'the fake must implement the capability that SURVIVED. A '
              'fake still shaped like the deleted one is the compile error '
              'W1.1c was budgeted to resolve.');
      expect(RegExp(r'\bfetchLivePosition\(').hasMatch(code), isTrue,
          reason: 'the fake must serve the snapshot read the cubit now calls');
      expect(code.contains('watchLive' 'Position'), isFalse,
          reason: 'a surviving watch-shaped read is a held connection by '
              'another name');
      expect(RegExp(r'Stream<DeliveryLivePosition>').hasMatch(code), isFalse,
          reason: 'a position STREAM type in a kept fake is the deleted design '
              'reintroduced through the test tree, where no grep receipt in '
              'this pack is looking for a type expression');
    });

    test('the position group counts reads as a NUMBER, so "no cadence" is '
        'measurable in the kept file too', () {
      final code = stripDartComments(readSource(_pushDriven));
      expect(code, contains('positionReads'),
          reason: 'the kept file must be able to state the cadence claim as a '
              'count. Without a counter it can only assert that SOMETHING '
              'happened, which is what the stream version did.');
    });
  });

  group('M9.d — overlay :151 / :180, the payload-adequacy pack, SURVIVE', () {
    // MB1 names these two by line at the base and says KEEP. They are the only
    // cases in either file that assert the SHAPE OF THE GATEWAY PAYLOAD rather
    // than the cubit's behaviour — i.e. the only thing standing between a
    // renamed JSON field and a silently empty marker.
    const kept = <int, String>{
      151: 'DioLiveTrackingRepository.fetchLivePosition parses the tracking ',
      180: 'fetchLivePosition is null on the legacy mock base (no tracking '
          'route)',
    };

    kept.forEach((baseLine, title) {
      test('overlay :$baseLine — "${title.trim()}" is still declared', () {
        // POS CONTROL: pin the title to the exact LINE MB1 names, at the base.
        // If MB1's line number is wrong this reds HERE, as a defect in the
        // batch document, rather than silently passing the file.
        final base = gitShow(_overlay, ref: kPreFixBase);
        expect(base, isNotNull, reason: 'POS CONTROL COULD NOT RUN');
        final baseLines = base!.split('\n');
        expect(baseLines.length, greaterThanOrEqualTo(baseLine),
            reason: 'the file had only ${baseLines.length} lines at the base');
        expect(baseLines[baseLine - 1], contains(title),
            reason: 'POS CONTROL FAILED: line $baseLine of $_overlay at '
                '$kPreFixBase does not carry the title MB1 says it does. '
                'Actual:\n  ${baseLines[baseLine - 1]}');

        // THE KEEP. Matched by TITLE rather than by line, because the file
        // legitimately shifted when the sibling cases were re-expressed.
        expect(readSource(_overlay), contains(title),
            reason: 'MB1 says KEEP overlay :$baseLine. It is gone. This is '
                'the payload-adequacy pack — with it removed, a gateway that '
                'renames a JSON field produces an empty marker and a fully '
                'green suite.');
      });
    });

    test('the overlay file still exercises the REAL Dio repository, not a fake',
        () {
      final code = stripDartComments(readSource(_overlay));
      expect(code, contains('DioLiveTrackingRepository'),
          reason: 'payload adequacy is a claim about the PARSER. Re-expressing '
              'these two against a hand-written fake would assert that the '
              'fake returns what the fake was told to return.');
    });
  });

  group('M9.e — neither kept file carries a dead token (the 5th cleanup site)',
      () {
    // MB1's amendment #7 raised the doc-comment cleanups from 4 to 5, and the
    // fifth is `live_tracking_push_driven_test.dart:20` — a KEPT file, OUTSIDE
    // lib/. M3 pins the four lib/ sites; this is the per-site pin for the one
    // that lives here, and it is the residual a feature-scoped sweep misses.
    const sites = <String, int>{_pushDriven: 20};

    sites.forEach((path, baseLine) {
      test('$path:$baseLine — the deleted alias is gone from this file', () {
        const alias = '/v1/geo/jeeb/' 'stream/';
        final base = gitShow(path, ref: kPreFixBase);
        expect(base, isNotNull, reason: 'POS CONTROL COULD NOT RUN');
        final baseLines = base!.split('\n');
        expect(baseLines[baseLine - 1].contains(alias), isTrue,
            reason: 'POS CONTROL FAILED: line $baseLine of $path at '
                '$kPreFixBase does not carry the alias. Actual:\n'
                '  ${baseLines[baseLine - 1]}');

        expect(occurrencesInFile(alias, path), isEmpty,
            reason: 'V-1 greps REPO-WIDE with no pathspec, so a survivor in a '
                'kept TEST file fails the same row as one in lib/');
      });
    });

    test('the rework was DATED AS HISTORY, not silently rewritten (T9)', () {
      // The doc comment at the top of the kept file is the only record of WHY
      // its position group changed shape. Erasing it passes every grep and
      // loses the reason.
      final src = readSource(_pushDriven);
      expect(src, contains('W1.1'),
          reason: 'the kept file must name the change that re-cut it');
      expect(src, contains('LocationController.cs'),
          reason: 'cite the gateway statement that the route is gone, so the '
              'next reader does not have to re-derive it');
    });
  });
}

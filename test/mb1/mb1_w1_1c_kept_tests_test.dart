import 'package:flutter_test/flutter_test.dart';

import 'mb1_source_lens.dart';

/// MB1 member item **W1.1c** — the rework of the two KEPT test files.
///
/// `live_tracking_push_driven_test.dart` and
/// `tracking_live_position_overlay_test.dart` were written against the deleted
/// stream capability. MB1's contract for them is specific and easy to satisfy
/// the wrong way:
///
/// > *the position-stream cases must be **re-expressed against
/// > `fetchLivePosition`** … keep the payload-adequacy pack.*
///
/// The wrong way is to make them compile by **deleting** the position cases.
/// That yields a green suite, a clean analyze, and zero coverage of the very
/// method MB1 exists to wire — and nothing else in the pack would notice,
/// because "does `fetchLivePosition` have a production call site" is a
/// different question from "does anything TEST it".
///
/// So this row asserts what survived, by NAME. Line numbers are deliberately
/// not used: `MB1.md` cites overlay `:151` / `:180`, and PR #204 has already
/// moved them — a line-numbered receipt would red on correct work.
///
/// Class: `static`. The two files' own green run is the behavioural half and
/// the MB1 runner executes them as part of this same item.

const String _pushDriven =
    'test/features/live_tracking/live_tracking_push_driven_test.dart';
const String _overlay =
    'test/features/live_tracking/tracking_live_position_overlay_test.dart';

/// Case names that must survive the rework. Substrings, not full titles — the
/// full title is prose and gets reworded; these fragments are the claim.
const List<String> _payloadAdequacyPack = <String>[
  // the parse of the surviving route's body
  'fetchLivePosition parses the tracking',
  // the gateway's own staleness verdict must reach the domain object
  'fetchLivePosition carries the gateway staleness verdict',
  // the legacy mock base has no tracking route and must degrade to null
  'fetchLivePosition is null on the legacy mock base',
];

/// Position-axis cases that must still exist in the push-driven file.
const List<String> _positionAxisCases = <String>[
  'reads the position on mount and again on each push',
  'no event ⇒ no position read after 60 virtual seconds',
  'a terminal row never reads a position',
  'reaching a terminal status stops reading the position',
];

int _countCases(String src) =>
    RegExp(r'\n\s*(?:testWidgets|test)\(').allMatches(src).length;

void main() {
  group('MB1 W1.1c — the kept files still EXERCISE fetchLivePosition', () {
    for (final path in <String>[_pushDriven, _overlay]) {
      test('$path drives the surviving read', () {
        final code = MB1Source.stripComments(MB1Source.raw(path));
        expect(
          RegExp(r'fetchLivePosition').hasMatch(code),
          isTrue,
          reason:
              'the cheapest way to make these files compile after the SSE '
              'teardown is to delete every position case. That is green, '
              'analyzable, and leaves the wired method untested.',
        );
        expect(
          code,
          contains('LivePositionSource'),
          reason:
              'the fake must implement the capability interface the cubit '
              'casts to — a fake that only implements LiveTrackingRepository '
              'takes the `is! LivePositionSource` early return and the test '
              'passes without ever reading a position.',
        );
      });
    }

    test('the payload-adequacy pack survived, by NAME', () {
      final overlay = MB1Source.raw(_overlay);
      for (final name in _payloadAdequacyPack) {
        expect(
          overlay,
          contains(name),
          reason:
              'MB1.md: "Keep overlay :151 / :180 — they are the '
              'payload-adequacy pack." Cited here by name because #204 '
              'already moved those lines.',
        );
      }
    });

    test('the position-axis cases survived, by NAME', () {
      final pushDriven = MB1Source.raw(_pushDriven);
      for (final name in _positionAxisCases) {
        expect(pushDriven, contains(name));
      }
    });

    test('the no-clock cases are still present in BOTH files', () {
      // These are the cases that would have caught the original P0 and did
      // not, because they were asserted against the stream. They are the most
      // valuable thing in either file and the easiest to lose in a rework.
      expect(
        MB1Source.raw(_pushDriven),
        contains('60 virtual seconds'),
        reason: 'the virtual-time no-poll assertion is what proves there is no '
            'cadence. Deleting it is how a re-armed timer gets back in.',
      );
      expect(
        MB1Source.raw(_pushDriven),
        contains('fakeAsync'),
        reason: 'a real-time test cannot assert "nothing happened for 60s".',
      );
    });
  });

  group('MB1 W1.1c — the rework did not thin the files out', () {
    test('case counts are at or above the floor MB1 committed to', () {
      // The floors are the values COUNTED on this branch, asserted as `>=` so
      // ADDING cases is fine and DELETING them reds.
      //
      // My first draft put the push-driven floor at 11 and it went red at 9 —
      // because I had read the figure off a `grep` whose alternation included
      // `group(`. Two groups, nine cases. Recorded rather than quietly fixed:
      // a floor set from an eyeballed grep is a fabricated threshold, and it
      // fails on correct work.
      //
      // MB1.md accounts for 13 cases across these two files, 7 of them
      // position cases. That figure is against the PRE-#204 base; the pair
      // carries 16 now, so 13 is a floor the current tree clears with room.
      final pushCount = _countCases(MB1Source.raw(_pushDriven));
      final overlayCount = _countCases(MB1Source.raw(_overlay));
      expect(
        pushCount,
        greaterThanOrEqualTo(9),
        reason: 'push-driven file lost cases (counted 9 at the branch head)',
      );
      expect(
        overlayCount,
        greaterThanOrEqualTo(7),
        reason: 'overlay file lost cases (counted 7 at the branch head)',
      );
      expect(
        pushCount + overlayCount,
        greaterThanOrEqualTo(13),
        reason:
            'MB1.md accounts for 13 cases across these two files. Fewer than '
            'that means the rework was a deletion.',
      );
    });

    test('POSITIVE CONTROL — the counter counts, and is not pinned', () {
      expect(_countCases('\n  test(\'a\', () {});\n  test(\'b\', () {});'), 2);
      expect(_countCases('\n  testWidgets(\'a\', (t) async {});'), 1);
      expect(_countCases('\n  // test( in a comment does not count'), 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'mb1_source_lens.dart';

/// MB1 member item **"the 5 stale doc-comment cleanups"**, as its own pack row.
///
/// ## Why this is a SEPARATE file from the SSE-teardown receipts
///
/// `GATE.md` §8: items are committed one per member item exactly so a bad one
/// can be reverted alone. A pack that folds the doc cleanups into the W1.1
/// teardown receipts can only report "a grep row is red" — it cannot say
/// whether the *code* regressed or a *sentence* did, and those have opposite
/// remedies (revert a wire vs. re-edit a comment).
///
/// ## Why this file is WIDER than the W1.1 receipts
///
/// `sse_teardown_grep_receipt_test.dart` walks `lib/` + `test/` for `.dart`
/// files. **V-1's predicate is `git grep` with no pathspec**, which searches
/// every TRACKED file of every extension — `.md`, `.json`, `.yaml`, `.xml`,
/// `.kt`, `.sh`. A residual in `docs/`, in `STATE/`, in an Android resource
/// comment or in a `.github` file is a hit that the narrower lens cannot see,
/// and MB1 attempt 1 was failed by exactly this class of miss: the residual
/// that survived sat in a KEPT file **outside `lib/`**.
///
/// So this row asks git what is tracked and reads all of it. If the two lenses
/// ever disagree, this one is the one that matches the gate.
///
/// ## The self-reference trap
///
/// A file that spells the forbidden tokens in order to assert their absence
/// **is itself a repo-wide hit**, and reds the row it exists to defend. Every
/// token below is assembled at runtime from fragments; there is a case at the
/// bottom that reads this file's own bytes and fails if anyone re-joins them.
///
/// Class: `static`. It proves nothing runs; it proves what the tree says.

/// The residual literals MB1's doc cleanups had to remove. Assembled, never
/// spelled — see the library doc.
final List<String> _residualTokens = <String>[
  // the deleted SSE alias route
  MB1Source.tok(<String>['geo/jeeb', '/stream']),
  // the deleted re-arm backoff constant
  MB1Source.tok(<String>['kPosition', 'RearmBackoff']),
];

/// The files `MB1.md` names as carrying a residual. They were EDITED, not
/// deleted — a "cleanup" performed by deleting the file would satisfy every
/// absence assertion while destroying live code, so their continued existence
/// is asserted separately.
const List<String> _editedNotDeleted = <String>[
  'lib/features/live_tracking/domain/delivery_tracking_info.dart',
  'lib/features/chat/application/chat_cubit.dart',
  'lib/features/deep_link_targets/chat_detail_screen.dart',
  'test/features/live_tracking/live_tracking_push_driven_test.dart',
];

void main() {
  group('MB1 doc cleanups — 0 residuals across EVERY tracked file', () {
    for (final token in _residualTokens) {
      test('"$token" appears in 0 tracked files (any extension)', () {
        final skipped = <String>[];
        final hits = MB1Source.trackedFilesContaining(token, skipped: skipped);
        expect(
          hits,
          isEmpty,
          reason:
              'V-1 runs `git grep` with NO pathspec. Prose is indistinguishable '
              'from a live call site to grep, so a doc comment here fails the '
              'gate row. If the hit is THIS file, someone un-split the token.',
        );
        // The denominator, quoted with the zero — a bare zero over an empty or
        // heavily-skipped population is worthless.
        expect(
          MB1Source.trackedFiles().length,
          greaterThan(1000),
          reason: 'population sanity: the lens must be reading a real tree',
        );
        expect(
          skipped.length,
          lessThan(MB1Source.trackedFiles().length ~/ 4),
          reason:
              'if a quarter of the tree is undecodable the zero above is a '
              'measurement of the skip list, not of the tree',
        );
      });
    }

    test('POSITIVE CONTROL — the lens finds a token that IS present', () {
      // Without this, all the isEmpty results above are satisfied by a lens
      // that reads nothing at all. `Sse_Alias_Route_Is_Gone` is the durable
      // handle the cleanups replaced the dead URL WITH, so it is guaranteed
      // present precisely because the cleanups landed.
      final hits = MB1Source.trackedFilesContaining(
        MB1Source.tok(<String>['Sse_Alias_Route', '_Is_Gone']),
      );
      expect(
        hits,
        isNotEmpty,
        reason:
            'the cleanups replaced a dead URL with the name of the gateway '
            'guard test. A zero here means the lens is blind.',
      );
      expect(hits.any((h) => h.startsWith('lib/')), isTrue);
    });

    test('NEGATIVE CONTROL — a token that never existed reports 0', () {
      // Assembled like the real ones. The first draft spelled this control as
      // a plain literal with a nonsense SUFFIX — and the self-check below
      // caught it immediately, because a token with a suffix still CONTAINS
      // the forbidden token as a prefix and is therefore itself a repo-wide
      // hit. That is the whole reason the self-check exists.
      expect(
        MB1Source.trackedFilesContaining(
          MB1Source.tok(<String>['kPosition', 'RearmBack', 'offXyzzyNotReal']),
        ),
        isEmpty,
      );
    });

    test('the named cleanup sites were EDITED, not deleted', () {
      for (final path in _editedNotDeleted) {
        // `raw` fails loudly on a missing file, which is the assertion.
        expect(MB1Source.raw(path), isNotEmpty, reason: '$path must still exist');
      }
    });

    test('this file does not defeat its own receipts', () {
      final self = MB1Source.raw('test/mb1/mb1_doc_residual_receipts_test.dart');
      for (final token in _residualTokens) {
        expect(
          self.contains(token),
          isFalse,
          reason:
              '"$token" is spelled literally in this file, so V-1\'s repo-wide '
              'grep will name it and the row reds on the INSTRUMENT rather '
              'than on the code — the most confusing possible failure.',
        );
      }
    });
  });

  group('MB1 doc cleanups — the two lenses agree', () {
    test('every .dart hit the narrow lens would find is also a tracked file', () {
      // Guards against the reverse trap: an UNTRACKED residual is invisible to
      // `git grep` and therefore to V-1, but visible to a filesystem walk. If
      // the two ever disagree, the gate follows git — and this assertion is
      // where that discrepancy surfaces instead of being discovered at the gate.
      final tracked = MB1Source.trackedFiles().toSet();
      final walked = MB1Source.dartFilesUnder(<String>['lib', 'test'])
          .map(MB1Source.rel)
          .where((p) => !p.contains('/generated/'))
          .toList();
      final untracked = walked.where((p) => !tracked.contains(p)).toList();
      expect(
        untracked,
        isEmpty,
        reason:
            'these .dart files exist on disk but git does not track them, so '
            'V-1 CANNOT see a residual in them. Stage them, or the receipts '
            'are measuring a different tree than the gate.',
      );
    });
  });
}

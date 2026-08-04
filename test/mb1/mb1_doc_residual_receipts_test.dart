import 'package:flutter_test/flutter_test.dart';

import 'mb1_source_lens.dart';

/// MB1 member item **"the 5 stale doc-comment cleanups"**, as its own pack row.
/// ## Why this is a SEPARATE file from the SSE-teardown receipts

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
        expect(
          MB1Source.trackedFiles().length,
          greaterThan(1000),
          reason: 'population sanity: the lens must be reading a real tree',
        );
        // Binary assets are undecodable BY NATURE and say nothing about the
        // lens; the MIDNIGHT redesign added ~340 capture PNGs, which drifted
        // the raw ratio past a quarter without the text corpus changing.
        const binaryExt = <String>['.png', '.jpg', '.jpeg', '.webp', '.ttf',
            '.otf', '.ttc', '.ico', '.jar', '.keystore', '.p12', '.zip'];
        final skippedText = skipped
            .where((f) => !binaryExt.any((e) => f.toLowerCase().endsWith(e)))
            .toList();
        final textTracked = MB1Source.trackedFiles()
            .where((f) => !binaryExt.any((e) => f.toLowerCase().endsWith(e)))
            .length;
        expect(
          skippedText.length,
          lessThan(textTracked ~/ 4),
          reason:
              'if a quarter of the TEXT tree is undecodable the zero above is '
              'a measurement of the skip list, not of the tree',
        );
      });
    }

    test('POSITIVE CONTROL — the lens finds a token that IS present', () {
      // Without this, all the isEmpty results above are satisfied by a lens
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

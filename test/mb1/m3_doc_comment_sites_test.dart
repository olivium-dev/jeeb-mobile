// MB1 ITEM M3 — the FOUR stale doc-comment cleanups.
//
// Member item: "4 stale doc-comment cleanups so the repo-wide greps can
// actually reach 0: delivery_tracking_info.dart:88, chat_cubit.dart:17,
// chat_detail_screen.dart:92 and :1542".
//
// These are prose, not callers — which is precisely why they are load-bearing.
// A verifier greps the TREE, not the AST, so a doc comment quoting a deleted
// route is byte-identical to a live one. Three of the four sat OUTSIDE
// lib/features/live_tracking/, which is how they survived a feature-scoped
// sweep.
//
// Each of the four gets its own `test()`, and each is pinned by LINE NUMBER at
// the pre-fix base, so a red names the exact site MB1 named. The line numbers
// were re-derived first-hand by the test author:
//
//   $ git grep -n -F <token> 30d12f1a… -- lib/
//   …/domain/delivery_tracking_info.dart:88
//   …/chat/application/chat_cubit.dart:17
//   …/deep_link_targets/chat_detail_screen.dart:92
//   …/deep_link_targets/chat_detail_screen.dart:1542
//
// The second assertion per site is the T9 doctrine this programme runs on: a
// superseded claim is DATED AS HISTORY, never silently deleted. A cleanup that
// merely erases the sentence passes the grep and fails here — and it should,
// because the next agent then has no record of why the precedent was wrong.

import 'package:flutter_test/flutter_test.dart';

import 'mb1_pack_support.dart';

/// One named site: file, the line it occupied at [kPreFixBase], and the token
/// that made it a grep hit.
class _Site {
  const _Site(this.path, this.baseLine, this.token, this.what);
  final String path;
  final int baseLine;
  final String token;
  final String what;
}

/// The two dead tokens, assembled (see mb1_pack_support.dart for why).
const String _aliasToken = '/v1/geo/jeeb/' 'stream/';
const String _backoffToken = 'kPositionRearm' 'Backoff';

const List<_Site> _sites = <_Site>[
  _Site(
    'lib/features/live_tracking/domain/delivery_tracking_info.dart',
    88,
    _aliasToken,
    'named the deleted SSE alias as a SECOND producer of the '
        'TrackingPolylineDto shape',
  ),
  _Site(
    'lib/features/chat/application/chat_cubit.dart',
    17,
    _backoffToken,
    'cited the deleted re-arm backoff as precedent for the chat cold-load '
        'retry',
  ),
  _Site(
    'lib/features/deep_link_targets/chat_detail_screen.dart',
    92,
    _backoffToken,
    '"Mirrors" the same deleted constant',
  ),
  _Site(
    'lib/features/deep_link_targets/chat_detail_screen.dart',
    1542,
    _backoffToken,
    '"the same shape and the same argument as" the same deleted constant',
  ),
];

void main() {
  group('M3.a — each named site, pinned by line at the pre-fix base', () {
    for (final site in _sites) {
      final name = '${site.path.split('/').last}:${site.baseLine}';
      test('$name — ${site.what}', () {
        // POSITIVE CONTROL. Read the exact line MB1 names, at the base commit,
        // and require the dead token to be on it. If MB1's line number were
        // wrong, or the file were renamed, this reds HERE — as a defect in the
        // batch document, not as a false clean bill for the code.
        final baseText = gitShow(site.path, ref: kPreFixBase);
        expect(baseText, isNotNull,
            reason: 'POS CONTROL COULD NOT RUN: cannot read ${site.path} at '
                '$kPreFixBase. Unverifiable is rejected, not passed '
                '(GATE.md §6.3 L3).');
        final baseLines = baseText!.split('\n');
        expect(baseLines.length, greaterThanOrEqualTo(site.baseLine),
            reason: 'the file had only ${baseLines.length} lines at the base, '
                'so MB1\'s line ${site.baseLine} cannot be right');
        expect(baseLines[site.baseLine - 1].contains(site.token), isTrue,
            reason: 'POS CONTROL FAILED: line ${site.baseLine} of '
                '${site.path} at $kPreFixBase does not carry the token MB1 '
                'says it does. Actual line:\n'
                '  ${baseLines[site.baseLine - 1]}');

        // THE CLEANUP. Scoped to this one file, so a red names one site.
        final now = occurrencesInFile(site.token, site.path);
        expect(now, isEmpty,
            reason: 'the dead token survives in ${site.path}, so the repo-wide '
                'grep MB1 V-1 runs cannot reach 0:\n${now.join('\n')}');
      });
    }
  });

  group('M3.b — the claim was DATED AS HISTORY, not deleted (T9 doctrine)', () {
    test('delivery_tracking_info.dart records why the second producer went',
        () {
      final src = readSource(_sites[0].path);
      expect(src, contains('MB1 W1.1'));
      expect(src.toLowerCase(), contains('retained not deleted'),
          reason: 'a silent erasure passes the grep and loses the reason');
      expect(src, contains('LocationController.cs:22-31'),
          reason: 'cite the gateway statement, so the next reader does not '
              'have to re-derive that the route is gone');
    });

    test('chat_cubit.dart records that the cited precedent was WRONG', () {
      final src = readSource(_sites[1].path);
      expect(src, contains('MB1 W1.1'));
      expect(src.toLowerCase(), contains('retained not deleted'));
      expect(src.toLowerCase(), contains('terminat'),
          reason: 'the correction that matters: a widening backoff is not by '
              'itself a defence against a loop — TERMINATING on success is. '
              'Without that sentence the file still teaches the defect.');
    });

    test('chat_detail_screen.dart carries a dated correction for BOTH sites',
        () {
      // Two of the four sites live in this one file, so one marker is not
      // enough: assert two, or site :92 and site :1542 cannot red apart.
      final src = readSource(_sites[2].path);
      final markers = 'Corrected (MB1'.allMatches(src).length;
      expect(markers, greaterThanOrEqualTo(2),
          reason: 'sites :92 and :1542 each need their own dated correction; '
              'found $markers');
      expect(src.toLowerCase(), contains('retained not deleted'));
    });
  });

  group('M3.c — the repo-wide count MB1 V-1 actually runs', () {
    test('lib/** and test/** carry ZERO hits for either doc-comment token', () {
      for (final token in const <String>[_aliasToken, _backoffToken]) {
        // POS control first: the token was really there before.
        expect(gitGrepCount(token, ref: kPreFixBase), greaterThan(0),
            reason: 'POS CONTROL FAILED for "$token" — matcher is broken');
        expect(occurrences(token), isEmpty,
            reason: 'V-1 greps the whole tree, not just lib/');
      }
    });
  });
}

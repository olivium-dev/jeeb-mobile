// MB1 ITEM M2 — W1.1, THE TEARDOWN. One grep receipt PER DELETED SYMBOL.
//
// MB1's test pack calls for "grep-receipt tests for each deleted symbol". Each
// symbol therefore gets its OWN `test()`, so a single reintroduced symbol names
// itself in the failure line instead of collapsing five absences into one red.
//
// EVERY RECEIPT SHIPS ITS OWN POSITIVE CONTROL, in the same test. The scanner
// is pointed first at the PRE-FIX BASE (`origin/main` = 30d12f1a…, an ancestor
// of this branch) and must find the token there, then at the working tree and
// must find nothing. A matcher that finds nothing in either place is broken,
// not clean — and a pack that could not tell those apart would report the same
// green for a correct teardown and for a typo in a token.
//
// This is deliberately a DIFFERENT instrument from the writer's own
// `sse_teardown_grep_receipt_test.dart`: that one scans the working tree only
// and lumps all five tokens into one assertion. Two agents running the same
// command inherit the same blind spot (GATE.md §2).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'mb1_pack_support.dart';

void main() {
  group('M2.a — per-symbol receipts (each reds alone)', () {
    for (final banned in kBannedTokens) {
      test('${banned.label}: present at the pre-fix base, ZERO today', () {
        // POSITIVE CONTROL — the same token, the same matcher, against the tree
        // the fix moved off. This must be > 0 or the receipt below means
        // nothing.
        final before = gitGrepCount(banned.token, ref: kPreFixBase);
        expect(before, isNot(-1),
            reason: 'POS CONTROL COULD NOT RUN: git is unavailable or '
                '$kPreFixBase is not in this clone. An absence claim whose '
                'positive control cannot run is UNVERIFIABLE, and this '
                'programme treats unverifiable as rejected (GATE.md §6.3 L3) '
                '— not as passed.');
        expect(before, greaterThan(0),
            reason: 'POS CONTROL FAILED: "${banned.token}" is not found even '
                'at the pre-fix base $kPreFixBase. The matcher is broken, so '
                'the zero below proves nothing. Expected roughly '
                '${banned.beforeHits} hits across ${banned.beforeFiles} files.');

        // THE RECEIPT.
        final now = occurrences(banned.token);
        expect(now, isEmpty,
            reason: 'MB1 W1.1 deleted this. ${banned.why}\n'
                'Surviving references:\n${now.join('\n')}');
      });
    }

    test('DENOMINATOR: the scanner actually reads the tree', () {
      // "Zero hits" from a scanner that opened no files is the single easiest
      // false green in this pack.
      final files = dartSources(const ['lib', 'test']);
      expect(files.length, greaterThan(500),
          reason: 'only ${files.length} .dart files were scanned — run this '
              'from the jeeb-mobile package root');
      final lines = files.fold<int>(0, (a, f) => a + f.value.length);
      expect(lines, greaterThan(50000),
          reason: 'only $lines lines were read');
    });

    test('SELF CONTROL: the scanner finds a token that IS present', () {
      // Proves `occurrences()` can return a non-empty list at all. Without
      // this, a scanner that always returns [] passes all five receipts above.
      final hits = occurrences('fetchLivePosition', dirs: const ['lib']);
      expect(hits, isNotEmpty,
          reason: 'the scanner returned nothing for a token that is definitely '
              'in lib/ — every receipt above is therefore meaningless');
    });
  });

  group('M2.b — the deleted files are gone', () {
    const gone = <String>[
      'lib/features/live_tracking/data/sse_live_position_stream.dart',
      'test/features/live_tracking/sse_live_position_stream_test.dart',
      'test/features/live_tracking/tracking_sse_rearm_regression_test.dart',
    ];
    for (final path in gone) {
      test('$path is deleted', () {
        // POS CONTROL: the file existed at the base, so "absent" is a deletion
        // and not a path typo.
        expect(gitShow(path, ref: kPreFixBase), isNotNull,
            reason: 'POS CONTROL FAILED: $path did not exist at $kPreFixBase '
                'either, so its absence today proves nothing');
        expect(File(path).existsSync(), isFalse);
      });
    }
  });

  group('M2.c — ANTI-CONTROL: absence alone would be satisfied by deleting '
      'the feature outright', () {
    test('the live snapshot route is still in the repository', () {
      final repo = readSource(
        'lib/features/live_tracking/data/dio_live_tracking_repository.dart',
      );
      expect(repo.contains(r"'/deliveries/$deliveryId/tracking'"), isTrue,
          reason: 'LocationController.cs:227 is the route the gateway KEPT. '
              'Five clean receipts plus no replacement is a deleted feature, '
              'not a fixed one.');
    });

    test('the cubit still calls it, on named causes', () {
      final raw = readSource(
        'lib/features/live_tracking/application/live_tracking_cubit.dart',
      );
      final code = stripDartComments(raw);

      // A CALL EXPRESSION, on comment-stripped source. `contains(
      // 'fetchLivePosition')` on the raw file — which is what this assertion
      // used to be — is satisfied by the method's own doc comments, so the
      // production call site could be deleted with this test still green.
      final calls = RegExp(r'\.fetchLivePosition\(').allMatches(code).length;
      expect(calls, greaterThanOrEqualTo(1),
          reason: 'fetchLivePosition had ZERO non-test callers at the base. If '
              'this returns to zero the marker is frozen again.');

      // NEG CONTROL for the stripper itself: prove the raw source WOULD have
      // passed the weak form, so the strengthening above is load-bearing and
      // not a no-op rewrite.
      expect(raw.contains('fetchLivePosition'), isTrue);
      final mentionsInComments =
          RegExp('fetchLivePosition').allMatches(raw).length -
              RegExp('fetchLivePosition').allMatches(code).length;
      expect(mentionsInComments, greaterThan(0),
          reason: 'the weak assertion was satisfiable by comments alone — that '
              'is why it was replaced. If this ever reaches 0 the NEG control '
              'has stopped discriminating and must be re-cut.');

      for (final cause in const ['screenOpen', 'push', 'resume', 'retry']) {
        expect(code.contains('LivePositionReadCause.$cause'), isTrue,
            reason: 'the read must still be caused by $cause');
      }
    });

    test('the position capability is singular', () {
      final domain = readSource(
        'lib/features/live_tracking/domain/live_tracking_repository.dart',
      );
      final abstractClasses = RegExp(r'abstract class (\w+)')
          .allMatches(domain)
          .map((m) => m.group(1))
          .toList();
      expect(abstractClasses, contains('LivePositionSource'));
      expect(abstractClasses.where((c) => c!.contains('Stream')), isEmpty,
          reason: 'a second, streaming capability interface is exactly how the '
              'deleted stack comes back');
    });
  });
}

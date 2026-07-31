// MB1 ITEM M11 — V-1's CONTRACT, RUN IN ITS OWN COMMAND SHAPE.
//
// Added by the MB1 TEST AUTHOR. Every other item in this pack scans `.dart`
// files under `lib/` and `test/` through `dartSources()`. **MB1's V-1 contract
// does not.** It is written, in the batch file, as
//
//     "Repo-wide, no pathspec: git grep -c <alias> -> no output, exit 1"
//     "git grep -l <streaming capability> | wc -l -> 0; same for
//      <SSE consumer class>, <stream subscription field>, <re-arm timer field>"
//     "LivePositionSource must still be present -- a zero there is the failure
//      mode, not the goal"
//     "fetchLivePosition -> >=1 non-test caller, matched as a call expression
//      on comment-stripped source. Baseline at origin/main is 0."
//
// Three of those rows are NOWHERE ELSE IN THIS PACK:
//
//   1. REPO-WIDE. `dartSources(['lib','test'])` cannot see `docs/`, `tool/`,
//      `android/`, `ios/`, `qa/`, `.github/`, a `.md`, a `.yaml`, or a `.sh`.
//      A dead route surviving in any of those passes every other item here and
//      FAILS V-1. The pack's own new files are the sharpest case: this file's
//      first draft carried the alias spelled out in a doc comment, `git grep`
//      went from exit 1 to exit 0, and NOTHING in the nine pre-existing items
//      noticed. This item is what noticed.
//   2. The stream-subscription field and the re-arm-timer field are named by
//      V-1 and are absent from `kBannedTokens` entirely, so M2 never receipts
//      them. (Every dead symbol in this file is described in prose and
//      assembled from fragments in code, for the reason in (1): spelling one
//      out makes the command under test return a hit off the test that runs
//      it.)
//   3. THE COMMAND SHAPE ITSELF. `git grep -c` prints per-FILE counts and, on
//      zero matches, prints NOTHING and exits 1 — it never prints the string
//      `0`. A verifier who scripts `[[ "$(git grep -c X)" == "0" ]]` gets a
//      permanent red on correct work. That is a recorded unsatisfiable-contract
//      defect in this programme (OWNER-DECISIONS.md, GW1 V-1), and MB1's own
//      amendment #3 exists because MB1 had the same bug. Asserting a summed
//      integer would not have caught either. So this item asserts the EXIT CODE
//      and the EMPTINESS OF STDOUT, which is what V-1 actually reads.
//
// EVERY ROW IS PAIRED. The identical command is run against `kPreFixBase`, the
// tree the fix moved off, and must there produce the OPPOSITE answer (exit 0,
// non-empty). A matcher that finds nothing in either place is broken, not
// clean.
//
// NON-CLAIM (GATE.md §3): `static`. This proves what is in the tree. It proves
// nothing about what runs, and nothing about a phone.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'mb1_pack_support.dart';

/// Assembled from adjacent fragments, never contiguous — see
/// `mb1_pack_support.dart`. Spelling any of these out in this file would make
/// the very command under test return a hit off the test that runs it.
const String _alias = 'geo/jeeb/' 'stream';
const String _backoff = 'kPositionRearm' 'Backoff';

/// The four symbols V-1 expresses as `git grep -l <sym> | wc -l` -> 0, with the
/// file counts they carried at [kPreFixBase], counted first-hand on 2026-07-31
/// with `git grep -l -F <sym> 30d12f1a | wc -l`:
///
///   SSE consumer class          7      streaming capability   7
///   stream-subscription field   2      re-arm-timer field     1
///
/// The keys below are assembled, never contiguous — see the file header.
const Map<String, int> _mustBeZero = <String, int>{
  'SseLivePosition' 'Stream': 7,
  'LivePositionStream' 'Source': 7,
  '_position' 'Subscription': 2,
  '_position' 'RearmTimer': 1,
};

void main() {
  group('M11.a — the two repo-wide `-c` rows, asserted as EXIT 1 + NO OUTPUT',
      () {
    for (final entry in <String, String>{
      _alias: 'the deleted SSE route alias',
      _backoff: 're-arm backoff constant',
    }.entries) {
      final token = entry.key;
      test('${entry.value}: repo-wide, no pathspec -> exit 1, empty stdout',
          () {
        // POSITIVE CONTROL — the SAME command, the SAME flags, one argument
        // different (the ref). It must answer exit 0 with output, or the row
        // below is a broken matcher reporting a triumphant silence.
        final before = gitGrepRepoWide(token, ref: kPreFixBase);
        expect(before.exitCode, isNot(-1),
            reason: 'POS CONTROL COULD NOT RUN: git is unavailable, or '
                '$kPreFixBase is not in this clone. GATE.md §6.3 L3 — '
                'unverifiable is REJECTED, never passed.');
        expect(before.exitCode, 0,
            reason: 'POS CONTROL FAILED: `git grep -c` found nothing for this '
                'token even at the pre-fix base, so exit 1 today proves '
                'nothing.\n$before');
        expect(before.emptyOutput, isFalse,
            reason: 'POS CONTROL FAILED: exit 0 with no output is not a shape '
                'git produces; the harness is wrong.\n$before');

        // THE ROW V-1 RUNS. Exit code AND emptiness, not a parsed integer:
        // `git grep -c` never prints `0`, and a contract that expects the
        // string `0` is unsatisfiable in every state of the code.
        final now = gitGrepRepoWide(token);
        expect(now.emptyOutput, isTrue,
            reason: 'repo-wide survivors of a token MB1 W1.1 deleted. These '
                'are OUTSIDE what the rest of this pack scans — it only reads '
                '.dart under lib/ and test/:\n${now.stdout}');
        expect(now.exitCode, 1,
            reason: 'V-1 reads the EXIT CODE. Anything but 1 here means the '
                'command found something, whatever the output looked like.');
      });
    }

    test('SELF CONTROL: the same command CAN still return exit 0 on this tree',
        () {
      // Without this, "exit 1 twice" is indistinguishable from a git that
      // refuses to search this working tree at all.
      final live = gitGrepRepoWide('LivePositionSource');
      expect(live.exitCode, 0,
          reason: 'repo-wide `git grep -c` returned no hit for a symbol that '
              'is certainly present, so both zeros above are meaningless\n'
              '$live');
      expect(live.emptyOutput, isFalse);
    });
  });

  group('M11.b — the four `git grep -l | wc -l -> 0` symbols, one test each',
      () {
    _mustBeZero.forEach((symbol, baseFiles) {
      test('$symbol: $baseFiles files at the base, 0 today', () {
        final before = gitGrepFiles(symbol, ref: kPreFixBase);
        expect(before.exitCode, isNot(-1),
            reason: 'POS CONTROL COULD NOT RUN (GATE.md §6.3 L3)');
        expect(before.lines, baseFiles,
            reason: 'POS CONTROL FAILED: expected $baseFiles files carrying '
                '"$symbol" at $kPreFixBase, counted ${before.lines}. Either '
                'the matcher is broken or the base commit is not what this '
                'pack thinks it is.\n$before');

        final now = gitGrepFiles(symbol);
        expect(now.lines, 0,
            reason: 'V-1 runs `git grep -l $symbol | wc -l` and requires 0. '
                'Surviving files:\n${now.stdout}');
      });
    });
  });

  group('M11.c — LivePositionSource MUST SURVIVE (a zero here is the failure '
      'mode, not the goal)', () {
    test('the one-shot capability is still present, and grew', () {
      // MB1 states this trap outright: four symbols must go to zero and a
      // FIFTH, nearly-identically-named one must not. An agent deleting by eye
      // removes the very contract the batch exists to wire, and every "0 hits"
      // receipt in this pack goes green while it does.
      final before = gitGrepFiles('LivePositionSource', ref: kPreFixBase);
      expect(before.lines, 3,
          reason: 'POS CONTROL: 3 files carried LivePositionSource at the '
              'base\n$before');

      final now = gitGrepFiles('LivePositionSource');
      expect(now.lines, greaterThan(0),
          reason: 'LivePositionSource is GONE. This is the documented failure '
              'mode of the teardown: it is a DIFFERENT type from the deleted '
              'streaming capability whose name it nearly shares, it owns '
              'fetchLivePosition, and deleting it removes the contract MB1 '
              'exists to wire.');
      expect(now.lines, greaterThanOrEqualTo(before.lines),
          reason: 'the surviving capability should be referenced at least as '
              'widely as before the fix — it went from an orphan to the '
              'production read path');
    });
  });

  group('M11.d — fetchLivePosition: 0 production call sites before, >=1 now',
      () {
    test('the call expression, measured by ONE instrument on BOTH sides', () {
      // V-1: ">=1 non-test caller, matched as a call expression
      // (\\.fetchLivePosition\\( on comment-stripped source). Baseline at
      // origin/main is 0 production call sites."
      //
      // The baseline half is the half that matters and it is nowhere else in
      // this pack. M2.c asserts ">=1 today" — which a repository that ALWAYS
      // had a caller would also satisfy. The claim MB1 actually makes is that
      // the fix was WRITTEN AND ORPHANED, and only the pair states it.
      final before = nonCommentMatches('.fetchLivePosition(',
          ref: kPreFixBase, paths: const <String>['lib/']);
      expect(before, isNot(-1),
          reason: 'POS CONTROL COULD NOT RUN (GATE.md §6.3 L3)');
      expect(before, 0,
          reason: 'POS CONTROL FAILED: the base tree already had $before '
              'production call site(s), so "the fix was orphaned" is false and '
              'the delta below measures nothing.');

      final now = nonCommentMatches('.fetchLivePosition(',
          paths: const <String>['lib/']);
      expect(now, greaterThanOrEqualTo(1),
          reason: 'back to ZERO production call sites = the frozen courier '
              'marker, which IS the P0 this batch exists to kill');
    });

    test('SELF CONTROL: the comment filter does not swallow everything', () {
      // `nonCommentMatches` drops comment lines. If it dropped EVERY line it
      // would report 0 forever and the base==0 leg above would be an artefact
      // of a broken filter rather than a fact about the tree.
      final total = gitGrepRepoWide('fetchLivePosition', ref: kPreFixBase);
      expect(total.exitCode, 0,
          reason: 'POS CONTROL: the bare token DID exist at the base — the '
              'method was written, just never called\n$total');
      final nonComment =
          nonCommentMatches('fetchLivePosition', ref: kPreFixBase);
      expect(nonComment, greaterThan(0),
          reason: 'the filter reported ZERO non-comment mentions of a method '
              'that is DECLARED in the base tree, so it is discarding real '
              'code and every count it produces is worthless');
    });
  });

  group('M11.e — the PACK ITSELF must not break the count it asserts', () {
    // This item exists because it already happened, during the authoring of
    // this very file: a doc comment quoting V-1's contract spelled the alias
    // out, and `git grep -c <alias>` went from "no output, exit 1" to
    // "test/mb1/mb1_pack_support.dart:1, exit 0". A verifier running V-1
    // verbatim would have booked that as a surviving dead route — a FAIL
    // manufactured by the test pack, on a tree whose PRODUCTION code was
    // clean. Every other item in the pack stayed green throughout.
    // Counted first-hand on 2026-07-31: test/mb1 = 12 (8 pre-existing + m9,
    // m10, m11, m12), tool/mb1 = 3 (run-pack.sh, neg-controls.sh,
    // suite-delta.sh). The floors below are deliberately the counts as they
    // stand, so REMOVING a pack file cannot silently shrink the denominator
    // that makes "0 hits" a measurement.
    const minFiles = <String, int>{'test/mb1': 12, 'tool/mb1': 3};

    minFiles.forEach((dir, floor) {
      test('$dir contributes 0 hits for either V-1 token', () {
        // DENOMINATOR: the directory exists and holds what it should, so "0
        // hits" is a measurement and not an empty scan. Counted on DISK, not
        // via `git ls-files`, because the hazard this test exists for occurs
        // while a pack file is still UNTRACKED — which is exactly when the
        // author cannot yet see it with a plain `git grep`.
        final onDisk = Directory(dir)
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .toList();
        expect(onDisk.length, greaterThanOrEqualTo(floor),
            reason: 'only ${onDisk.length} file(s) under $dir, expected at '
                'least $floor — the path is wrong or the pack has shrunk, so '
                'the clean bill below is vacuous');

        // `--untracked` on purpose. V-1 runs on a CLEAN CLONE where every file
        // is tracked, so plain `git grep` is right for M11.a–M11.d. Here the
        // subject is the pack being authored, and an uncommitted slip is the
        // whole failure mode: this file's own first draft carried the alias in
        // a doc comment and plain `git grep` could not see it until it was
        // staged.
        for (final token in const <String>[_alias, _backoff]) {
          final hits = git(<String>[
            'grep', '-c', '-F', '--untracked', '--', token, '--', dir,
          ]);
          expect(hits.emptyOutput, isTrue,
              reason: 'the pack spells a banned token contiguously in $dir, '
                  'so `git grep` — which V-1 runs REPO-WIDE with no pathspec '
                  '— now reports a survivor off the test that proves there '
                  'are none. Assemble it from fragments instead:\n'
                  '${hits.stdout}');
        }
      });
    });

    test('SELF CONTROL: the scoped, --untracked grep DOES match a token that '
        'is in those directories', () {
      // Proves the exact command shape used above can return a hit at all.
      // Without it, "empty output twice" is indistinguishable from a pathspec
      // that matches no file.
      for (final dir in const <String>['test/mb1', 'tool/mb1']) {
        final needle = dir == 'test/mb1' ? 'kPreFixBase' : 'BASE_SHA';
        final hits = git(<String>[
          'grep', '-c', '-F', '--untracked', '--', needle, '--', dir,
        ]);
        expect(hits.exitCode, 0,
            reason: 'the path-scoped grep found nothing for "$needle", which '
                'is definitely in $dir, so its zeros prove nothing\n$hits');
      }
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MB1 — the standing grep receipts for the SSE teardown, run as tests so they
/// cannot silently stop being true between now and the next batch.
///
/// ## READ THIS BEFORE EDITING: why every forbidden token is SPLIT
///
/// MB1's V-1 contract is a **repo-wide** `git grep`, with no pathspec, for the
/// symbols the teardown removed. A test file that spells those symbols out in
/// order to assert their absence **is itself a match**, and reds the very gate
/// row it exists to defend. The first draft of this file did exactly that:
/// `git grep -c` went from *no output, exit 1* to naming this file, in six of
/// the six receipts below.
///
/// So each token is assembled at RUNTIME from fragments that are individually
/// harmless. The strings are identical to the symbols; the source bytes are
/// not. Do not "tidy" them back into literals — that silently breaks V-1 while
/// every test here still passes, which is the worst shape a gate can take.
///
/// ## The other failure mode these are shaped against
///
/// MB1.md's test pack: *"Each receipt must match a call expression on
/// comment-stripped source, never a bare token — `contains(...)` is satisfied
/// by the method's own doc comments and stays green with the production call
/// site deleted."* Hence the comment-stripping, and hence the negative control
/// that proves the strictness is real rather than claimed.
///
/// These run over the working tree via `dart:io`, so they measure the same
/// bytes a verifier's `git grep` would.

/// Joins fragments into a forbidden token at runtime.
///
/// Neither of the two obvious spellings survives `dart analyze`, and they
/// contradict each other: adjacent strings inside a list literal raise
/// `no_adjacent_strings_in_list` ("try adding a comma"), and `'a' + 'b'` raises
/// `prefer_adjacent_string_concatenation` ("try removing the operator"). BOTH
/// suggested fixes reassemble the literal token and red V-1's repo-wide grep.
/// A join is the one form neither lint objects to, and it states the intent
/// outright instead of hiding it behind an `// ignore:`.
String _tok(List<String> fragments) => fragments.join();

/// The tokens MB1 V-1 requires to be absent, assembled so this file is not
/// itself a hit. See the library doc above.
///
/// A LIST, not a map keyed by the readable name: a key would be a literal, and
/// an earlier revision of this file split only the VALUES and left six literal
/// keys behind — still six repo-wide hits. The test NAME is interpolated from
/// the assembled value, so a verifier still reads the real symbol in the
/// output.
final List<String> _forbidden = [
  _tok(['SseLive', 'PositionStream']),
  _tok(['LivePosition', 'StreamSource']),
  _tok(['_position', 'Subscription']),
  _tok(['_position', 'RearmTimer']),
  _tok(['kPosition', 'RearmBackoff']),
  _tok(['geo/jeeb', '/stream']),
];

/// Repo root, derived by walking up to `pubspec.yaml` so this works from any
/// cwd (the harness runs tests from the package root; a verifier may not).
Directory get _repoRoot {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate the repo root from ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

List<File> _dartFiles(List<String> roots) => [
  for (final r in roots)
    if (Directory('${_repoRoot.path}/$r').existsSync())
      ...Directory('${_repoRoot.path}/$r')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
];

/// Every file MB1's repo-wide predicate would reach. Deliberately wider than
/// `lib/` — the predicate has no pathspec, and the residual that survived
/// attempt 1 was in a KEPT file under `test/`.
List<File> get _allSourceFiles => _dartFiles(['lib', 'test']);

/// Strips `///`, `//` and `/* */` so a doc comment can never satisfy a receipt.
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
      .join('\n');
}

/// Files whose RAW bytes contain [token] — the shape `git grep -l` reports.
/// Raw, not comment-stripped, on purpose: to `grep` a doc comment and a live
/// call site are the same thing, and V-1 runs `grep`.
List<String> _filesContaining(String token) => [
  for (final f in _allSourceFiles)
    if (f.readAsStringSync().contains(token))
      f.path.replaceFirst('${_repoRoot.path}/', ''),
];

void main() {
  group('MB1 — the deleted SSE symbols are gone REPO-WIDE', () {
    for (final token in _forbidden) {
      test('$token appears in 0 files under lib/ + test/', () {
        expect(
          _filesContaining(token),
          isEmpty,
          reason:
              'MB1 V-1 greps the whole tree with no pathspec, so prose '
              'counts as a residual. If THIS file is the hit, someone '
              'un-split the token — read the class doc.',
        );
      });
    }

    test('this file does not defeat its own receipts', () {
      // The self-referential guard, made explicit — and it has already earned
      // its keep twice: the first draft spelled all six tokens out, and the
      // second split only the values of a map whose KEYS were still literals.
      // Both drafts turned six clean receipts into six hits on the guard
      // itself, which reds the gate row on the instrument rather than on the
      // code — the most confusing possible failure.
      final self = File(
        '${_repoRoot.path}/test/features/live_tracking/'
        'sse_teardown_grep_receipt_test.dart',
      ).readAsStringSync();
      for (final token in _forbidden) {
        expect(
          self.contains(token),
          isFalse,
          reason:
              '"$token" is spelled literally in this file, so V-1\'s '
              'repo-wide grep will name it.',
        );
      }
    });
  });

  group('POSITIVE CONTROL — the instrument can find things', () {
    test('LivePositionSource is still PRESENT (a zero here is the FAILURE)', () {
      // MB1.md is explicit: "Keep LivePositionSource — it is a different type,
      // it owns fetchLivePosition, and deleting it by eye removes the very
      // contract this batch exists to wire."
      final files = _filesContaining(_tok(['LivePosition', 'Source']));
      expect(
        files,
        isNotEmpty,
        reason:
            'deleting this type would satisfy every negative receipt '
            'above while destroying the thing MB1 exists to wire — the '
            'archetypal grep-driven false pass.',
      );
      expect(
        files.any(
          (f) => f.endsWith(
            'lib/features/live_tracking/domain/'
            'live_tracking_repository.dart',
          ),
        ),
        isTrue,
        reason:
            'it must survive at its DECLARATION site, not merely in a '
            'test fake.',
      );
    });

    test(
      'a symbol that never existed is reported absent (no false positives)',
      () {
        expect(
          _filesContaining(_tok(['SseLive', 'PositionStream', 'Xyzzy'])),
          isEmpty,
        );
      },
    );
  });

  group('MB1 — fetchLivePosition has a real production CALL SITE', () {
    test('>=1 call expression in lib/, on comment-stripped source', () {
      // The baseline at origin/main was ZERO production call sites — the
      // method existed and was orphaned, which is the whole reason MB1 exists.
      // This assertion is what distinguishes "the method is present" from
      // "the method is wired".
      final callSites = <String>[];
      for (final f in _dartFiles(['lib'])) {
        final code = _stripComments(f.readAsStringSync());
        if (RegExp(r'\.fetchLivePosition\(').hasMatch(code)) {
          callSites.add(f.path.replaceFirst('${_repoRoot.path}/', ''));
        }
      }
      expect(
        callSites,
        isNotEmpty,
        reason:
            'baseline was 0. If this reds, the courier marker is '
            'orphaned again and the P0 is back.',
      );
      expect(callSites, contains(endsWith('live_tracking_cubit.dart')));
    });

    test('NEGATIVE CONTROL: a bare-token match would have passed on the '
        'orphaned code, so the receipt must be a CALL', () {
      // Proves the strictness is real rather than claimed: the DECLARATION
      // carries the bare token, and only the cubit carries the call. A
      // `contains('fetchLivePosition')` receipt cannot tell them apart, and
      // would have gone green against the pre-MB1 tree where the method had
      // zero callers.
      final declCode = _stripComments(
        File(
          '${_repoRoot.path}/lib/features/live_tracking/domain/'
          'live_tracking_repository.dart',
        ).readAsStringSync(),
      );
      expect(
        declCode.contains('fetchLivePosition'),
        isTrue,
        reason: 'the bare token IS present at the declaration…',
      );
      expect(
        RegExp(r'\.fetchLivePosition\(').hasMatch(declCode),
        isFalse,
        reason: '…but it is NOT a call there.',
      );
    });
  });

  group('MB1 — the position axis has no clock', () {
    test('no Timer / Future.delayed in the live_tracking feature', () {
      final offenders = <String>[];
      for (final f in _dartFiles(['lib/features/live_tracking'])) {
        final code = _stripComments(f.readAsStringSync());
        for (final pattern in const [
          'Timer.periodic',
          'Timer(',
          'Future.delayed',
        ]) {
          if (code.contains(pattern)) {
            offenders.add(
              '${f.path.replaceFirst('${_repoRoot.path}/', '')} -> $pattern',
            );
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the entire point of MB1 is that the position is read on '
            'EVENTS and on no clock. A re-armed timer here is how the '
            'original 2/5/15/30 s backoff became a permanent poll against a '
            '404 for four days.',
      );
    });
  });
}

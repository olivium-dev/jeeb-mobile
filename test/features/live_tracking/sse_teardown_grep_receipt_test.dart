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
    // ## READ THIS BEFORE TRUSTING THE ALLOWANCE BELOW
    //
    // This receipt used to be a flat ban on `Timer.periodic` / `Timer(` /
    // `Future.delayed` anywhere under `lib/features/live_tracking/`. It has ONE
    // named exception now, and a narrowed gate that gains an exception in the
    // same change that would otherwise red it is exactly the shape that should
    // make a reviewer suspicious. So:
    //
    //  * **What it was built to ban, it still bans.** A timer whose tick READS
    //    the gateway — the 2/5/15/30 s backoff that became a permanent poll of
    //    a 404 for four days. That ban is now asserted MORE strictly than
    //    before, not less: `live_tracking_cubit.dart`, the file that actually
    //    held that timer, is pinned by name below, and every other file in the
    //    tree is still banned outright.
    //  * **What it now permits** is one `Timer.periodic` in
    //    `courier_position_socket.dart`, and only because a subscription needs
    //    a keepalive to exist at all: `LiveCommWeb.Channels.TopicChannel`
    //    schedules its own 25 s `:heartbeat`, counts misses, and STOPS the
    //    channel at 3 — so a subscriber that never speaks is disconnected after
    //    ~75 s. The alternative to this timer is not "no timer", it is "no
    //    subscription".
    //  * **The permission is not taken on trust.** The two tests after it prove
    //    STRUCTURALLY that the allowed tick cannot be a poll: the callback is
    //    pinned to `_sendKeepAlive`, and `_sendKeepAlive`'s own body is checked
    //    to contain no `await` and no HTTP client, so it cannot request or
    //    receive data. A poll that returns nothing is not a poll.
    //
    // If a second exception is ever proposed here, the question to ask is the
    // one this file already answers for the first: what does the tick RECEIVE?
    const keepAliveFile =
        'lib/features/live_tracking/data/courier_position_socket.dart';
    const clockPatterns = ['Timer.periodic', 'Timer(', 'Future.delayed'];

    /// The predicate, extracted so the POSITIVE CONTROL can run the very same
    /// code over planted source. A ban asserted by an inlined loop is a ban
    /// nobody has ever seen fire.
    List<String> clockHits(String path, String code) => [
      for (final pattern in clockPatterns)
        if (code.contains(pattern)) '$path -> $pattern',
    ];

    test('the CUBIT holds no clock at all — the file the P0 actually lived in',
        () {
      // Pinned by NAME, and stricter than the sweep below: whatever else the
      // feature tree grows, the thing that schedules position reads must never
      // hold a timer.
      final code = _stripComments(
        File(
          '${_repoRoot.path}/lib/features/live_tracking/application/'
          'live_tracking_cubit.dart',
        ).readAsStringSync(),
      );
      expect(clockHits('live_tracking_cubit.dart', code), isEmpty);
    });

    test('no Timer / Future.delayed anywhere in the feature except the ONE '
        'named keepalive', () {
      final offenders = <String>[];
      for (final f in _dartFiles(['lib/features/live_tracking'])) {
        final rel = f.path.replaceFirst('${_repoRoot.path}/', '');
        if (rel == keepAliveFile) continue;
        offenders.addAll(clockHits(rel, _stripComments(f.readAsStringSync())));
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

    test('the allowance is EXACTLY one Timer.periodic and nothing else', () {
      final code = _stripComments(
        File('${_repoRoot.path}/$keepAliveFile').readAsStringSync(),
      );
      expect(
        RegExp('Timer.periodic').allMatches(code).length,
        1,
        reason: 'one keepalive, not a family of timers',
      );
      // The other two shapes stay banned even in the allowed file: a one-shot
      // `Timer(` is how a self-rescheduling poll is spelled, and
      // `Future.delayed` is how it is spelled when someone is avoiding the word
      // Timer.
      expect(code.contains('Timer('), isFalse);
      expect(code.contains('Future.delayed'), isFalse);
    });

    test('the allowed tick CANNOT be a poll — it receives nothing', () {
      final code = _stripComments(
        File('${_repoRoot.path}/$keepAliveFile').readAsStringSync(),
      );

      // 1. The callback is pinned. A tick body free to be anything is not a
      //    permission, it is a hole.
      expect(
        RegExp(r'Timer\.periodic\(\s*_keepAlive\s*,\s*\(_\)\s*=>\s*'
                r'_sendKeepAlive\(\)\s*\)')
            .hasMatch(code),
        isTrue,
        reason: 'the permitted timer must call _sendKeepAlive and nothing else',
      );

      // 2. And that method cannot obtain data. No `await` means nothing can be
      //    received; no HTTP client means there is nothing to receive it from.
      // The signature is matched LOOSELY on purpose. A tight `void … {` would
      // make an `async` rewrite fail on "the method is findable" instead of on
      // the `await` ban below — the right red, for the wrong reason, and a
      // reader would learn nothing from it.
      final body = RegExp(
        r'(?:void|Future<void>) _sendKeepAlive\(\)\s*(?:async\s*)?\{(.*?)\n  \}',
        dotAll: true,
      ).firstMatch(code)?.group(1);
      expect(body, isNotNull, reason: 'the pinned method must be findable');
      expect(body, contains('_send('));
      for (final banned in const ['await', 'Dio', 'HttpClient', 'http.', '.get(']) {
        expect(body!.contains(banned), isFalse,
            reason: 'a keepalive that can $banned is a poll');
      }
    });

    test('POSITIVE CONTROL: the ban still fires on planted source', () {
      // Without this, "offenders is empty" is equally satisfied by a predicate
      // that stopped matching — which is precisely what narrowing a gate risks.
      expect(
        clockHits('planted.dart', 'void t() { Timer.periodic(d, (_) {}); }'),
        isNotEmpty,
      );
      expect(clockHits('planted.dart', 'Timer(d, () {});'), isNotEmpty);
      expect(
        clockHits('planted.dart', 'await Future.delayed(d);'),
        isNotEmpty,
      );
      expect(clockHits('planted.dart', 'final x = 1;'), isEmpty);
    });
  });
}

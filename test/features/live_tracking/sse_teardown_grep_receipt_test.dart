// MB1 W1.1 — GREP RECEIPT for the SSE teardown.
//
// The customer-facing P0 this batch kills was not a bug in a line of code; it
// was a whole SUBSYSTEM pointed at a route the gateway had deleted. So the
// acceptance condition is a set of ABSENCES, and an absence needs a standing
// instrument or it silently comes back. Five tokens are banned (each assembled
// below rather than written out — see "Why the tokens are assembled"):
//
//   * the gateway's SSE position alias under `/v1/geo/` — deleted server-side.
//     `LocationController.cs:22-31` is explicit: the `Accept: text/event-stream`
//     arm was a 5 s server-side re-read loop and "is deleted, along with the …
//     alias that existed only to open it". Any client reference is a dead GET.
//   * the streaming capability interface, its Dio consumer class, and its
//     `watch`-shaped read method — the consumer stack built on that route.
//   * the re-arm backoff constant. This is the part that turned a dead route
//     into a LOOP: the attempt counter reset only inside the frame handler of a
//     stream that could never deliver a frame, so it parked at its 30 s steady
//     state and re-issued the dead GET for the life of the screen.
//
// Counted at `jeeb-mobile` origin/main = 30d12f1a2023db8a98e4af40a0627897ede8c577,
// i.e. the state this guard had to move off (`git grep`, whole repo):
//
//     the /v1/geo/ alias      3 hits / 2 files  (2 code + 1 doc comment)
//     the backoff constant    7 hits / 3 files  (4 code + 3 doc comments,
//                                                3 of them outside live_tracking/)
//     the SSE consumer class  code + 2 test files
//
// WHY THE TOKENS ARE ASSEMBLED FROM FRAGMENTS. A guard normally names what it
// forbids — that is how the gateway's `.50` ban gate is built, and its own hits
// are allowlisted as "inert by construction". That option is deliberately NOT
// taken here, because MB1's verifier contract is a COUNT: `git grep` for the
// dead tokens must return 0. If this file spelled them out, a verifier running
// the contract verbatim would get a non-zero count off the very file that
// proves the count is zero, and would have to decide whether that is a finding.
// Assembling the literals at runtime removes the ambiguity entirely: the tokens
// exist as data, never as a contiguous string in any source file, so the
// contract's 0 is a real 0 and this guard still detects every reintroduction.
// The NEG control below is what proves the assembly did not defang it.
//
// GUARD PROOF — run by the writer before commit, both directions:
//   NEG: append the two literals to demo_live_tracking_repository.dart
//        -> FAIL, naming `demo_live_tracking_repository.dart:44` for BOTH.
//   POS: restore -> 3/3 pass. Plus the third test below, which asserts the
//        REPLACEMENT is present and wired — "zero stream references" alone
//        would be satisfied just as well by deleting the feature outright.
//
// COMMENTS ARE NOT EXEMPT here, unlike the identity guard next door. The whole
// point of MB1's doc-comment cleanups is that a repo-wide grep reaches ZERO — a
// verifier greps the tree, not the AST, and a stale doc comment naming a deleted
// route is indistinguishable from a live caller. Three of the four stale
// comments MB1 names sat OUTSIDE lib/features/live_tracking/ entirely, which is
// exactly why a feature-scoped sweep missed them.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The banned SSE route alias, assembled so the literal appears nowhere.
const String _aliasToken = '/v1/geo/jeeb/' 'stream/';

/// The banned re-arm backoff constant.
const String _backoffToken = 'kPositionRearm' 'Backoff';

/// The banned consumer class.
const String _consumerToken = 'SseLivePosition' 'Stream';

/// The banned streaming capability interface.
const String _streamSourceToken = 'LivePositionStream' 'Source';

/// The banned streaming read method.
const String _watchToken = 'watchLive' 'Position';

/// Every token that must not survive W1.1, with the reason it was deleted.
final Map<String, String> _bannedTokens = <String, String>{
  _aliasToken: 'gateway route DELETED (LocationController.cs:22-31) — any '
      'reference is a request that can only 404',
  _consumerToken: 'the consumer of that deleted route; the file is gone',
  _streamSourceToken:
      'the streaming capability interface; only LivePositionSource remains',
  _backoffToken:
      'the re-arm schedule that turned a dead route into a permanent loop',
  _watchToken:
      'the streaming read; the snapshot read is fetchLivePosition',
};

/// The only file allowed to hold the banned tokens — it holds them as assembled
/// data, not as source literals, so even here `git grep` finds nothing.
const String _selfPath = 'sse_teardown_grep_receipt_test.dart';

Iterable<File> _dartFilesUnder(String dir) sync* {
  final root = Directory(dir);
  if (!root.existsSync()) return;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

void main() {
  test('lib/** and test/** carry ZERO references to the deleted SSE stack', () {
    expect(Directory('lib').existsSync(), isTrue,
        reason: 'this test must run from the package root');

    final offenders = <String>[];
    var filesScanned = 0;

    for (final dir in const ['lib', 'test']) {
      for (final file in _dartFilesUnder(dir)) {
        if (file.path.endsWith(_selfPath)) continue;
        filesScanned++;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final entry in _bannedTokens.entries) {
            if (lines[i].contains(entry.key)) {
              offenders.add('${file.path}:${i + 1}  [${entry.key}] '
                  '— ${entry.value}');
            }
          }
        }
      }
    }

    // A scanner that reached no files would report a triumphant zero. Assert the
    // denominator, exactly as every recorder claim in this programme must.
    expect(filesScanned, greaterThan(500),
        reason: 'the scan must actually have read the tree');

    expect(
      offenders,
      isEmpty,
      reason: 'MB1 W1.1 deleted the SSE position stack. These references point '
          'at a route the gateway removed, or at symbols that no longer '
          'exist:\n${offenders.join('\n')}',
    );
  });

  test('the deleted files are actually gone', () {
    const gone = <String>[
      'lib/features/live_tracking/data/sse_live_position_stream.dart',
      'test/features/live_tracking/sse_live_position_stream_test.dart',
      'test/features/live_tracking/tracking_sse_rearm_regression_test.dart',
    ];
    for (final path in gone) {
      expect(File(path).existsSync(), isFalse, reason: '$path must be deleted');
    }
  });

  test('the LIVE tracking route is still referenced, and by a real caller', () {
    // The counterpart POSITIVE control. "Zero stream references" is worthless on
    // its own — a feature deleted outright would satisfy it just as well. What
    // makes the absence a measurement is that the replacement is present AND
    // wired.
    final repo = File(
      'lib/features/live_tracking/data/dio_live_tracking_repository.dart',
    ).readAsStringSync();
    expect(repo.contains("'/deliveries/\$deliveryId/tracking'"), isTrue,
        reason: 'the one-shot snapshot route the gateway still serves '
            '(LocationController.cs:227)');

    final cubit = File(
      'lib/features/live_tracking/application/live_tracking_cubit.dart',
    ).readAsStringSync();
    expect(cubit.contains('fetchLivePosition'), isTrue,
        reason: 'fetchLivePosition had ZERO non-test callers at origin/main — '
            'the fix was already written and orphaned. If this ever goes back '
            'to zero the marker is frozen again.');
  });
}

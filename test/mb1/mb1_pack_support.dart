// MB1 TEST PACK — shared support.
//
// Authored by the MB1 TEST AUTHOR, who did not write the code under test. This
// file holds only helpers; every assertion lives in an `m<N>_*_test.dart`
// sibling so each member item reds on its own (GATE.md §8: "a pack that goes
// red as one lump cannot tell the verifiers which item broke").
//
// ---------------------------------------------------------------------------
// WHY THE BANNED TOKENS ARE ASSEMBLED FROM FRAGMENTS
// ---------------------------------------------------------------------------
// MB1's V-1 contract is a COUNT: `git grep <dead token>` must return 0, repo
// wide. A guard that spelled its tokens out would hand a verifier running that
// contract verbatim a non-zero result off the very files that prove the count
// is zero. So every banned literal below is built at runtime from two adjacent
// string fragments: the token exists as DATA and never as a contiguous run of
// bytes in any source file, so `git grep` still returns a real 0 while the
// scanner still detects every reintroduction.
//
// This deliberately breaks the convention used by the gateway's `.50` ban gate
// (which names what it forbids and allowlists its own hits). The NEG controls
// in `tool/mb1/neg-controls.sh` are what prove the assembly did not defang the
// guard — without them, "assembled tokens" would be indistinguishable from
// "tokens that match nothing".
//
// ---------------------------------------------------------------------------
// EVERY ABSENCE CLAIM HERE CARRIES A POSITIVE CONTROL
// ---------------------------------------------------------------------------
// "0 hits" on its own is worthless: a scanner that read no files, or a token
// that matches nothing anywhere, reports the same triumphant zero. So each
// receipt is paired with [gitGrepCount] run against [kPreFixBase] — the same
// token, the same matcher, against the tree the fix moved OFF. A token that
// cannot be found even at the pre-fix base is a broken matcher, not a clean
// tree, and the pack says so.

import 'dart:io';

/// `jeeb-mobile` `origin/main` at the moment MB1's branch was cut — the tree
/// every "this is gone now" claim is measured against.
///
/// Verified: `git merge-base --is-ancestor 30d12f1a… HEAD` → exit 0.
const String kPreFixBase = '30d12f1a2023db8a98e4af40a0627897ede8c577';

/// One symbol/route MB1 W1.1 deleted, plus the counted state it was deleted
/// from. `beforeHits`/`beforeFiles` are `git grep -c -F` sums over the WHOLE
/// tracked tree at [kPreFixBase], counted first-hand by the test author on
/// 2026-07-31 — they are documentation of the starting point, while the live
/// assertion is [gitGrepCount] > 0 at the base and == 0 today.
class BannedToken {
  const BannedToken({
    required this.token,
    required this.label,
    required this.beforeHits,
    required this.beforeFiles,
    required this.why,
  });

  /// The assembled literal. Never appears contiguously in any source file.
  final String token;

  /// Human name used in the test description, so a red names the symbol.
  final String label;

  /// `git grep -c -F <token> 30d12f1…` summed, whole repo.
  final int beforeHits;

  /// Distinct files in that same count.
  final int beforeFiles;

  /// Why its survival is a defect, not a style nit.
  final String why;
}

/// The five tokens W1.1 had to remove. Order is stable so a runner can address
/// them positionally.
const List<BannedToken> kBannedTokens = <BannedToken>[
  BannedToken(
    token: '/v1/geo/jeeb/' 'stream/',
    label: 'the deleted SSE route alias',
    beforeHits: 6,
    beforeFiles: 4,
    why: 'the gateway DELETED this route (LocationController.cs:22-31) 16 h '
        'after the mobile consumer landed. Any surviving reference is a GET '
        'that can only 404.',
  ),
  BannedToken(
    token: 'SseLivePosition' 'Stream',
    label: 'the SSE consumer class',
    beforeHits: 19,
    beforeFiles: 7,
    why: 'the Dio consumer of that deleted route; its file is gone.',
  ),
  BannedToken(
    token: 'LivePositionStream' 'Source',
    label: 'the streaming capability interface',
    beforeHits: 14,
    beforeFiles: 7,
    why: 'the streaming sibling of LivePositionSource. Only the one-shot '
        'snapshot capability may remain — a second capability is how the '
        'stream path would come back.',
  ),
  BannedToken(
    token: 'watchLive' 'Position',
    label: 'the streaming read method',
    beforeHits: 15,
    beforeFiles: 8,
    why: 'the `watch`-shaped read. The snapshot read is fetchLivePosition; a '
        'surviving watch-shaped read is a held connection by another name.',
  ),
  BannedToken(
    token: 'kPositionRearm' 'Backoff',
    label: 'the re-arm backoff constant',
    beforeHits: 7,
    beforeFiles: 3,
    why: 'THE loop. Its attempt counter reset only inside the frame handler of '
        'a stream that could never deliver a frame, so it parked at its 30 s '
        'steady state and re-issued the dead GET for the life of the screen. '
        '3 of its 7 hits sat OUTSIDE lib/features/live_tracking/, which is how '
        'a feature-scoped sweep missed them.',
  ),
];

/// Every `.dart` file under [dirs], on disk, as (path, lines) pairs.
///
/// Scans the working tree rather than `git grep` on purpose: a verifier's
/// clean clone and this pack must agree, and an untracked reintroduction is
/// still a reintroduction.
List<MapEntry<String, List<String>>> dartSources(List<String> dirs) {
  final out = <MapEntry<String, List<String>>>[];
  for (final dir in dirs) {
    final root = Directory(dir);
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      out.add(MapEntry(entity.path, entity.readAsLinesSync()));
    }
  }
  return out;
}

/// `path:line  text` for every line under [dirs] containing [token].
List<String> occurrences(String token, {List<String> dirs = const ['lib', 'test']}) {
  final hits = <String>[];
  for (final file in dartSources(dirs)) {
    for (var i = 0; i < file.value.length; i++) {
      if (file.value[i].contains(token)) {
        hits.add('${file.key}:${i + 1}  ${file.value[i].trim()}');
      }
    }
  }
  return hits;
}

/// `path:line  text` for every line of the single file [path] containing
/// [token].
///
/// Deliberately separate from [occurrences]: that one takes DIRECTORIES, and
/// handing it a file path silently scans nothing and returns a triumphant empty
/// list. This variant throws when the file is missing, so a typo reds instead
/// of passing.
List<String> occurrencesInFile(String token, String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('MB1 pack: cannot scan missing file $path');
  }
  final lines = file.readAsLinesSync();
  final hits = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains(token)) hits.add('$path:${i + 1}  ${lines[i].trim()}');
  }
  return hits;
}

/// Whether `git` is usable here at all. An absence claim whose positive
/// control could not run is UNVERIFIABLE, and this programme treats
/// unverifiable as rejected (GATE.md §6.3 `L3`) rather than as passed.
bool get gitAvailable {
  try {
    return Process.runSync('git', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Total `git grep -F` hit count for [token] at [ref], whole tree.
///
/// Returns -1 when git could not answer at all (missing binary, missing ref),
/// which callers must treat as a failure rather than as a zero.
int gitGrepCount(String token, {required String ref, List<String> paths = const []}) {
  if (!gitAvailable) return -1;
  final probe = Process.runSync('git', ['cat-file', '-e', '$ref^{commit}']);
  if (probe.exitCode != 0) return -1;
  final res = Process.runSync(
    'git',
    ['grep', '-c', '-F', '--', token, ref, if (paths.isNotEmpty) '--', ...paths],
  );
  // `git grep -c` prints per-FILE counts and, on zero matches, prints nothing
  // and exits 1. (This exact shape is a recorded unsatisfiable-contract defect
  // elsewhere in this programme — see OWNER-DECISIONS.md, GW1 V-1.) So sum the
  // per-file counts; no output means zero, which is a legitimate answer here
  // and is distinguished from -1 "could not ask".
  if (res.exitCode != 0 && (res.stdout as String).trim().isEmpty) return 0;
  var total = 0;
  for (final line in (res.stdout as String).trim().split('\n')) {
    if (line.isEmpty) continue;
    final idx = line.lastIndexOf(':');
    if (idx < 0) continue;
    total += int.tryParse(line.substring(idx + 1)) ?? 0;
  }
  return total;
}

/// The file's content at [ref], or null when git cannot produce it.
String? gitShow(String path, {required String ref}) {
  if (!gitAvailable) return null;
  final res = Process.runSync('git', ['show', '$ref:$path']);
  if (res.exitCode != 0) return null;
  return res.stdout as String;
}

/// Reads a working-tree file, failing loudly rather than returning ''.
String readSource(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    throw StateError('MB1 pack: expected source file missing: $path '
        '(run from the jeeb-mobile package root)');
  }
  return f.readAsStringSync();
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Shared source-reading lens for the MB1 pack.
///
/// Every MB1 receipt that talks about "what the tree contains" goes through
/// here, for three reasons that each cost this programme a wrong answer at
/// least once:
///
/// 1. **`git grep` skips untracked files.** A receipt verified before `git add`
///    returns a clean answer that flips the moment the file is staged. So the
///    repo-wide lens is [trackedFiles], which asks **git** what is tracked
///    rather than walking the filesystem — the same population V-1's `git grep`
///    sees, no more and no less.
/// 2. **A doc comment and a live call site are the same thing to `grep`.** Any
///    receipt about *behaviour* must run on [stripComments]-ed source; any
///    receipt about *residual prose* must run on RAW bytes. Mixing the two is
///    how `contains('fetchLivePosition')` stayed green on a tree where the
///    method had zero callers.
/// 3. **A test file that spells a forbidden token IS a repo-wide hit.** This
///    library therefore contains **no** forbidden literal of its own; callers
///    assemble theirs at runtime with [tok].
///
/// This file is intentionally not a `_test.dart`, so `flutter test` never picks
/// it up as a suite of its own.
abstract final class MB1Source {
  /// Repo root, found by walking up to `pubspec.yaml` so the receipts work from
  /// any cwd (the harness runs from the package root; a verifier may not).
  static Directory get repoRoot {
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

  /// Joins fragments into a token at runtime.
  ///
  /// Neither obvious spelling survives `dart analyze`, and the two lints
  /// contradict each other here: adjacent strings in a list literal raise
  /// `no_adjacent_strings_in_list` ("try adding a comma"), and `'a' + 'b'`
  /// raises `prefer_adjacent_string_concatenation` ("try removing the
  /// operator"). **Both suggested fixes reassemble the literal and red V-1's
  /// repo-wide grep.** A join is the one form neither lint objects to.
  static String tok(List<String> fragments) => fragments.join();

  /// Strips `///`, `//` and `/* */`, so prose can never satisfy a behavioural
  /// receipt.
  ///
  /// Deliberately naive: it does not understand a `//` inside a string literal.
  /// For a "does this CALL exist" receipt that is the safe direction —
  /// over-stripping can only make the assertion harder to satisfy.
  ///
  /// **It is the UNSAFE direction for any receipt about a URL, and that is not
  /// hypothetical.** `'http://192.168.2.50:10090'` strips to `'http:` — the
  /// `//` of the scheme is read as a line comment — so a `.50`-ban assertion
  /// run over stripped source is BLIND to exactly the string it forbids. That
  /// bug shipped in the first draft of `mb1_w1_4_build_line_test.dart` and was
  /// caught only because the negative control refused to go red.
  ///
  /// Rule: **host/URL receipts read [raw], never this.**
  static String stripComments(String src) {
    final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    return noBlock
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');
  }

  /// Raw bytes of a repo-relative path. Fails loudly rather than returning `''`
  /// — a missing file that reads as an empty string satisfies every "token is
  /// absent" assertion, which is the silent-wrong-answer shape this pack is
  /// written against.
  static String raw(String repoRelativePath) {
    final f = File('${repoRoot.path}/$repoRelativePath');
    if (!f.existsSync()) fail('MB1 receipt targets a missing file: $repoRelativePath');
    return f.readAsStringSync();
  }

  /// [raw], comment-stripped.
  static String strippedLib(String repoRelativePath) =>
      stripComments(raw(repoRelativePath));

  /// Every file `git grep` would search — i.e. every TRACKED file, whatever its
  /// extension. Wider than `lib/` + `test/` on purpose: MB1's V-1 predicate has
  /// no pathspec, and a residual in a `.md`, a `.json` or an `.xml` counts.
  ///
  /// Returns repo-relative paths. Fails if git is unavailable or reports
  /// nothing — an empty population would make every absence assertion pass
  /// vacuously, which is exactly the failure `GATE.md` §7 calls "a 403 with no
  /// matching 200".
  static List<String> trackedFiles() {
    final r = Process.runSync(
      'git',
      <String>['ls-files', '-z'],
      workingDirectory: repoRoot.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (r.exitCode != 0) {
      fail('git ls-files failed (exit ${r.exitCode}): ${r.stderr}');
    }
    // `-z` is NUL-separated on purpose. Newline-separated output QUOTES any
    // path containing a space or a newline, and a quoted path does not exist
    // on disk — it would be silently skipped, and a skipped file trivially
    // "contains no forbidden token". The separator is written as an ESCAPE,
    // not as a raw byte: a literal NUL in a source file makes git classify
    // that file as binary and stop grepping it, which would quietly exempt
    // this lens from the very predicate it implements.
    final paths = (r.stdout as String)
        .split('\u0000')
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      fail('git ls-files returned 0 files — the lens is blind, not the tree clean');
    }
    return paths;
  }

  /// Tracked files whose RAW bytes contain [token]. Undecodable (binary) files
  /// are skipped and reported through [skipped] so a caller can prove the skip
  /// list did not swallow the answer.
  static List<String> trackedFilesContaining(
    String token, {
    List<String>? skipped,
  }) {
    final hits = <String>[];
    for (final rel in trackedFiles()) {
      final f = File('${repoRoot.path}/$rel');
      if (!f.existsSync()) continue; // deleted-but-staged; git grep would skip it too
      String content;
      try {
        content = f.readAsStringSync();
      } catch (_) {
        skipped?.add(rel);
        continue;
      }
      if (content.contains(token)) hits.add(rel);
    }
    return hits;
  }

  /// Dart files under the given repo-relative roots.
  static List<File> dartFilesUnder(List<String> roots) => <File>[
    for (final r in roots)
      if (Directory('${repoRoot.path}/$r').existsSync())
        ...Directory('${repoRoot.path}/$r')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
  ];

  /// Repo-relative form of an absolute path produced by [dartFilesUnder].
  static String rel(File f) => f.path.replaceFirst('${repoRoot.path}/', '');
}

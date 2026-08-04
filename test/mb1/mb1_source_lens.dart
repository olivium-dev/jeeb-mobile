import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Shared source-reading lens for the MB1 pack.
/// Every MB1 receipt that talks about "what the tree contains" goes through
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
  /// Neither obvious spelling survives `dart analyze`, and the two lints
  static String tok(List<String> fragments) => fragments.join();

  /// Strips `///`, `//` and `/* */`, so prose can never satisfy a behavioural
  /// receipt.
  static String stripComments(String src) {
    final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    return noBlock
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');
  }

  /// Raw bytes of a repo-relative path. Fails loudly rather than returning `''`
  /// — a missing file that reads as an empty string satisfies every "token is
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

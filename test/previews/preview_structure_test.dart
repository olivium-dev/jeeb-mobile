// Structural guardrails for the widget-preview rollout.
//
// Two invariants, both cheap enough to run on every CI job:
//
//   1. PREVIEWS NEVER LEAK INTO PRODUCTION. Nothing outside `lib/previews/`
//      may import from it. Previews exist to be compiled by the preview
//      scaffold and tree-shaken out of the app; the moment production code
//      imports one, that stops being true and a dev-only fixture is shipping
//      to users.
//
//   2. COVERAGE ONLY GOES UP. The rollout adds previews area by area over many
//      PRs. Without a ratchet, a deleted or renamed preview silently reduces
//      coverage and nobody notices until someone opens the canvas.
//
// Update `_coverageFloor` DOWNWARD as areas land. It is never raised.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Maximum number of uncovered widgets allowed. Lower this as waves land —
/// never raise it.
const int _coverageFloor = 119;

final RegExp _widgetClass = RegExp(
  r'^class ([A-Z][A-Za-z0-9_]*) extends (?:StatelessWidget|StatefulWidget)',
  multiLine: true,
);

/// Must stay in sync with `tool/preview_coverage.dart`. Scope decisions about
/// what the rollout is for (product UI), not judgements about difficulty.
const List<String> _excludedPrefixes = <String>[
  'lib/previews/',
  'lib/devtool/',
  'lib/l10n/',
  'lib/core/observability/', // dev-only overlay, compiled out via kObsCompiledIn
];

/// Widgets deliberately excluded from coverage — see
/// `tool/preview_exclusions.txt` for the rule and the reasons.
Set<String> _exclusions() {
  final file = File('tool/preview_exclusions.txt');
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .map((String l) => l.split('#').first.trim())
      .where((String l) => l.isNotEmpty)
      .toSet();
}

List<File> _dartFilesUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return <File>[];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
}

String _rel(String path) =>
    path.replaceFirst('${Directory.current.path}${Platform.pathSeparator}', '');

/// `ChatMessageBubble` -> `chat_message_bubble`. Must match the same helper in
/// `tool/preview_coverage.dart`.
String _snake(String pascal) => pascal
    .replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (Match m) => '_${m.group(1)}',
    )
    .toLowerCase();

void main() {
  test('no production code imports lib/previews/', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final path = _rel(file.path);
      if (path.startsWith('lib/previews/')) continue;
      final source = file.readAsStringSync();
      if (source.contains('previews/harness/') ||
          source.contains("package:jeeb_mobile/previews/") ||
          RegExp(r"import '[^']*\/previews\/").hasMatch(source)) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These production files import preview-only code, which would '
          'ship dev fixtures to users:\n${offenders.join('\n')}',
    );
  });

  test('preview coverage does not regress', () {
    final excluded = _exclusions();
    final all = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final path = _rel(file.path);
      if (_excludedPrefixes.any(path.startsWith)) continue;
      for (final m in _widgetClass.allMatches(file.readAsStringSync())) {
        final name = m.group(1)!;
        if (name.endsWith('Screen')) continue;
        if (excluded.contains(name)) continue;
        all.add(name);
      }
    }

    // Covered == owns `lib/previews/<area>/<snake>_preview.dart`. A mere mention
    // inside a sibling's preview does NOT count — that once inflated coverage by
    // five widgets that had no preview of their own.
    // Skip `harness/`: `jeeb_preview.dart` ends in `_preview.dart` and would
    // falsely cover a widget named `Jeeb`.
    final previewFiles = _dartFilesUnder('lib/previews')
        .where((File f) => !_rel(f.path).startsWith('lib/previews/harness/'))
        .map((File f) => f.uri.pathSegments.last)
        .where((String n) => n.endsWith('_preview.dart'))
        .toSet();
    final uncovered = all
        .where((String n) => !previewFiles.contains('${_snake(n)}_preview.dart'))
        .toList();

    expect(
      uncovered.length,
      lessThanOrEqualTo(_coverageFloor),
      reason: 'Preview coverage regressed: ${uncovered.length} widgets have no '
          'preview but the floor is $_coverageFloor. Either add the missing '
          'preview or lower the floor if widgets were deleted.\n'
          'Run: dart run tool/preview_coverage.dart',
    );
  });
}

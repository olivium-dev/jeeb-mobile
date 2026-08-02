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
const int _coverageFloor = 167;

final RegExp _widgetClass = RegExp(
  r'^class ([A-Z][A-Za-z0-9_]*) extends (?:StatelessWidget|StatefulWidget)',
  multiLine: true,
);

const List<String> _excludedPrefixes = <String>[
  'lib/previews/',
  'lib/devtool/',
  'lib/l10n/',
];

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
    final all = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final path = _rel(file.path);
      if (_excludedPrefixes.any(path.startsWith)) continue;
      for (final m in _widgetClass.allMatches(file.readAsStringSync())) {
        final name = m.group(1)!;
        if (name.endsWith('Screen')) continue;
        all.add(name);
      }
    }

    final previewText = _dartFilesUnder('lib/previews')
        .map((File f) => f.readAsStringSync())
        .join('\n');
    final uncovered = all
        .where((String n) => !RegExp('\\b$n\\b').hasMatch(previewText))
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

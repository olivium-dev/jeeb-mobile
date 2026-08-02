// Preview-coverage inventory.
//
//   dart run tool/preview_coverage.dart           # human summary
//   dart run tool/preview_coverage.dart --json    # machine-readable work queue
//   dart run tool/preview_coverage.dart --area chat
//
// A widget counts as COVERED when its class name appears anywhere under
// `lib/previews/`. That is deliberately a text-level check rather than an
// analyzer pass: it costs milliseconds, has no package dependency, and cannot
// itself break the build. The rollout's real correctness gate is the per-area
// render test, not this script — this only answers "what is left".
//
// Screens are out of scope: they are already covered by the on-device Screen
// Catalog (`lib/devtool/catalog/`), which carries 270 mocked states.

import 'dart:convert';
import 'dart:io';

/// Directories that hold no previewable production widgets.
const List<String> _excludedPrefixes = <String>[
  'lib/previews/', // the previews themselves
  'lib/devtool/', // dev-only catalog + shell
  'lib/l10n/', // generated localizations
];

final RegExp _widgetClass = RegExp(
  r'^class ([A-Z][A-Za-z0-9_]*) extends (?:StatelessWidget|StatefulWidget)',
  multiLine: true,
);

class WidgetRef {
  WidgetRef(this.name, this.path);
  final String name;
  final String path;

  /// Feature folder the widget belongs to — the preview's destination area
  /// under `lib/previews/`.
  String get area {
    final feature = RegExp(r'^lib/features/([^/]+)/').firstMatch(path);
    if (feature != null) return feature.group(1)!;
    if (path.startsWith('lib/core/')) return 'core';
    if (path.startsWith('lib/app/')) return 'app';
    return 'misc';
  }

  /// Conventional preview file for this widget.
  String get previewPath => 'lib/previews/$area/${_snake(name)}_preview.dart';

  Map<String, Object?> toJson() => <String, Object?>{
        'widget': name,
        'source': path,
        'area': area,
        'previewPath': previewPath,
      };
}

String _snake(String pascal) => pascal
    .replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (Match m) => '_${m.group(1)}',
    )
    .toLowerCase();

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

void main(List<String> args) {
  final wantJson = args.contains('--json');
  final areaIndex = args.indexOf('--area');
  final areaFilter =
      areaIndex >= 0 && areaIndex + 1 < args.length ? args[areaIndex + 1] : null;

  // 1. Every public, non-screen widget in production code.
  final all = <WidgetRef>[];
  for (final file in _dartFilesUnder('lib')) {
    final path = _rel(file.path);
    if (_excludedPrefixes.any(path.startsWith)) continue;
    for (final m in _widgetClass.allMatches(file.readAsStringSync())) {
      final name = m.group(1)!;
      if (name.endsWith('Screen')) continue; // owned by the Screen Catalog
      all.add(WidgetRef(name, path));
    }
  }

  // 2. Everything named anywhere under lib/previews/.
  final previewSource = StringBuffer();
  for (final file in _dartFilesUnder('lib/previews')) {
    previewSource.writeln(file.readAsStringSync());
  }
  final previewText = previewSource.toString();
  final covered = <WidgetRef>[];
  final uncovered = <WidgetRef>[];
  for (final w in all) {
    (RegExp('\\b${w.name}\\b').hasMatch(previewText) ? covered : uncovered)
        .add(w);
  }

  final queue = areaFilter == null
      ? uncovered
      : uncovered.where((WidgetRef w) => w.area == areaFilter).toList();

  if (wantJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'total': all.length,
        'covered': covered.length,
        'uncovered': uncovered.length,
        'queue': queue.map((WidgetRef w) => w.toJson()).toList(),
      }),
    );
    return;
  }

  // Human summary, grouped by area so waves are obvious.
  final byArea = <String, List<WidgetRef>>{};
  for (final w in queue) {
    byArea.putIfAbsent(w.area, () => <WidgetRef>[]).add(w);
  }
  final areas = byArea.keys.toList()
    ..sort((String a, String b) => byArea[b]!.length.compareTo(byArea[a]!.length));

  stdout.writeln('Preview coverage: ${covered.length}/${all.length} '
      '(${(covered.length / all.length * 100).toStringAsFixed(1)}%)');
  stdout.writeln('Remaining: ${uncovered.length}\n');
  for (final area in areas) {
    stdout.writeln('${area.padRight(28)} ${byArea[area]!.length}');
    for (final w in byArea[area]!) {
      stdout.writeln('  ${w.name.padRight(38)} ${w.path}');
    }
  }
}

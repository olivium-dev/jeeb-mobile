// Preview-coverage inventory.
//
//   dart run tool/preview_coverage.dart           # human summary
//   dart run tool/preview_coverage.dart --json    # machine-readable work queue
//   dart run tool/preview_coverage.dart --area chat
//
// A widget counts as COVERED when it OWNS a preview file at the conventional
// path — `lib/previews/<area>/<snake_name>_preview.dart`.
//
// An earlier version asked "does this class name appear anywhere under
// lib/previews/", which silently counted five widgets as covered because a
// sibling's preview happened to mention them in a doc comment. Owning a file is
// unambiguous and cannot be earned by a passing reference. A widget that is only
// ever rendered inside a parent still needs its own file — give it one preview
// showing it in isolation, which is the point.
//
// Screens are out of scope: they are already covered by the on-device Screen
// Catalog (`lib/devtool/catalog/`), which carries 270 mocked states.

import 'dart:convert';
import 'dart:io';

/// Directories that hold no previewable PRODUCT widgets.
///
/// These are scope decisions about what the rollout is for — product UI — not
/// judgements about difficulty. A widget inside one of these paths is out of
/// scope however easy it would be to preview.
const List<String> _excludedPrefixes = <String>[
  'lib/previews/', // the previews themselves
  'lib/devtool/', // dev-only catalog + shell
  'lib/l10n/', // generated localizations
  // Dev-only session-trace overlay. `kObsCompiledIn` is
  // `kDevToolEnabled && bool.fromEnvironment('JEEB_OBS_OVERLAY')`
  // (observability_config.dart:32), so this whole tree is compiled OUT of every
  // non-devtool build — the same category as `lib/devtool/` above, and excluded
  // for the same reason. See docs/previews/WAVE03_FINDINGS.md for the seams that
  // would have to be added if it is ever brought back into scope.
  'lib/core/observability/',
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

void main(List<String> args) {
  final wantJson = args.contains('--json');
  final areaIndex = args.indexOf('--area');
  final areaFilter =
      areaIndex >= 0 && areaIndex + 1 < args.length ? args[areaIndex + 1] : null;

  // 1. Every public, non-screen widget in production code.
  final excluded = _exclusions();
  final all = <WidgetRef>[];
  for (final file in _dartFilesUnder('lib')) {
    final path = _rel(file.path);
    if (_excludedPrefixes.any(path.startsWith)) continue;
    for (final m in _widgetClass.allMatches(file.readAsStringSync())) {
      final name = m.group(1)!;
      if (name.endsWith('Screen')) continue; // owned by the Screen Catalog
      if (excluded.contains(name)) continue;
      all.add(WidgetRef(name, path));
    }
  }

  // 2. Every preview file that exists, by basename.
  final previewFiles = _dartFilesUnder('lib/previews')
      .map((File f) => f.uri.pathSegments.last)
      .where((String n) => n.endsWith('_preview.dart'))
      .toSet();

  final covered = <WidgetRef>[];
  final uncovered = <WidgetRef>[];
  for (final w in all) {
    (previewFiles.contains('${_snake(w.name)}_preview.dart')
            ? covered
            : uncovered)
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

// Preview-coverage inventory.
//
//   dart run tool/preview_coverage.dart           # human summary
//   dart run tool/preview_coverage.dart --json    # machine-readable work queue
//   dart run tool/preview_coverage.dart --area chat
//
// A widget counts as COVERED when its OWN source file carries a preview
// section that (a) declares at least one `@JeebPreview` function named after
// the widget and (b) actually constructs it. Both, not either.
//
// The rule has been wrong twice before, in opposite directions:
//
//   "the class name appears somewhere under lib/previews/" counted five widgets
//   as covered because a sibling's preview mentioned them in a doc comment.
//
//   "the widget owns lib/previews/<area>/<snake>_preview.dart" fixed that but
//   assumed file name == class name, which is false for `ActiveOrderCard` and
//   `ClientHomeTierBadge` — both live in `active_request_card.dart`.
//
// Requiring construction alone brings back the first bug (a sibling fixture
// happens to build your widget); requiring the name alone lets a mis-typed
// fixture pass. Hence both, and a third bucket — MALFORMED — for the widgets
// with one signal and not the other, which is what a half-finished migration
// looks like.
//
// Screens are out of scope: they are already covered by the on-device Screen
// Catalog (`lib/devtool/catalog/`), which carries 270 mocked states.
//
// The detector itself lives in `tool/preview_inventory.dart`, shared verbatim
// with `test/previews/preview_structure_test.dart`.

import 'dart:convert';
import 'dart:io';

import 'preview_inventory.dart';

void main(List<String> args) {
  final bool wantJson = args.contains('--json');
  final int areaIndex = args.indexOf('--area');
  final String? areaFilter =
      areaIndex >= 0 && areaIndex + 1 < args.length ? args[areaIndex + 1] : null;

  final List<WidgetCoverage> results = PreviewInventory.scan().coverage();

  List<WidgetCoverage> of(CoverageVerdict v) =>
      results.where((WidgetCoverage r) => r.verdict == v).toList();

  final List<WidgetCoverage> covered = of(CoverageVerdict.covered);
  final List<WidgetCoverage> malformed = of(CoverageVerdict.malformed);
  final List<WidgetCoverage> uncovered = of(CoverageVerdict.uncovered);

  // MALFORMED is debt, not coverage: it queues alongside the uncovered.
  final List<WidgetCoverage> queue = <WidgetCoverage>[...malformed, ...uncovered]
      .where((WidgetCoverage r) => areaFilter == null || r.widget.area == areaFilter)
      .toList();

  if (wantJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'total': results.length,
        'covered': covered.length,
        'uncovered': uncovered.length,
        'malformed': malformed.length,
        'previews': covered.fold<int>(
          0,
          (int sum, WidgetCoverage r) => sum + r.previews.length,
        ),
        'queue': <Map<String, Object?>>[
          for (final WidgetCoverage r in queue)
            <String, Object?>{
              ...r.widget.toJson(),
              'verdict': r.verdict.name,
              'reason': r.reason,
            },
        ],
      }),
    );
    return;
  }

  final int previewCount = covered.fold<int>(
    0,
    (int sum, WidgetCoverage r) => sum + r.previews.length,
  );

  stdout.writeln('Preview coverage: ${covered.length}/${results.length} '
      '(${(covered.length / results.length * 100).toStringAsFixed(1)}%) '
      '· $previewCount preview functions');
  stdout.writeln('Uncovered: ${uncovered.length}   Malformed: '
      '${malformed.length}\n');

  if (malformed.isNotEmpty) {
    stdout.writeln('MALFORMED — one half of a preview section, not both:');
    for (final WidgetCoverage r in malformed) {
      stdout.writeln('  ${r.widget.name.padRight(38)} ${r.widget.path}');
      stdout.writeln('  ${' '.padRight(38)} ${r.reason}');
    }
    stdout.writeln('');
  }

  // Human summary, grouped by area.
  final byArea = <String, List<WidgetCoverage>>{};
  for (final WidgetCoverage r in queue) {
    byArea.putIfAbsent(r.widget.area, () => <WidgetCoverage>[]).add(r);
  }
  final List<String> areas = byArea.keys.toList()
    ..sort((String a, String b) => byArea[b]!.length.compareTo(byArea[a]!.length));

  for (final String area in areas) {
    stdout.writeln('${area.padRight(28)} ${byArea[area]!.length}');
    for (final WidgetCoverage r in byArea[area]!) {
      stdout.writeln('  ${r.widget.name.padRight(38)} ${r.widget.path}');
    }
  }
}

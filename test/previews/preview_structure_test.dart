// Structural guardrails for widget previews.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// import is what keeps the detector single-sourced with the CLI.
// ignore: avoid_relative_lib_imports — `tool/` is not a package; this relative
import '../../tool/preview_inventory.dart';

/// Maximum number of uncovered widgets allowed. Lower it as previews land —
/// never raise it. A widget whose previews are dropped or misnamed fails here
const int _coverageFloor = 0;

/// Whole-word identifier match — `_hosted` must not match `_hostedFoo`.
bool _referencesName(String haystack, String name) => RegExp(
      r'(?<![A-Za-z0-9_$])' + RegExp.escape(name) + r'(?![A-Za-z0-9_$])',
    ).hasMatch(haystack);

void main() {
  final PreviewInventory inventory = PreviewInventory.scan();

  test('INV-1 · lib/previews/ does not exist', () {
    final dir = Directory('lib/previews');
    final List<String> leftovers = dir.existsSync()
        ? dir.listSync(recursive: true).map((FileSystemEntity e) => e.path).toList()
        : const <String>[];

    expect(
      dir.existsSync(),
      isFalse,
      reason: 'Previews now live in the widget file they belong to, and the '
          'harness lives at $harnessPath. Nothing may remain under '
          'lib/previews/:\n${leftovers.join('\n')}',
    );
  });

  test('INV-2 · the harness is imported only by files with a preview section', () {
    final offenders = <String>[];
    final stale = <String>[];

    for (final SourceFile file in inventory.files) {
      if (file.path.startsWith('lib/core/previews/')) continue;
      final String source = file.rawLines.join('\n');

      // Nothing may reach for the retired tree, at any path spelling.
      if (source.contains('previews/harness/') ||
          source.contains('package:jeeb_mobile/previews/')) {
        stale.add(file.path);
      }

      final bool importsHarness =
          source.contains('core/previews/jeeb_preview.dart') ||
              source.contains('package:jeeb_mobile/core/previews/');
      if (importsHarness && !file.hasPreviewSection) offenders.add(file.path);
    }

    expect(
      stale,
      isEmpty,
      reason: 'These files import the retired lib/previews/ tree, which no '
          'longer exists:\n${stale.join('\n')}',
    );
    expect(
      offenders,
      isEmpty,
      reason: 'These files import the preview harness but have no JEEB PREVIEWS '
          'section — an import left behind after the previews were deleted. '
          'Remove it:\n${offenders.join('\n')}',
    );
  });

  test('INV-3 · no @JeebPreview above a banner, and one banner per file', () {
    final offenders = <String>[];

    for (final SourceFile file in inventory.files) {
      if (file.bannerLines.length > 1) {
        offenders.add('${file.path}: ${file.bannerLines.length} banners — a '
            'file gets ONE section even when it previews several widgets');
      }
      final List<int> annotations = file.previewAnnotationLines;
      if (annotations.isEmpty) continue;
      if (!file.hasPreviewSection) {
        offenders.add('${file.path}: has @JeebPreview but no banner');
        continue;
      }
      for (final int line in annotations) {
        if (line < file.bannerIndex) {
          offenders.add('${file.path}:${line + 1}: @JeebPreview above the banner');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('INV-4 · nothing above a banner references anything below it', () {
    final offenders = <String>[];

    for (final SourceFile file in inventory.previewSections) {
      final String shipping = file.codeAboveBanner;
      for (final SectionDeclaration decl in file.sectionDeclarations) {
        if (_referencesName(shipping, decl.name)) {
          offenders.add('${file.path}: production code above the banner '
              'references `${decl.name}`, declared at line ${decl.line + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'A preview fixture is now reachable from shipping code, so it is '
          'no longer tree-shaken and a dev-only fixture ships to users:\n'
          '${offenders.join('\n')}',
    );
  });

  test('INV-5 · nothing below a banner is referenced from another library', () {
    // Preview functions are public because the SDK requires it
    final offenders = <String>[];

    for (final SourceFile file in inventory.previewSections) {
      for (final SectionDeclaration decl in file.sectionDeclarations) {
        final RegExp reference = RegExp(
          r'(?<![A-Za-z0-9_$])' + RegExp.escape(decl.name) + r'(?![A-Za-z0-9_$])',
        );
        for (final SourceFile other in inventory.files) {
          if (identical(other, file)) continue;
          if (reference.hasMatch(other.codeText)) {
            offenders.add('${other.path} references `${decl.name}`, which is '
                'preview-only code in ${file.path}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('INV-6 · every name below a banner is widget-prefixed, and public only '
      'when a test needs it', () {
    final String testSources = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .map((File f) => f.readAsStringSync())
        .join('\n');

    final unprefixed = <String>[];
    final gratuitouslyPublic = <String>[];

    for (final SourceFile file in inventory.previewSections) {
      final Set<String> previewNames =
          file.previewFunctions.map((PreviewFunction p) => p.name).toSet();

      for (final SectionDeclaration decl in file.sectionDeclarations) {
        // §3.4: `_clientHomeGreetingHosted`, `_ClientHomeTierBadgeActiveHeader`,
        final String bare =
            decl.name.startsWith('_') ? decl.name.substring(1) : decl.name;
        final bool prefixed = file.widgetClasses.any(
          (String w) =>
              hasNamePrefix(bare, lowerCamel(w)) || hasNamePrefix(bare, w),
        );
        if (!prefixed) {
          unprefixed.add('${file.path}:${decl.line + 1}: `${decl.name}` is not '
              'prefixed with a widget name from this file '
              '(${file.widgetClasses.where((String w) => !w.startsWith('_')).join(', ')})');
        }

        if (decl.isPrivate || previewNames.contains(decl.name)) continue;
        if (!_referencesName(testSources, decl.name)) {
          gratuitouslyPublic.add('${file.path}:${decl.line + 1}: '
              '`${decl.name}` is public but no test uses it — make it private');
        }
      }
    }

    expect(unprefixed, isEmpty, reason: unprefixed.join('\n'));
    expect(gratuitouslyPublic, isEmpty, reason: gratuitouslyPublic.join('\n'));
  });

  test('INV-7 · preview coverage does not regress', () {
    final List<WidgetCoverage> results = inventory.coverage();

    List<WidgetCoverage> of(CoverageVerdict v) =>
        results.where((WidgetCoverage r) => r.verdict == v).toList();

    final List<WidgetCoverage> malformed = of(CoverageVerdict.malformed);
    final List<WidgetCoverage> uncovered = of(CoverageVerdict.uncovered);

    // MALFORMED is a widget with one half of a preview section and not the
    expect(
      malformed.map((WidgetCoverage r) => '${r.widget.name} '
          '(${r.widget.path}): ${r.reason}'),
      isEmpty,
      reason: 'Half-finished preview sections. Run: '
          'dart run tool/preview_coverage.dart',
    );

    expect(
      uncovered.length,
      lessThanOrEqualTo(_coverageFloor),
      reason: 'Preview coverage regressed: ${uncovered.length} widgets have no '
          'preview but the floor is $_coverageFloor. Either add the missing '
          'previews or lower the floor if widgets were deleted.\n'
          'Run: dart run tool/preview_coverage.dart\n'
          '${uncovered.map((WidgetCoverage r) => '  ${r.widget.name} '
              '(${r.widget.path})').join('\n')}',
    );
  });
}

// The widget-preview detector — ONE implementation, two callers.
//
//   tool/preview_coverage.dart            the work queue / CLI report
//   test/previews/preview_structure_test.dart   the CI guardrails
//
// Previews live at the BOTTOM of the widget's own source file, below a banner
// line, because `flutter widget-preview start` filters its canvas by the
// DECLARING file: open `chat_message_bubble.dart` in the IDE and you see that
// widget's previews and nothing else. A separate `lib/previews/` tree made
// every preview show up under a file nobody was editing.
//
// Everything here works on raw text. That is deliberate: this runs inside a
// plain `flutter test` with no analyzer session, so it must not need one. Two
// views of each file are kept:
//
//   rawLines   verbatim, used to find the banner (which IS a comment)
//   codeLines  same length, but any line whose first non-whitespace characters
//              are `//` is blanked
//
// The code-only view is not optional. Three preview sections mention
// `@JeebPreview` inside prose comments, and a naive scan attributes those to
// the next `Widget _something(` it finds. There are no `/* */` block comments
// anywhere in `lib/`, and §6 of the spec forbids introducing one inside a
// preview section, so blanking whole-line comments is sufficient.

import 'dart:io';

/// Directories that hold no previewable PRODUCT widgets.
///
/// Scope decisions about what the rollout is for — product UI — not judgements
/// about difficulty. A widget inside one of these paths is out of scope however
/// easy it would be to preview.
const List<String> excludedPrefixes = <String>[
  'lib/previews/', // the retired preview tree; must no longer exist
  'lib/core/previews/', // the annotation itself
  'lib/devtool/', // dev-only catalog + shell
  'lib/l10n/', // generated localizations
  // Dev-only session-trace overlay. `kObsCompiledIn` is
  // `kDevToolEnabled && bool.fromEnvironment('JEEB_OBS_OVERLAY')`
  // (observability_config.dart:32), so this whole tree is compiled OUT of every
  // non-devtool build — the same category as `lib/devtool/` above, and excluded
  // for the same reason. NB: two widgets in there DO carry previews
  // (`ObsOverlayBubble`, `ObsOverlayPanelHeader`); they are simply not counted.
  'lib/core/observability/',
];

/// The one import any file with a preview section is allowed to add.
const String harnessPath = 'lib/core/previews/jeeb_preview.dart';

/// Opening line of a preview section. Written by hand, matched by machine —
/// see `lib/core/previews/README.md` for the bytes to copy.
final RegExp bannerPattern = RegExp(r'^// =+ JEEB PREVIEWS =+$');

final RegExp _widgetClass =
    RegExp(r'^class ([A-Z][A-Za-z0-9_]*) extends (?:StatelessWidget|StatefulWidget)');

final RegExp _previewAnnotation = RegExp(r'^@JeebPreview\b');

/// Preview functions take no parameters — the SDK requires it
/// (`_PreviewVisitor.visitFunctionDeclaration`), and all 726 in this tree
/// comply. The empty `()` is what stops a parameterised fixture helper from
/// ever being mistaken for a preview.
final RegExp _previewFunction =
    RegExp(r'^Widget ([a-z][A-Za-z0-9_]*)\(\) (?:=>|\{)');

final RegExp _typeDeclaration = RegExp(
  r'^(?:abstract |base |final |sealed |interface )*'
  r'(?:class|enum|mixin|extension|typedef) ([A-Za-z_$][A-Za-z0-9_$]*)',
);

final RegExp _variableDeclaration = RegExp(
  r'^(?:const|final|late final|late|var)\s+'
  r'(?:[\w$<>,\s.?\[\]]+?\s+)?([A-Za-z_$][A-Za-z0-9_$]*)\s*=',
);

final RegExp _functionDeclaration = RegExp(
  r'^[\w$][\w$<>,\s.?\[\]]*?\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*(?:<[^>]*>)?\s*\(',
);

/// `ChatMessageBubble` -> `chatMessageBubble`.
String lowerCamel(String pascal) =>
    pascal.isEmpty ? pascal : pascal[0].toLowerCase() + pascal.substring(1);

/// Does [name] start with [prefix] at an identifier boundary?
///
/// `clientHomeGreetingNamed` belongs to `ClientHomeGreeting`; `clientHomeGrid`
/// does not. The boundary must be an uppercase letter, a digit, or the end of
/// the string — otherwise `ChatTab` would claim `chatTabbedView`.
bool hasNamePrefix(String name, String prefix) {
  if (!name.startsWith(prefix)) return false;
  if (name.length == prefix.length) return true;
  final int c = name.codeUnitAt(prefix.length);
  final bool upper = c >= 0x41 && c <= 0x5A;
  final bool digit = c >= 0x30 && c <= 0x39;
  return upper || digit;
}

/// A `@JeebPreview`-annotated function and the line it is declared on.
class PreviewFunction {
  const PreviewFunction(this.name, this.line);

  final String name;

  /// 0-based index into [SourceFile.rawLines].
  final int line;
}

/// A top-level name declared below the banner — preview function, fixture,
/// size constant, specimen widget.
class SectionDeclaration {
  const SectionDeclaration(this.name, this.line);

  final String name;
  final int line;

  bool get isPrivate => name.startsWith('_');
}

/// One `.dart` file under `lib/`, parsed for everything the preview rules need.
class SourceFile {
  SourceFile._(this.path, this.rawLines)
      : codeLines = rawLines
            .map((String l) => l.trimLeft().startsWith('//') ? '' : l)
            .toList(growable: false);

  factory SourceFile.read(String path, File file) =>
      SourceFile._(path, file.readAsLinesSync());

  /// Repo-relative, forward-slashed.
  final String path;
  final List<String> rawLines;
  final List<String> codeLines;

  List<int>? _bannerLines;
  List<String>? _widgets;
  List<PreviewFunction>? _previews;
  List<SectionDeclaration>? _declarations;
  String? _codeText;
  String? _above;
  String? _below;

  /// The whole file, comments blanked. Cached: the cross-file reference scan
  /// asks ~800 files this question once per declaration.
  String get codeText => _codeText ??= codeLines.join('\n');

  /// Every line matching the banner. More than one is a defect (INV-3).
  List<int> get bannerLines => _bannerLines ??= <int>[
        for (int i = 0; i < rawLines.length; i++)
          if (bannerPattern.hasMatch(rawLines[i])) i,
      ];

  /// First banner line, or -1 when the file has no preview section.
  int get bannerIndex => bannerLines.isEmpty ? -1 : bannerLines.first;

  bool get hasPreviewSection => bannerIndex >= 0;

  /// Public widget classes declared in this file, in source order. Unfiltered:
  /// `Screen`s and excluded names are kept, because the naming rules in §3.4
  /// are about avoiding collisions, not about coverage scope.
  List<String> get widgetClasses => _widgets ??= <String>[
        for (final String line in codeLines)
          if (_widgetClass.firstMatch(line) case final Match m) m.group(1)!,
      ];

  /// Lines carrying `@JeebPreview` at column 0, anywhere in the file.
  List<int> get previewAnnotationLines => <int>[
        for (int i = 0; i < codeLines.length; i++)
          if (_previewAnnotation.hasMatch(codeLines[i])) i,
      ];

  /// The preview functions in this file's section.
  ///
  /// For each `@JeebPreview` at or after the banner, scan forward to the first
  /// zero-arg `Widget name()` — stopping if another annotation arrives first,
  /// which means the previous one annotated something that is not a preview.
  List<PreviewFunction> get previewFunctions =>
      _previews ??= _collectPreviewFunctions();

  List<PreviewFunction> _collectPreviewFunctions() {
    if (!hasPreviewSection) return const <PreviewFunction>[];
    final found = <PreviewFunction>[];
    for (final int start in previewAnnotationLines) {
      if (start < bannerIndex) continue;
      for (int i = start + 1; i < codeLines.length; i++) {
        if (_previewAnnotation.hasMatch(codeLines[i])) break;
        final Match? m = _previewFunction.firstMatch(codeLines[i]);
        if (m != null) {
          found.add(PreviewFunction(m.group(1)!, i));
          break;
        }
      }
    }
    return found;
  }

  /// Every top-level name declared below the banner.
  List<SectionDeclaration> get sectionDeclarations =>
      _declarations ??= _collectSectionDeclarations();

  List<SectionDeclaration> _collectSectionDeclarations() {
    if (!hasPreviewSection) return const <SectionDeclaration>[];
    final found = <SectionDeclaration>[];
    for (int i = bannerIndex; i < codeLines.length; i++) {
      final String line = codeLines[i];
      if (line.isEmpty) continue;
      // Only column-0 lines can open a top-level declaration; continuations
      // and closers are indented or start with a bracket.
      if (line.startsWith(RegExp(r'[\s})\];=@]'))) continue;
      final Match? m = _typeDeclaration.firstMatch(line) ??
          _variableDeclaration.firstMatch(line) ??
          _functionDeclaration.firstMatch(line);
      if (m != null) found.add(SectionDeclaration(m.group(1)!, i));
    }
    return found;
  }

  /// Code-only text above the banner (the shipping half of the file).
  String get codeAboveBanner => _above ??=
      hasPreviewSection ? codeLines.take(bannerIndex).join('\n') : codeText;

  /// Code-only text from the banner to EOF.
  String get codeBelowBanner =>
      _below ??= hasPreviewSection ? codeLines.skip(bannerIndex).join('\n') : '';

  /// Does the preview section actually build [widget]?
  ///
  /// A preview named after a widget it never constructs is a mis-typed fixture,
  /// which is exactly the failure the old file-ownership rule could not see.
  bool constructs(String widget) => RegExp(
        r'(?<![A-Za-z0-9_$])' + RegExp.escape(widget) + r'\s*\(',
      ).hasMatch(codeBelowBanner);
}

/// A previewable widget and where it is declared.
class WidgetRef {
  const WidgetRef(this.name, this.path);

  final String name;
  final String path;

  /// Feature folder the widget belongs to. Drives `--area` and the report
  /// grouping; it is no longer a destination, since previews now live in
  /// [path] itself.
  String get area {
    final Match? feature = RegExp(r'^lib/features/([^/]+)/').firstMatch(path);
    if (feature != null) return feature.group(1)!;
    if (path.startsWith('lib/core/')) return 'core';
    if (path.startsWith('lib/app/')) return 'app';
    return 'misc';
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'widget': name,
        'source': path,
        'area': area,
      };
}

/// Why a widget failed to count as covered.
enum CoverageVerdict {
  /// Owns ≥1 attributed preview function AND its section constructs it.
  covered,

  /// Neither signal.
  uncovered,

  /// Exactly one of the two signals — almost always a half-finished migration.
  malformed,

  /// In scope and genuinely previewable, but not until a production seam is
  /// added — the widget offers no way to inject its data.
  ///
  /// Deliberately NOT an exclusion. An exclusion says "out of scope"; this says
  /// "real debt, named". It is reported separately rather than left in the
  /// uncovered count, where it would block a rollout from ever finishing while
  /// telling nobody why. `tool/preview_blocked.txt` records the exact seam.
  blocked,
}

class WidgetCoverage {
  const WidgetCoverage(this.widget, this.verdict, this.previews, this.reason);

  final WidgetRef widget;
  final CoverageVerdict verdict;

  /// Preview functions attributed to this widget.
  final List<String> previews;

  /// Human-readable explanation, empty when [verdict] is
  /// [CoverageVerdict.covered].
  final String reason;
}

/// Everything the two callers need, computed once.
class PreviewInventory {
  PreviewInventory._(this.files, this.exclusions, this.blocked);

  /// Every `.dart` file under `lib/`, including the excluded prefixes — the
  /// structural invariants need to see files that coverage ignores.
  final List<SourceFile> files;

  /// Widget class names deliberately kept out of the coverage count.
  final Set<String> exclusions;

  /// Widgets awaiting a production seam, mapped to the seam they need.
  final Map<String, String> blocked;

  static PreviewInventory scan({
    String libRoot = 'lib',
    String exclusionsFile = 'tool/preview_exclusions.txt',
    String blockedFile = 'tool/preview_blocked.txt',
  }) {
    final files = <SourceFile>[];
    for (final File f in _dartFilesUnder(libRoot)) {
      final String path = _rel(f.path);
      files.add(SourceFile.read(path, f));
    }
    files.sort((SourceFile a, SourceFile b) => a.path.compareTo(b.path));
    return PreviewInventory._(
      files,
      _loadExclusions(exclusionsFile),
      _loadBlocked(blockedFile),
    );
  }

  /// Files carrying a preview section.
  Iterable<SourceFile> get previewSections =>
      files.where((SourceFile f) => f.hasPreviewSection);

  /// Files coverage cares about — product UI only.
  Iterable<SourceFile> get inScopeFiles => files.where(
        (SourceFile f) => !excludedPrefixes.any(f.path.startsWith),
      );

  /// Coverage verdict per in-scope widget, in file order.
  List<WidgetCoverage> coverage() {
    final results = <WidgetCoverage>[];
    for (final SourceFile file in inScopeFiles) {
      // Attribution is resolved against EVERY widget in the file, then filtered
      // — so a preview claimed by an excluded sibling does not leak onto an
      // in-scope one.
      final List<String> candidates = file.widgetClasses;
      for (final String name in candidates) {
        // Screens WERE excluded here on the grounds that the on-device Screen
        // Catalog covered them. It covers ~56 of 82, it is an in-app browser
        // rather than an IDE surface, and 0 screens had a preview — so the
        // tool reported 100% while 80 screens showed nothing when opened.
        // A coverage number that excludes the gap is the failure the
        // MALFORMED check exists to prevent, so the exclusion is gone.
        if (exclusions.contains(name)) continue;
        if (blocked.containsKey(name)) {
          results.add(WidgetCoverage(
            WidgetRef(name, file.path),
            CoverageVerdict.blocked,
            const <String>[],
            blocked[name]!,
          ));
          continue;
        }

        final owned = <String>[
          for (final PreviewFunction fn in file.previewFunctions)
            if (_owner(fn.name, candidates) == name) fn.name,
        ];
        final bool builds = file.constructs(name);
        final ref = WidgetRef(name, file.path);

        if (owned.isNotEmpty && builds) {
          results.add(WidgetCoverage(ref, CoverageVerdict.covered, owned, ''));
        } else if (owned.isEmpty && !builds) {
          results.add(
            WidgetCoverage(
              ref,
              CoverageVerdict.uncovered,
              owned,
              file.hasPreviewSection
                  ? 'file has a preview section but nothing for this widget'
                  : 'no preview section in ${file.path}',
            ),
          );
        } else {
          results.add(
            WidgetCoverage(
              ref,
              CoverageVerdict.malformed,
              owned,
              owned.isEmpty
                  ? 'the section builds $name but no preview function is '
                      'named ${lowerCamel(name)}*'
                  : 'previews named ${lowerCamel(name)}* exist '
                      '(${owned.join(', ')}) but the section never '
                      'constructs $name',
            ),
          );
        }
      }
    }
    return results;
  }

  /// Which widget owns [fn]. Longest prefix wins, so a future merge that puts
  /// `Chat` and `ChatComposer` in one file cannot silently cross-attribute.
  static String? _owner(String fn, List<String> widgets) {
    String? best;
    for (final String w in widgets) {
      if (!hasNamePrefix(fn, lowerCamel(w))) continue;
      if (best == null || w.length > best.length) best = w;
    }
    return best;
  }
}

Set<String> _loadExclusions(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .map((String l) => l.split('#').first.trim())
      .where((String l) => l.isNotEmpty)
      .toSet();
}

/// `<WidgetName>  # the seam it needs` — same comment convention as the
/// exclusions file, but here the comment is load-bearing: it IS the debt.
Map<String, String> _loadBlocked(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String, String>{};
  final out = <String, String>{};
  for (final String raw in file.readAsLinesSync()) {
    final int hash = raw.indexOf('#');
    final String name = (hash < 0 ? raw : raw.substring(0, hash)).trim();
    if (name.isEmpty) continue;
    out[name] = hash < 0 ? '' : raw.substring(hash + 1).trim();
  }
  return out;
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

String _rel(String path) => path
    .replaceFirst('${Directory.current.path}${Platform.pathSeparator}', '')
    .replaceAll(Platform.pathSeparator, '/');

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// A REAL transitive import-closure walk over `lib/`, from both shipping
// entrypoints.
//
// WHY THIS FILE EXISTS. The two pre-existing isolation tests —
// `test/release/store_entrypoint_auth_surface_test.dart` ("the product
// entrypoint has no Dev Tool dependency graph") and
// `test/internal_devtool/internal_devtool_source_contract_test.dart`
// ("internal release graph stays isolated from the legacy developer tool") —
// each grep a SINGLE file's own bytes. Neither can see an edge that arrives
// one hop away, so both pass unchanged while the graph beneath them changes.
// Shake-to-Dev-Tool added exactly such an edge
// (`lib/app/app.dart` -> `lib/devtool/shake/devtool_shake.dart` ->
// `lib/devtool/devtool_shell.dart`, i.e. Super Login + location sim +
// scenario users), and both of those tests stayed green through it.
//
// WHAT IS AND IS NOT NEW. The graph did NOT become "no longer isolated" here:
// on `origin/main`, twelve product screens already import
// `lib/devtool/catalog/...` fixtures, so a release AOT snapshot has always
// depended on tree-shaking to keep `lib/devtool/` out. What IS new is the
// first edge that reaches the `devtool_shell` cluster. So the invariant this
// file pins is the one that is actually true and actually load-bearing:
// exactly one non-catalog edge crosses into `lib/devtool/`, and it is behind
// a compile-time `false`.

/// Hand-rolled instead of `package:path`: `path` is not a declared dependency
/// of this package, and the repo's dependency-ownership gate forbids reaching
/// for an undeclared transitive one.
String _normalize(String path) {
  final List<String> out = <String>[];
  for (final String segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (out.isNotEmpty && out.last != '..') {
        out.removeLast();
      } else {
        out.add('..');
      }
      continue;
    }
    out.add(segment);
  }
  return out.join('/');
}

String _dirname(String path) {
  final int index = path.lastIndexOf('/');
  return index < 0 ? '' : path.substring(0, index);
}

final RegExp _directive = RegExp(
  '''^\\s*(?:import|export)\\s+(?:'([^']+)'|"([^"]+)")''',
  multiLine: true,
);

Iterable<String> _targets(String source) =>
    _directive.allMatches(source).map((m) => m.group(1) ?? m.group(2)!);

/// Maps a directive target onto a repo-relative path under `lib/`, or null for
/// anything outside this package (`dart:`, third-party `package:`).
String? _resolve(String target, String fromDir) {
  const String selfPrefix = 'package:jeeb_mobile/';
  if (target.startsWith(selfPrefix)) {
    return _normalize('lib/${target.substring(selfPrefix.length)}');
  }
  if (target.startsWith('dart:') || target.startsWith('package:')) return null;
  return _normalize(fromDir.isEmpty ? target : '$fromDir/$target');
}

Set<String> _closure(String entry) {
  final Set<String> seen = <String>{};
  final List<String> queue = <String>[_normalize(entry)];
  while (queue.isNotEmpty) {
    final String current = queue.removeLast();
    if (!seen.add(current)) continue;
    final File file = File(current);
    if (!file.existsSync()) continue;
    for (final String target in _targets(file.readAsStringSync())) {
      final String? resolved = _resolve(target, _dirname(current));
      if (resolved != null) queue.add(resolved);
    }
  }
  return seen;
}

/// Every edge `a -> b` inside [closure] whose target is under `lib/devtool/`.
List<List<String>> _devToolEdges(Set<String> closure) {
  final List<List<String>> edges = <List<String>>[];
  for (final String from in closure) {
    final File file = File(from);
    if (!file.existsSync()) continue;
    for (final String target in _targets(file.readAsStringSync())) {
      final String? to = _resolve(target, _dirname(from));
      if (to != null && to.startsWith('lib/devtool/')) {
        edges.add(<String>[from, to]);
      }
    }
  }
  return edges;
}

/// Source lines with `//` comments stripped, so a mention inside a doc comment
/// is not mistaken for a use site.
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final int index = line.indexOf('//');
      return index < 0 ? line : line.substring(0, index);
    })
    .join('\n');

void main() {
  final Set<String> product = _closure('lib/main.dart');
  final Set<String> internal = _closure('lib/main_android_internal.dart');
  final Map<String, Set<String>> entrypoints = <String, Set<String>>{
    'lib/main.dart': product,
    'lib/main_android_internal.dart': internal,
  };

  group('Dev Tool import closure', () {
    test('the walker actually walks (positive controls)', () {
      // Without these, every assertion below could pass vacuously on a
      // resolver that silently returns an empty or one-element closure.
      expect(
        product,
        containsAll(<String>[
          'lib/main.dart',
          'lib/app/jeeb_bootstrap.dart',
          'lib/app/app.dart',
          'lib/core/router/app_router.dart',
        ]),
        reason: 'the product closure must reach past its own entrypoint',
      );
      expect(product.length, greaterThan(500));
      expect(
        internal,
        contains('lib/internal_devtool/internal_devtool_app.dart'),
        reason: 'the internal entrypoint must reach the restricted tool',
      );
      expect(
        product,
        isNot(contains('lib/internal_devtool/internal_devtool_app.dart')),
        reason: 'the store entrypoint must not reach the restricted tool',
      );
    });

    test('the only non-catalog crossing into lib/devtool/ is the shake edge', () {
      for (final MapEntry<String, Set<String>> entry in entrypoints.entries) {
        final List<String> crossings = _devToolEdges(entry.value)
            .where((edge) => !edge.first.startsWith('lib/devtool/'))
            .where((edge) => !edge.last.startsWith('lib/devtool/catalog/'))
            .map((edge) => '${edge.first} -> ${edge.last}')
            .toList()
          ..sort();

        expect(
          crossings,
          <String>['lib/app/app.dart -> lib/devtool/shake/devtool_shake.dart'],
          reason:
              'a new import edge into lib/devtool/ landed in ${entry.key}; '
              'it is NOT covered by the const gate and would put Super Login '
              'strings in a release compilation unit',
        );
      }
    });

    test('the pre-existing catalog-fixture crossings have not grown', () {
      // Baseline captured from `origin/main`: twelve product screens already
      // import their catalog fixtures. Pinned so a thirteenth is noticed, and
      // so the test above cannot be relaxed by moving code under
      // `lib/devtool/catalog/`.
      for (final MapEntry<String, Set<String>> entry in entrypoints.entries) {
        final Set<String> importers = _devToolEdges(entry.value)
            .where((edge) => !edge.first.startsWith('lib/devtool/'))
            .where((edge) => edge.last.startsWith('lib/devtool/catalog/'))
            .map((edge) => edge.first)
            .toSet();

        expect(importers, hasLength(12), reason: entry.key);
        expect(
          importers,
          contains('lib/core/diagnostics/diagnostics_screen.dart'),
          reason: 'positive control on a known pre-existing importer',
        );
      }
    });

    test('the shake edge is used only behind the compile-time const', () {
      final String app = _codeOnly(File('lib/app/app.dart').readAsStringSync());

      expect(
        'DevToolShakeHost'.allMatches(app).length,
        1,
        reason: 'app.dart must have exactly one DevToolShakeHost use site '
            'outside comments',
      );
      expect(
        app,
        contains('kShakeToDevToolEnabled'),
        reason: 'that use site must be guarded by the const',
      );
      expect(
        RegExp(
          r'kShakeToDevToolEnabled\s*\?\s*DevToolShakeHost\(',
        ).hasMatch(app),
        isTrue,
        reason: 'the only use site must be the const-false ternary, so a '
            'release AOT snapshot drops the whole subgraph',
      );
    });

    test('neither shipping entrypoint reaches another Dev Tool entrypoint', () {
      for (final MapEntry<String, Set<String>> entry in entrypoints.entries) {
        expect(
          entry.value,
          isNot(contains('lib/main_devtool.dart')),
          reason: entry.key,
        );
      }
    });
  });
}

// M6 — the devtool tree is low user impact but the capture harness mounts it,
// so a `Colors.black54` scrim or an orange "OK" frame lands in the evidence.
// Source-level, in the shape `no_raw_semantic_colors_test.dart` established:
// these two surfaces need a driver (a gateway client, a pushed route) that a
// widget test would have to fake more than it asserts.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Paint that must not reappear in the devtool tree.
final Map<String, RegExp> _forbidden = <String, RegExp>{
  // The lookbehind keeps `JeebSemanticColors.midnight()` out of the match.
  'Material palette constant':
      RegExp(r'(?<![A-Za-z0-9_])Colors\.(?!transparent\b)[a-zA-Z]'),
  'raw Color(0x...) literal': RegExp(r'Color\(0x'),
  // Under Midnight `primary` IS #D73B00, so it is the orange-budget signature,
  // not a neutral brand slot. `tertiary` is its compat alias.
  'brand accent on devtool chrome': RegExp(r'\.(primary|tertiary)\b'),
};

const List<String> _files = <String>[
  'lib/devtool/catalog/catalog_screen.dart',
  'lib/devtool/actions/actions_page.dart',
];

void main() {
  group('devtool chrome carries no light-theme or brand paint', () {
    for (final String path in _files) {
      test(path, () {
        final File file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '$path moved — update devtool_midnight_chrome_test.dart');
        final String source = file.readAsStringSync();
        for (final MapEntry<String, RegExp> entry in _forbidden.entries) {
          final RegExpMatch? match = entry.value.firstMatch(source);
          expect(
            match,
            isNull,
            reason: '$path regressed: found "${match?.group(0)}" '
                '(${entry.key}). Read the token layer — `JeebSemanticColors` '
                'glass rungs, `context.jeebRoles`, `JeebRadii`.',
          );
        }
      });
    }
  });
}

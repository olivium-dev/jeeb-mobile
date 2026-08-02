// A `*Container` colour role must never be used as INK.
//
// `app_theme.dart` states the rule in its own words:
//
//   > Anything that wants to PAINT with brand orange (a progress bar, an accent
//   > icon) must use `tertiary`, never a `*Container` role.
//
// It was broken in 11 production widgets anyway, and only 6 of those were ever
// reported — because the light scheme HIDES the mistake. `AppTheme.light()`
// hand-pins `primary`, `secondary` and `secondaryContainer` all to the same
// `_jeebNavy`, so a heading painted with `secondaryContainer` measures ~17:1 on
// white and looks perfect in every light-only review. `AppTheme.dark()` derives
// its scheme from `ColorScheme.fromSeed`, where `secondaryContainer` resolves to
// a dark FILL tone (#444559) against a #131318 surface — roughly 2:1, under even
// the 3:1 large-text floor. The app runs `themeMode: ThemeMode.system`.
//
// A widget test cannot catch this: the colour resolves fine, renders fine, and
// throws nothing. Only measuring it against the surface, or looking at it in
// dark mode, shows the problem. So this is a source-level guard instead.
//
// If you are adding a legitimate FILL — `Container(color:)`, `BoxDecoration`,
// `ColoredBox` — that is correct usage and this test already ignores it. The
// check only fires when the role lands in a `TextStyle`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Colour roles that describe a FILL, and so may never be a text colour.
const List<String> _containerRoles = <String>[
  'primaryContainer',
  'secondaryContainer',
  'tertiaryContainer',
  'errorContainer',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'surfaceContainerLow',
  'surfaceContainerLowest',
];

final RegExp _colorAssignment = RegExp(
  r'color:\s*(?:theme\.)?(?:\w+)?[Cc]olorScheme\.(\w+)',
);

/// Openers that mean the `color:` about to follow is a FILL.
const List<String> _fillOpeners = <String>[
  'BoxDecoration(',
  'ColoredBox(',
  'Container(',
  'CircleAvatar(',
  'Material(',
];

/// Openers that mean it is INK.
const List<String> _inkOpeners = <String>['copyWith(', 'TextStyle('];

/// Whichever opener appears LAST before the match wins.
///
/// Comparing "contains" rather than position was not enough: the splash screen
/// is a `ColoredBox` fill sitting a few lines below an unrelated
/// `SystemUiOverlayStyle.light.copyWith(`, and a contains-check read that stray
/// `copyWith` as a text style and reported the fill as a defect.
bool _isInkContext(String before) {
  int lastOf(List<String> needles) => needles
      .map(before.lastIndexOf)
      .fold(-1, (int a, int b) => a > b ? a : b);
  return lastOf(_inkOpeners) > lastOf(_fillOpeners);
}

List<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('no *Container colour role is used as a text colour', () {
    final offenders = <String>[];

    for (final file in _libDartFiles()) {
      final source = file.readAsStringSync();
      for (final match in _colorAssignment.allMatches(source)) {
        final role = match.group(1)!;
        if (!_containerRoles.contains(role)) continue;

        final before = source.substring(
          match.start < 300 ? 0 : match.start - 300,
          match.start,
        );
        if (!_isInkContext(before)) continue; // a fill — legitimate

        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        final path = file.path.replaceFirst(
          '${Directory.current.path}${Platform.pathSeparator}',
          '',
        );
        offenders.add('$path:$line uses `$role` as ink');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A *Container role is a FILL and is illegible on a surface in dark '
          'mode. Use the matching on-colour (`onSecondaryContainer`) when '
          'painting ON that container, or a foreground role (`primary`, '
          '`onSurface`, `onSurfaceVariant`) when painting on a surface.\n\n'
          'Note `AppTheme.light()` pins primary/secondary/secondaryContainer to '
          'the same navy, so swapping `secondaryContainer` -> `primary` for ink '
          'is a no-op in light and a fix in dark.\n\n'
          '${offenders.join('\n')}',
    );
  });
}

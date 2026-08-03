// A `*Container` colour role must never be used as INK.

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
/// Comparing "contains" rather than position was not enough: the splash screen
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
          'A *Container role is a FILL and is illegible as ink. Use the '
          'matching on-colour (`onSecondaryContainer`) when painting ON that '
          'container, or a foreground role (`onSurface`, `onSurfaceVariant`) '
          'when painting on a surface.\n\n'
          'MIDNIGHT: `secondaryContainer` was navy in the light theme (dark '
          'ink on white); it is now #10175E, invisible on the navy field.\n\n'
          '${offenders.join('\n')}',
    );
  });
}

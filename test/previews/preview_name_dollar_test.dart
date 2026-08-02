// A `$` in a preview name disables EVERY preview in the project.
//
// `flutter widget-preview start` serialises each annotation into one generated
// file, and it re-emits string arguments WITHOUT re-escaping them. So a name
// that is perfectly legal in our source:
//
//     name: 'Currency LBP · hardcoded \$ icon',
//
// comes back out as
//
//     preview: _i2.JeebPreview(name: 'Currency LBP · hardcoded $ icon', ...)
//
// where `$ ` opens a string interpolation. The generated file then fails to
// parse:
//
//     Could not format because the source could not be parsed:
//     line 4, column 217434: Expected an identifier.
//
// Every preview in the project lives in that one file, so all 1,441 of them
// disappear at once and both the IDE panel and the CLI report "No previews
// detected" — pointing at nothing in particular. Three names cost the whole
// canvas, and the render tests could not see it because they call the preview
// functions directly and never serialise the annotation.
//
// Until the generator escapes properly, keep `$` out of preview metadata.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A string argument inside an `@JeebPreview(...)` block.
final RegExp _annotation = RegExp(r'@JeebPreview\(([^)]*)\)', dotAll: true);

List<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('no @JeebPreview name or group contains a dollar sign', () {
    final offenders = <String>[];

    for (final file in _libDartFiles()) {
      final source = file.readAsStringSync();
      for (final match in _annotation.allMatches(source)) {
        final args = match.group(1)!;
        if (!args.contains(r'$')) continue;
        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A `\$` in a preview annotation is re-emitted unescaped into the '
          'generated preview scaffold, which then fails to parse. That takes '
          'out EVERY preview in the project, not just this one, and the '
          'symptom is an empty canvas with no useful error.\n\n'
          'Write the currency out instead — "9.00 USD", not "\\\$9.00".\n\n'
          '${offenders.join('\n')}',
    );
  });
}

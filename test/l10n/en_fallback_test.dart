// UX-46: `_get` asserts in debug and returns the KEY in release, so a key
// present only in EN would ship as `someKeyName` to an Arabic user. The
// delegate merges EN underneath the target locale; this pins that.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

String _read(String tag) => File('lib/l10n/app_$tag.arb').readAsStringSync();

void main() {
  test('a key missing from AR resolves to the EN string, never the key', () {
    final Map<String, dynamic> ar =
        jsonDecode(_read('ar')) as Map<String, dynamic>;
    ar.remove('errorGenericBody');

    final AppLocalizations loc = debugLoadMergedAppLocalizations(
      const Locale('ar'),
      arbJson: jsonEncode(ar),
      fallbackArbJson: _read('en'),
    );

    final String en =
        (jsonDecode(_read('en')) as Map<String, dynamic>)['errorGenericBody']
            as String;
    expect(loc.errorGenericBody, en);
  });

  test('the target locale still wins over the EN underlay', () {
    final AppLocalizations loc = debugLoadMergedAppLocalizations(
      const Locale('ar'),
      arbJson: _read('ar'),
      fallbackArbJson: _read('en'),
    );

    final String ar =
        (jsonDecode(_read('ar')) as Map<String, dynamic>)['errorGenericBody']
            as String;
    expect(loc.errorGenericBody, ar);
  });
}

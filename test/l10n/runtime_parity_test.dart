// Runtime parity gate for T-MOB-FIX-002 (JEB-2).
// Authoritative spec: JEB-2 LEAD comment 14782 §3.
//
// Asserts that every key in the EN + AR ARB resolves to a non-null,
// non-key, non-empty value via `AppLocalizations.byKey`.
// Catches stub strings that were never translated (value == key) which the
// static `qa/t-mob-fix-002/l10n_parity_check.sh` would also flag but only
// at the ARB layer — this runtime test exercises the loader path.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    test('${locale.languageCode}: every ARB key loads with a non-key value',
        () {
      final arbPath = 'lib/l10n/app_${locale.languageCode}.arb';
      final raw = File(arbPath).readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final keys = json.keys.where((k) => !k.startsWith('@')).toList();

      final loc = debugLoadAppLocalizationsSync(locale, raw);

      final failures = <String>[];
      for (final key in keys) {
        final value = loc.byKey(key);
        if (value == null) {
          failures.add('null: $key');
        } else if (value == key) {
          failures.add('value-equals-key: $key');
        } else if (value.trim().isEmpty) {
          failures.add('empty: $key');
        }
      }

      expect(
        failures,
        isEmpty,
        reason: 'Found ${failures.length} parity defect(s) in '
            '${locale.languageCode}:\n  ${failures.take(20).join('\n  ')}'
            '${failures.length > 20 ? '\n  ... (+${failures.length - 20} more)' : ''}',
      );
    });

    test('${locale.languageCode}: ARB key set matches the other locale', () {
      final raw = File('lib/l10n/app_${locale.languageCode}.arb')
          .readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final keys = json.keys.where((k) => !k.startsWith('@')).toSet();

      final otherCode = locale.languageCode == 'en' ? 'ar' : 'en';
      final otherRaw = File('lib/l10n/app_$otherCode.arb').readAsStringSync();
      final otherJson = jsonDecode(otherRaw) as Map<String, dynamic>;
      final otherKeys =
          otherJson.keys.where((k) => !k.startsWith('@')).toSet();

      final onlyHere = keys.difference(otherKeys);
      final onlyThere = otherKeys.difference(keys);

      expect(
        onlyHere.isEmpty && onlyThere.isEmpty,
        isTrue,
        reason: 'ARB drift between ${locale.languageCode} and $otherCode:\n'
            '  only in ${locale.languageCode}: ${onlyHere.take(15)}\n'
            '  only in $otherCode: ${onlyThere.take(15)}',
      );
    });
  }
}

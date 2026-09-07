import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _failureKey = RegExp(
  r'error|invalid|failed|unavailable|denied|cannot|couldn|retry|offline|timeout|expired|tooMany|rateLimit|refreshFailed|loading|required',
  caseSensitive: false,
);
final _placeholders = RegExp(r'\{[^{}]*\}');
final _allowedTokens = RegExp(
  r'\b(?:PDF|GPS|JPEG|PNG|Face ID|Google|Apple|OTP|SMS|E\.164|Wi-Fi)\b',
);
final _latin = RegExp(r'[A-Za-z]{2,}');
final _arabicIndic = RegExp(r'[\u0660-\u0669]');

void main() {
  test('Arabic failure copy is translated and uses Western digits', () {
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final ar =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = en.keys.where(
      (key) => !key.startsWith('@') && _failureKey.hasMatch(key),
    );
    expect(
      keys.length,
      greaterThan(500),
      reason: 'The guard must cover the full failure family.',
    );
    final violations = <String>[];
    for (final key in keys) {
      final value = ar[key];
      if (value is! String || value.trim().isEmpty || value == en[key]) {
        violations.add('$key: untranslated');
        continue;
      }
      final copy = value
          .replaceAll(_placeholders, '')
          .replaceAll(_allowedTokens, '');
      if (_arabicIndic.hasMatch(value)) {
        violations.add('$key: non-Western digits');
      }
      if (_latin.hasMatch(copy)) violations.add('$key: unapproved Latin token');
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

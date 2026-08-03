// P4 + P5 (b01-20260725) — TC-C19: l10n parity for the attachment copy.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// The keys P4/P5 introduces.
const _p45Keys = <String>[
  'chatErrorAttachmentUploadFailed',
  'chatAttachmentSheetSubtitle',
];

/// Every key the attachment flow renders, new and pre-existing.
const _attachmentKeys = <String>[
  ..._p45Keys,
  'chatAttachmentSheetTitle',
  'chatAttachmentCamera',
  'chatAttachmentGallery',
  'chatAttachmentCancel',
];

Map<String, dynamic> _arb(String tag) =>
    jsonDecode(File('lib/l10n/app_$tag.arb').readAsStringSync())
        as Map<String, dynamic>;

/// True when [value] contains at least one character in the Arabic block.
bool _hasArabicScript(String value) =>
    value.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  setUpAll(() {
    en = _arb('en');
    ar = _arb('ar');
  });

  test('every attachment key exists in BOTH app_en.arb and app_ar.arb', () {
    for (final key in _attachmentKeys) {
      expect(en.containsKey(key), isTrue, reason: 'missing in app_en.arb: $key');
      expect(ar.containsKey(key), isTrue, reason: 'missing in app_ar.arb: $key');
      expect((en[key] as String).trim(), isNotEmpty, reason: 'blank en: $key');
      expect((ar[key] as String).trim(), isNotEmpty, reason: 'blank ar: $key');
    }
  });

  test('the Arabic copy is REAL Arabic, not an English placeholder', () {
    for (final key in _attachmentKeys) {
      final value = ar[key] as String;
      expect(
        _hasArabicScript(value),
        isTrue,
        reason: 'app_ar.arb[$key] carries no Arabic script: "$value"',
      );
      expect(
        value,
        isNot(en[key]),
        reason: 'app_ar.arb[$key] is a verbatim copy of the English string',
      );
    }
  });

  test('each P4/P5 key resolves through a hand-written getter in both locales',
      () {
    final enL10n = debugLoadAppLocalizationsSync(
      const Locale('en'),
      File('lib/l10n/app_en.arb').readAsStringSync(),
    );
    final arL10n = debugLoadAppLocalizationsSync(
      const Locale('ar'),
      File('lib/l10n/app_ar.arb').readAsStringSync(),
    );

    // A missing getter is a compile error; a missing ARB entry would surface as
    expect(enL10n.chatErrorAttachmentUploadFailed,
        en['chatErrorAttachmentUploadFailed']);
    expect(arL10n.chatErrorAttachmentUploadFailed,
        ar['chatErrorAttachmentUploadFailed']);
    expect(enL10n.chatAttachmentSheetSubtitle, en['chatAttachmentSheetSubtitle']);
    expect(arL10n.chatAttachmentSheetSubtitle, ar['chatAttachmentSheetSubtitle']);

    for (final key in _p45Keys) {
      expect(enL10n.chatErrorAttachmentUploadFailed, isNot(key));
      expect(arL10n.chatAttachmentSheetSubtitle, isNot(key));
    }
  });
}

/// Digit-normalization primitives for numeric identity fields.
///
/// Arabic keyboards (the app is RTL-first) produce Eastern Arabic-Indic
/// digits — `٠١٢٣٤٥٦٧٨٩` (U+0660–U+0669) — and some locales produce the
/// Extended (Persian/Urdu) variants `۰۱۲۳۴۵۶۷۸۹` (U+06F0–U+06F9). Dart's
/// ASCII-only `\d` and `FilteringTextInputFormatter.digitsOnly` both reject
/// them, silently swallowing keystrokes, even though the value the user typed
/// is a perfectly good number. Normalizing to ASCII before any digit filter
/// or `^\d{12}$`-style validation keeps Arabic-keyboard input working
/// (JEBV4-113 review finding 5).
///
/// NOTE: the phone field in `lebanon_phone.dart` has the same gap (raw
/// `digitsOnly` on an Arabic-first app); fixing it is tracked separately —
/// this module is deliberately reusable for that follow-up.
library;

import 'package:flutter/services.dart';

const Map<int, int> _arabicIndicToAscii = {
  // Eastern Arabic-Indic digits U+0660–U+0669 (٠١٢٣٤٥٦٧٨٩).
  0x0660: 0x30, 0x0661: 0x31, 0x0662: 0x32, 0x0663: 0x33, 0x0664: 0x34,
  0x0665: 0x35, 0x0666: 0x36, 0x0667: 0x37, 0x0668: 0x38, 0x0669: 0x39,
  // Extended (Persian/Urdu) digits U+06F0–U+06F9 (۰۱۲۳۴۵۶۷۸۹).
  0x06F0: 0x30, 0x06F1: 0x31, 0x06F2: 0x32, 0x06F3: 0x33, 0x06F4: 0x34,
  0x06F5: 0x35, 0x06F6: 0x36, 0x06F7: 0x37, 0x06F8: 0x38, 0x06F9: 0x39,
};

/// Returns [input] with every Eastern Arabic-Indic / Extended digit replaced
/// by its ASCII `0-9` equivalent. All other characters pass through unchanged
/// (1:1, length-preserving).
String normalizeArabicIndicDigits(String input) {
  if (input.isEmpty) return input;
  final units = input.codeUnits;
  StringBuffer? out;
  for (var i = 0; i < units.length; i++) {
    final mapped = _arabicIndicToAscii[units[i]];
    if (mapped != null) {
      out ??= StringBuffer(input.substring(0, i));
      out.writeCharCode(mapped);
    } else {
      out?.writeCharCode(units[i]);
    }
  }
  return out?.toString() ?? input;
}

/// A [TextInputFormatter] that maps Eastern Arabic-Indic / Extended digits to
/// ASCII as the user types (or pastes). Length-preserving (1:1 mapping), so
/// the selection/cursor position stays valid unchanged. Place it BEFORE
/// [FilteringTextInputFormatter.digitsOnly] so Arabic keystrokes survive the
/// digits filter instead of being swallowed.
class ArabicIndicDigitsFormatter extends TextInputFormatter {
  const ArabicIndicDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeArabicIndicDigits(newValue.text);
    if (identical(normalized, newValue.text) ||
        normalized == newValue.text) {
      return newValue;
    }
    return newValue.copyWith(text: normalized);
  }
}

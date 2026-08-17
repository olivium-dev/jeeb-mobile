library;

import 'package:flutter/services.dart';

const Map<int, int> _arabicIndicToAscii = {
  0x0660: 0x30, 0x0661: 0x31, 0x0662: 0x32, 0x0663: 0x33, 0x0664: 0x34,
  0x0665: 0x35, 0x0666: 0x36, 0x0667: 0x37, 0x0668: 0x38, 0x0669: 0x39,
  0x06F0: 0x30, 0x06F1: 0x31, 0x06F2: 0x32, 0x06F3: 0x33, 0x06F4: 0x34,
  0x06F5: 0x35, 0x06F6: 0x36, 0x06F7: 0x37, 0x06F8: 0x38, 0x06F9: 0x39,
};

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

/// Uppercases as the user types, preserving the caret. Used where an upstream
/// contract enforces an `[A-Z0-9]` shape and rejects rather than normalizes.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    // Same length, so the existing selection stays valid.
    return newValue.copyWith(text: upper);
  }
}

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

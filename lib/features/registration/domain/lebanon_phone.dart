/// Lebanese phone-number value object: normalises user input to E.164 (`+961XXXXXXXX`).
class LebanonPhone {
  const LebanonPhone._(this.digits);

  final String digits;

  String get e164 => '$dialCode$digits';

  static const String dialCode = '+961';

  static const int nationalDigitCount = 8;

  /// Min 7 digits: some valid numbers carry only 7 national digits (+9613000002 seed).
  static const int minNationalDigitCount = 7;

  static String normalise(String raw) {
    final input = _transliterateDigits(raw).trim();
    if (!_allowedCharacters.hasMatch(input)) return '';
    if ('+'.allMatches(input).length > 1) return '';
    if (input.contains('+') && !input.startsWith('+')) return '';
    if (input.startsWith('+') && !input.startsWith(dialCode)) return '';
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    var rest = digitsOnly;
    if (rest.startsWith('961')) {
      rest = rest.substring(3);
    } else if (rest.startsWith('0')) {
      rest = rest.substring(1);
    }
    return rest;
  }

  /// Parses [raw] to LebanonPhone if valid (7-8 digits), else null. Used for "ready to send" CTA gate.
  static LebanonPhone? tryParse(String raw) {
    final n = normalise(raw);
    if (n.length < minNationalDigitCount || n.length > nationalDigitCount) {
      return null;
    }
    return LebanonPhone._(n);
  }

  String get displayWithPrefix => '$dialCode $digits';
}

final RegExp _allowedCharacters = RegExp(r'^[+0-9٠-٩۰-۹\s\-()]*$');

const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
const String _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

String _transliterateDigits(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    final character = String.fromCharCode(rune);
    final arabicIndex = _arabicIndicDigits.indexOf(character);
    final persianIndex = _persianDigits.indexOf(character);
    final digitIndex = arabicIndex >= 0 ? arabicIndex : persianIndex;
    buffer.write(digitIndex >= 0 ? digitIndex : character);
  }
  return buffer.toString();
}

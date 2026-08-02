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
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    var rest = digitsOnly;
    if (rest.startsWith('961')) {
      rest = rest.substring(3);
    } else if (rest.startsWith('0')) {
      rest = rest.substring(1);
    }
    if (rest.length > nationalDigitCount) {
      rest = rest.substring(0, nationalDigitCount);
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

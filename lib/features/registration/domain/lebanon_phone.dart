/// Lebanese phone-number value object and normaliser.
///
/// Lebanon's national mobile format is 8 digits prefixed with `+961`. The
/// auth-service contract (T-mobile-002 / JEEB-55) expects E.164 — i.e.
/// `+961XXXXXXXX` — on every OTP send/verify call. This class is the single
/// place that knows how to coerce user input (which may include the +961
/// prefix, a leading 0, spaces, dashes, or punctuation) into that canonical
/// form, and how to validate it.
class LebanonPhone {
  const LebanonPhone._(this.digits);

  /// Eight national digits, with no prefix and no separators.
  final String digits;

  /// E.164 representation: `+961XXXXXXXX`.
  String get e164 => '$dialCode$digits';

  /// The fixed Lebanese dial code.
  static const String dialCode = '+961';

  /// Maximum length of the national subscriber number (mobile).
  static const int nationalDigitCount = 8;

  /// Minimum length of a valid Lebanese national subscriber number. Some valid
  /// numbers (incl. the +9613000002 seed) carry only 7 national digits, so we
  /// accept 7 or 8.
  static const int minNationalDigitCount = 7;

  /// Strips everything that isn't a digit, then drops a `+961`, `961`, or a
  /// leading `0` that callers commonly paste. Returns the up-to-8 trailing
  /// national digits. Anything longer is truncated — the UI relies on the
  /// max-length contract and never feeds us more than that.
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

  /// Returns a [LebanonPhone] if [raw] normalises to a valid Lebanese national
  /// number (7 or 8 digits), otherwise `null`. Callers use this for the
  /// "ready to send" gate on the phone-entry CTA.
  static LebanonPhone? tryParse(String raw) {
    final n = normalise(raw);
    if (n.length < minNationalDigitCount || n.length > nationalDigitCount) {
      return null;
    }
    return LebanonPhone._(n);
  }

  /// Display form with the prefix: `+961 XXXXXXXX`. Used in the OTP step's
  /// subtitle ("we sent a code to ...").
  String get displayWithPrefix => '$dialCode $digits';
}

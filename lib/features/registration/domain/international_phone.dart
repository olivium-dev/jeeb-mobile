import 'registration_country_metadata.dart';

final RegExp _allowedPhoneCharacters = RegExp(r'^[+0-9\s\-()]*$');
final RegExp _formattingCharacters = RegExp(r'[\s\-()]');
final RegExp _asciiDigits = RegExp(r'^[0-9]+$');

const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
const String _persianDigits = '۰۱۲۳۴۵۶۷۸۹';
const int _e164MaxDigits = 15;

/// Registration-scoped phone value object whose only wire form is E.164.
class InternationalPhone {
  const InternationalPhone._({
    required this.countryCode,
    required this.dialCode,
    required this.nationalDigits,
  });

  final String countryCode;
  final String dialCode;
  final String nationalDigits;

  String get e164 => '$dialCode$nationalDigits';

  String get displayWithPrefix => '$dialCode $nationalDigits';

  /// Normalizes display punctuation and localized digits without truncating.
  static String normaliseForEditing({
    required String countryCode,
    required String raw,
  }) {
    final ascii = _transliterateDigits(raw).trim();
    final compact = _compact(ascii);
    if (compact == null) return ascii;
    final country = RegistrationCountryCatalog.byCode(countryCode);
    if (country == null) return compact;
    return _nationalDigits(compact, country) ?? compact;
  }

  static InternationalPhone? tryParse({
    required String countryCode,
    required String raw,
  }) {
    final country = RegistrationCountryCatalog.byCode(countryCode);
    if (country == null) return null;
    final compact = _compact(_transliterateDigits(raw).trim());
    if (compact == null) return null;
    final national = _nationalDigits(compact, country);
    if (!_isValidNational(national, country)) return null;
    final phone = InternationalPhone._(
      countryCode: country.code,
      dialCode: country.dialCode,
      nationalDigits: national!,
    );
    return _digitCount(phone.e164) <= _e164MaxDigits ? phone : null;
  }

  static bool _isValidNational(
    String? national,
    RegistrationCountryMetadata country,
  ) {
    if (national == null || !_asciiDigits.hasMatch(national)) return false;
    return national.length >= country.minNationalDigits &&
        national.length <= country.maxNationalDigits;
  }
}

String? _compact(String value) {
  if (!_allowedPhoneCharacters.hasMatch(value)) return null;
  final compact = value.replaceAll(_formattingCharacters, '');
  if ('+'.allMatches(compact).length > 1) return null;
  if (compact.contains('+') && !compact.startsWith('+')) return null;
  return compact;
}

String? _nationalDigits(String compact, RegistrationCountryMetadata country) {
  if (compact.startsWith('+')) {
    if (!compact.startsWith(country.dialCode)) return null;
    return compact.substring(country.dialCode.length);
  }
  final prefix = country.nationalPrefix;
  if (prefix == null || !compact.startsWith(prefix)) return compact;
  return compact.substring(prefix.length);
}

int _digitCount(String value) => value.codeUnits.where(_isAsciiDigit).length;

bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

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

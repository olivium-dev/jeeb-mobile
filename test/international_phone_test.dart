import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/registration/domain/international_phone.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_country_metadata.dart';

void main() {
  group('InternationalPhone.tryParse', () {
    test('canonicalizes supported Lebanon, Netherlands, and US formats', () {
      expect(_parse('LB', '71 123 456')?.e164, '+96171123456');
      expect(_parse('NL', '6 1234 5678')?.e164, '+31612345678');
      expect(_parse('US', '(415) 555-0100')?.e164, '+14155550100');
    });

    test('normalizes declared LB and NL national trunk prefixes', () {
      expect(_parse('LB', '03 123 456')?.e164, '+9613123456');
      expect(_parse('NL', '06 1234 5678')?.e164, '+31612345678');
    });

    test('does not strip a trunk zero where metadata does not declare one', () {
      expect(_parse('IT', '06 6982 0000')?.e164, '+390669820000');
    });

    test('transliterates Arabic-Indic and Persian digits', () {
      expect(_parse('LB', '٧١١٢٣٤٥٦')?.e164, '+96171123456');
      expect(_parse('NL', '۶۱۲۳۴۵۶۷۸')?.e164, '+31612345678');
    });

    test('accepts an explicit E.164 value matching the selected country', () {
      expect(_parse('NL', '+31 6 1234 5678')?.e164, '+31612345678');
    });

    test('rejects an explicit E.164 value for a different country', () {
      expect(_parse('LB', '+31 6 1234 5678'), isNull);
    });

    test('rejects invalid characters, misplaced plus, and short values', () {
      expect(_parse('US', '415CALLNOW'), isNull);
      expect(_parse('US', '415+5550100'), isNull);
      expect(_parse('NL', '6123'), isNull);
    });

    test('never truncates and enforces the E.164 15-digit ceiling', () {
      const overlong = '1234567890123456';
      expect(
        InternationalPhone.normaliseForEditing(
          countryCode: 'US',
          raw: overlong,
        ),
        overlong,
      );
      expect(_parse('US', overlong), isNull);
    });
  });

  test(
    'country catalog is complete, unique, localized, and defaults to LB',
    () {
      const countries = RegistrationCountryCatalog.all;
      expect(countries, hasLength(243));
      expect(countries.map((country) => country.code).toSet(), hasLength(243));
      expect(
        countries.every((country) => country.dialCode.startsWith('+')),
        isTrue,
      );
      expect(
        countries.every((country) => country.englishName.isNotEmpty),
        isTrue,
      );
      expect(
        countries.every((country) => country.arabicName.isNotEmpty),
        isTrue,
      );
      expect(RegistrationCountryCatalog.defaultCountry.code, 'LB');
    },
  );
}

InternationalPhone? _parse(String countryCode, String raw) =>
    InternationalPhone.tryParse(countryCode: countryCode, raw: raw);

import 'package:flutter/widgets.dart';
import 'package:omds/omds.dart';

import '../domain/registration_country_metadata.dart';

/// Adapts registration-owned metadata to the stock OMDS country model.
abstract final class RegistrationCountryOptions {
  static final List<OmdsCountry> _english = _build('en');
  static final List<OmdsCountry> _arabic = _build('ar');

  static List<OmdsCountry> forLocale(Locale locale) =>
      locale.languageCode == 'ar' ? _arabic : _english;

  static OmdsCountry selectedFor({
    required Locale locale,
    required String countryCode,
  }) {
    final countries = forLocale(locale);
    return countries.firstWhere(
      (country) => country.code == countryCode,
      orElse: () => countries.firstWhere(_isDefaultCountry),
    );
  }

  static List<OmdsCountry> _build(String languageCode) => List.unmodifiable(
    RegistrationCountryCatalog.all.map(
      (country) => OmdsCountry(
        name: country.localizedName(languageCode),
        code: country.code,
        dialCode: country.dialCode,
        flag: country.flag,
      ),
    ),
  );

  static bool _isDefaultCountry(OmdsCountry country) =>
      country.code == RegistrationCountryCatalog.defaultCountryCode;
}

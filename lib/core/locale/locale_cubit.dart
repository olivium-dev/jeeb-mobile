import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// Cubit owning the active app [Locale].
///
/// Resolution order on boot:
/// 1. Persisted user choice in [SharedPreferences] (key `_kLocalePrefKey`).
/// 2. The device locale reported by [PlatformDispatcher], if supported.
/// 3. Hard fallback to English.
///
/// Switching at runtime is a single [setLocale] call — no app restart.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit({
    required SharedPreferences prefs,
    Locale Function()? deviceLocaleProvider,
  })  : _prefs = prefs,
        _deviceLocaleProvider =
            deviceLocaleProvider ?? _defaultDeviceLocaleProvider,
        super(_resolveInitial(prefs, deviceLocaleProvider));

  static const String _kLocalePrefKey = 'app.locale.languageCode';

  final SharedPreferences _prefs;
  final Locale Function() _deviceLocaleProvider;

  static Locale _defaultDeviceLocaleProvider() =>
      PlatformDispatcher.instance.locale;

  /// Debug-only locale override (`--dart-define=JEEB_FORCE_LOCALE=ar`), matching
  /// the splash-host override in `jeeb_bootstrap.dart`. Lets the running app
  /// (not just the pre-bootstrap splash) be captured in a fixed locale on an
  /// emulator that can't change its system locale. No-op in release builds and
  /// when unset; the normal prefs → device → English resolution is untouched.
  static const String _kForcedLocale =
      kDebugMode ? String.fromEnvironment('JEEB_FORCE_LOCALE') : '';

  static Locale _resolveInitial(
    SharedPreferences prefs,
    Locale Function()? deviceLocaleProvider,
  ) {
    if (_kForcedLocale.isNotEmpty && _isSupported(_kForcedLocale)) {
      return Locale(_kForcedLocale);
    }
    final saved = prefs.getString(_kLocalePrefKey);
    if (saved != null && _isSupported(saved)) {
      return Locale(saved);
    }
    final device = (deviceLocaleProvider ?? _defaultDeviceLocaleProvider)();
    if (_isSupported(device.languageCode)) {
      return Locale(device.languageCode);
    }
    return const Locale('en');
  }

  static bool _isSupported(String languageCode) => AppLocalizations
      .supportedLocales
      .any((l) => l.languageCode == languageCode);

  /// Switch to [locale]. No-op if equal to the current value.
  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) {
      debugPrint('LocaleCubit: ignoring unsupported locale $locale');
      return;
    }
    if (locale.languageCode == state.languageCode) return;
    emit(Locale(locale.languageCode));
    await _prefs.setString(_kLocalePrefKey, locale.languageCode);
  }

  /// Reset to the device-reported locale (used by the "follow system" toggle).
  Future<void> resetToDeviceLocale() async {
    final device = _deviceLocaleProvider();
    final next =
        _isSupported(device.languageCode) ? device.languageCode : 'en';
    emit(Locale(next));
    await _prefs.remove(_kLocalePrefKey);
  }
}

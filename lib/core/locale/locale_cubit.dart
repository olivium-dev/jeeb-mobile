import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../dev_seam/dev_seam.dart';
import 'language_preference_repository.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit({
    required SharedPreferences prefs,
    Locale Function()? deviceLocaleProvider,
    LanguagePreferenceRepository? remote,
  })  : _prefs = prefs,
        _deviceLocaleProvider =
            deviceLocaleProvider ?? _defaultDeviceLocaleProvider,
        _remote = remote,
        super(_resolveInitial(prefs, deviceLocaleProvider));

  static const String _kLocalePrefKey = 'app.locale.languageCode';

  final SharedPreferences _prefs;
  final Locale Function() _deviceLocaleProvider;

  final LanguagePreferenceRepository? _remote;

  static Locale _defaultDeviceLocaleProvider() =>
      PlatformDispatcher.instance.locale;

  static String get _forcedLocale =>
      kDebugMode ? DevSeam.current.forcedLocale : '';

  static Locale _resolveInitial(
    SharedPreferences prefs,
    Locale Function()? deviceLocaleProvider,
  ) {
    final forced = _forcedLocale;
    if (forced.isNotEmpty && _isSupported(forced)) {
      return Locale(forced);
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

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) {
      debugPrint('LocaleCubit: ignoring unsupported locale $locale');
      return;
    }
    if (locale.languageCode == state.languageCode) return;
    emit(Locale(locale.languageCode));
    await _prefs.setString(_kLocalePrefKey, locale.languageCode);
    await _pushRemote(locale.languageCode);
  }

  Future<void> resetToDeviceLocale() async {
    final device = _deviceLocaleProvider();
    final next =
        _isSupported(device.languageCode) ? device.languageCode : 'en';
    emit(Locale(next));
    await _prefs.remove(_kLocalePrefKey);
    await _pushRemote(next);
  }

  Future<void> syncFromServer() async {
    final remote = _remote;
    if (remote == null) return;
    try {
      final code = await remote.fetch();
      if (code == null || !_isSupported(code)) return;
      if (code == state.languageCode) return;
      emit(Locale(code));
      await _prefs.setString(_kLocalePrefKey, code);
    } on Object {
      // Best effort: the locale already changed in memory; a failed write
      // must not undo it.
    }
  }

  Future<void> _pushRemote(String languageCode) async {
    final remote = _remote;
    if (remote == null) return;
    try {
      await remote.save(languageCode);
    } on Object {
      // Best effort: the remote copy is a convenience, not the source.
    }
  }
}

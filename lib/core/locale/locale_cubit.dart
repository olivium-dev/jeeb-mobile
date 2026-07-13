import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../dev_seam/dev_seam.dart';
import 'language_preference_repository.dart';

/// Cubit owning the active app [Locale].
///
/// Resolution order on boot:
/// 1. Persisted user choice in [SharedPreferences] (key `_kLocalePrefKey`).
/// 2. The device locale reported by [PlatformDispatcher], if supported.
/// 3. Hard fallback to English.
///
/// Switching at runtime is a single [setLocale] call — no app restart.
///
/// SERVER PERSISTENCE (JEBV4-205, E10): when a [LanguagePreferenceRepository]
/// is supplied, every language WRITE is mirrored to the shared
/// remote-user-preferences service (GR-2 store — never user-management, never a
/// gateway-local store), and [syncFromServer] re-hydrates the saved language
/// after login. The SharedPreferences entry stays as an offline-first cache;
/// the server value is the system of record, so the choice survives a reinstall
/// (the local cache is wiped, `syncFromServer` restores it). The remote is
/// best-effort: a failed round trip never breaks an offline switch.
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

  /// Optional server-side store for the language preference (JEBV4-205). Null in
  /// tests / unauthenticated contexts, in which case persistence is local-only.
  final LanguagePreferenceRepository? _remote;

  static Locale _defaultDeviceLocaleProvider() =>
      PlatformDispatcher.instance.locale;

  /// Debug-only locale override, resolved at RUNTIME from [DevSeam] (replaces
  /// the compile-time `JEEB_FORCE_LOCALE`; the dart-define still feeds it via
  /// the seam fallback). Lets the running app be captured in a fixed locale on
  /// an emulator that can't change its system locale. Empty in release builds
  /// and when unset; the normal prefs → device → English resolution is
  /// untouched.
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

  /// Switch to [locale]. No-op if equal to the current value.
  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) {
      debugPrint('LocaleCubit: ignoring unsupported locale $locale');
      return;
    }
    if (locale.languageCode == state.languageCode) return;
    emit(Locale(locale.languageCode));
    await _prefs.setString(_kLocalePrefKey, locale.languageCode);
    // JEBV4-205: mirror the choice to the remote-user-preferences store so it
    // survives a reinstall. Best-effort — an offline switch already took effect
    // locally above and must never surface an error.
    await _pushRemote(locale.languageCode);
  }

  /// Reset to the device-reported locale (used by the "follow system" toggle).
  Future<void> resetToDeviceLocale() async {
    final device = _deviceLocaleProvider();
    final next =
        _isSupported(device.languageCode) ? device.languageCode : 'en';
    emit(Locale(next));
    await _prefs.remove(_kLocalePrefKey);
    // JEBV4-205: "follow system" resolves to a concrete supported code; persist
    // THAT server-side so the account reflects the active language everywhere.
    await _pushRemote(next);
  }

  /// JEBV4-205: re-hydrate the language from the remote-user-preferences store.
  /// Call after login (identity known). A server value overrides the local
  /// cache — the DoD "language persists across reinstall" case, where the local
  /// cache was wiped but the server still holds the user's choice. Best-effort:
  /// any transport/upstream failure leaves the current locale untouched.
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
      // Degrade to the local/device resolution — never crash the post-login
      // path on a preferences round trip.
    }
  }

  /// Best-effort server write for [languageCode]; swallows all failures so a
  /// local switch is never blocked by an offline/failing preferences service.
  Future<void> _pushRemote(String languageCode) async {
    final remote = _remote;
    if (remote == null) return;
    try {
      await remote.save(languageCode);
    } on Object {
      // Offline-first: the local cache already holds the choice.
    }
  }
}

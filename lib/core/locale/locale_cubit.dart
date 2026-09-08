import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../dev_seam/dev_seam.dart';
import '../diagnostics/diag.dart';
import '../network/app_failure.dart';
import '../session/auth_loss_signals.dart';
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

  final ValueNotifier<bool> _pendingPushNotifier = ValueNotifier<bool>(false);

  /// LANG-01: true while a local language change has not reached the server, so
  /// the screen can say so and [syncFromServer] will not revert it.
  bool get hasPendingLanguagePush => _pendingPushNotifier.value;

  /// The same flag as a listenable — the cubit's own state is the [Locale],
  /// which does not change when only the push status does.
  ValueListenable<bool> get languagePushPending => _pendingPushNotifier;

  /// One auth-loss signal per cubit: the owed-push retry runs on every sync.
  bool _signalledAuthLoss = false;

  bool get _pendingPush => _pendingPushNotifier.value;

  set _pendingPush(bool value) => _pendingPushNotifier.value = value;

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
    // The server's copy is STALE while our own push is still owed; reading it
    // here is what used to revert an offline language change.
    if (_pendingPush) {
      await _pushRemote(state.languageCode);
      return;
    }
    try {
      final code = await remote.fetch();
      if (code == null || !_isSupported(code)) return;
      if (code == state.languageCode) return;
      emit(Locale(code));
      await _prefs.setString(_kLocalePrefKey, code);
    } on LanguagePreferenceException catch (e) {
      _reportLanguageFailure('language_sync_failed', e);
    } catch (e) {
      Diag.event('language_sync_failed', {'kind': AppFailure.of(e).kind.name});
    }
  }

  Future<void> _pushRemote(String languageCode) async {
    final remote = _remote;
    if (remote == null) return;
    try {
      await remote.save(languageCode);
      _pendingPush = false;
    } on LanguagePreferenceException catch (e) {
      _pendingPush = true;
      _reportLanguageFailure('language_push_failed', e);
    } catch (e) {
      _pendingPush = true;
      Diag.event('language_push_failed', {'kind': AppFailure.of(e).kind.name});
    }
  }

  /// App-scoped in production. A widget listening to [languagePushPending]
  /// must be disposed BEFORE the cubit (tests: pump an empty tree first).
  @override
  Future<void> close() {
    _pendingPushNotifier.dispose();
    return super.close();
  }

  /// §5.10: an unauthorized preference write is a session problem, not a
  /// language one — it belongs on the session lane, not in a silent catch.
  void _reportLanguageFailure(String event, LanguagePreferenceException e) {
    Diag.event(event, {'failure': e.failure.name});
    if (e.failure != LanguagePreferenceFailure.unauthorized) return;
    // Latched: `syncFromServer` retries the owed push on every sync, and each
    // signal flips SessionCubit to unauthenticated.
    if (_signalledAuthLoss) return;
    _signalledAuthLoss = true;
    AuthLossSignals.instance.signal(reason: AuthLossReason.sessionExpired);
  }
}

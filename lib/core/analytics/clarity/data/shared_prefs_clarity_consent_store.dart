import 'package:shared_preferences/shared_preferences.dart';

import '../domain/clarity_consent.dart';
import '../domain/clarity_consent_store.dart';

typedef ClarityPreferenceReader = Object? Function(String key);
typedef ClarityPreferenceWriter =
    Future<bool> Function(String key, String value);
typedef ClarityPreferenceRemover = Future<bool> Function(String key);

final class SharedPrefsClarityConsentStore implements ClarityConsentStore {
  SharedPrefsClarityConsentStore(
    SharedPreferences preferences, {
    ClarityPreferenceReader? reader,
    ClarityPreferenceWriter? writer,
    ClarityPreferenceRemover? remover,
  }) : _reader = reader ?? preferences.get,
       _writer = writer ?? preferences.setString,
       _remover = remover ?? preferences.remove;

  static const String consentPreferenceName = 'privacy.clarity_consent.v1';

  static const String _granted = 'granted';
  static const String _denied = 'denied';

  final ClarityPreferenceReader _reader;
  final ClarityPreferenceWriter _writer;
  final ClarityPreferenceRemover _remover;

  @override
  Future<ClarityConsent> read() async {
    try {
      final stored = _reader(consentPreferenceName);
      if (stored == _granted) {
        // A grant is valid only for the current process. Never rehydrate it
        // after a restart: even if best-effort cleanup fails, returning
        // unknown keeps capture closed until the user opts in again.
        try {
          await _remover(consentPreferenceName);
        } catch (_) {
          // Fail closed below.
        }
        return ClarityConsent.unknown;
      }
      return stored == _denied ? ClarityConsent.denied : ClarityConsent.unknown;
    } catch (_) {
      return ClarityConsent.unknown;
    }
  }

  @override
  Future<bool> write(ClarityConsent consent) async {
    if (consent == ClarityConsent.unknown) return clear();
    final value = switch (consent) {
      ClarityConsent.granted => _granted,
      ClarityConsent.denied => _denied,
      ClarityConsent.unknown => throw StateError('unreachable'),
    };
    try {
      // Remove a prior grant before recording denial. If the second write
      // fails, the next launch reads unknown and therefore remains off.
      // If removal itself fails, still try to overwrite the stale grant with
      // an explicit denial. A stale grant is also ignored by read().
      if (consent == ClarityConsent.denied) await clear();
      return await _writer(consentPreferenceName, value);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      if (_reader(consentPreferenceName) == null) return true;
      return await _remover(consentPreferenceName);
    } catch (_) {
      return false;
    }
  }
}

/// Port for the SERVER-persisted app-language preference (JEBV4-205, E10).
///
/// GR-2 disposition (ticket JEBV4-205): the language preference is user-scoped
/// state, so it persists through the shared **remote-user-preferences** service
/// — NEVER user-management (GR-2) and NEVER a gateway-local store (GR-3). The
/// concrete [DioLanguagePreferenceRepository] therefore talks ONLY to the
/// gateway's `/api/UserPreferences/preferences*` BFF (backed by
/// `ServiceRemoteUserPreferencesClient`), and issues ZERO writes to
/// `/api/User/*` (user-management) or any gateway persistence.
///
/// The device-local [LocaleCubit] SharedPreferences cache is an offline-first
/// mirror of this server value, not the system of record: on a fresh install
/// the local cache is empty, so [fetch] re-hydrates the user's saved language
/// from the server (DoD: "language persists across reinstall").
abstract class LanguagePreferenceRepository {
  /// Returns the server-persisted language code (e.g. `en` / `ar`), or `null`
  /// when the user has never chosen one (upstream 404 / unset). Throws
  /// [LanguagePreferenceException] on a transport/upstream error so the caller
  /// can degrade to the local cache.
  Future<String?> fetch();

  /// Persists [languageCode] as the user's language preference on the server.
  /// Throws [LanguagePreferenceException] on failure (the caller keeps the
  /// local cache regardless, so a switch still works offline).
  Future<void> save(String languageCode);
}

/// Failure classes for a language-preference round trip, mirroring the sibling
/// repository ports (e.g. `DisplayNameFailure`).
enum LanguagePreferenceFailure { network, unauthorized, unknown }

/// Typed exception thrown by [LanguagePreferenceRepository].
class LanguagePreferenceException implements Exception {
  const LanguagePreferenceException(this.failure, [this.message]);

  final LanguagePreferenceFailure failure;
  final String? message;

  @override
  String toString() =>
      'LanguagePreferenceException(${failure.name}${message == null ? '' : ': $message'})';
}

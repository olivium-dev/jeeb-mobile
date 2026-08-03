abstract class LanguagePreferenceRepository {
  Future<String?> fetch();

  Future<void> save(String languageCode);
}

enum LanguagePreferenceFailure { network, unauthorized, unknown }

class LanguagePreferenceException implements Exception {
  const LanguagePreferenceException(this.failure, [this.message]);

  final LanguagePreferenceFailure failure;
  final String? message;

  @override
  String toString() =>
      'LanguagePreferenceException(${failure.name}${message == null ? '' : ': $message'})';
}

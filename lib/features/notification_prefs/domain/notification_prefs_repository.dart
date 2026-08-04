import 'notification_prefs_model.dart';

enum NotificationPrefsFailure { network, unknown }

class NotificationPrefsRepositoryException implements Exception {
  const NotificationPrefsRepositoryException(this.failure, [this.message]);

  final NotificationPrefsFailure failure;
  final String? message;

  @override
  String toString() =>
      'NotificationPrefsRepositoryException($failure, $message)';
}

abstract class NotificationPrefsRepository {
  Future<NotificationPrefs> fetch();

  Future<NotificationPrefs> save(NotificationCategoryPrefs categories);
}

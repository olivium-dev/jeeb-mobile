import '../../../core/network/app_failure.dart';
import 'notification_prefs_model.dart';

enum NotificationPrefsFailure {
  network,

  /// 401/403 — the session, not the connection.
  unauthorized,

  /// 5xx.
  serverError,

  /// A 200 whose body carries neither shape: silently reading it as
  /// "everything on" would flip switches the user never touched (F22).
  malformed,

  unknown,
}

class NotificationPrefsRepositoryException implements Exception {
  const NotificationPrefsRepositoryException(
    this.failure, [
    this.message,
    this.appFailure,
  ]);

  final NotificationPrefsFailure failure;
  final String? message;

  /// The classified transport failure, so `failureCopy` keeps `Retry-After`,
  /// `problem.detail` and `offline` instead of a re-synthesised 500.
  final AppFailure? appFailure;

  @override
  String toString() =>
      'NotificationPrefsRepositoryException($failure, $message)';
}

abstract class NotificationPrefsRepository {
  Future<NotificationPrefs> fetch();

  Future<NotificationPrefs> save(NotificationCategoryPrefs categories);
}

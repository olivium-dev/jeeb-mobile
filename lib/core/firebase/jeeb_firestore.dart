import 'package:cloud_firestore/cloud_firestore.dart';

/// The one place the app decides which Firestore database chat reads from.
/// Default pinned to `contracts/jeeb-firebase-v1.json`.`firestoreDatabaseId`.
abstract final class JeebFirestore {
  /// Firestore's own name for the unnamed database.
  static const String defaultDatabaseId = '(default)';

  /// A build may restate the canonical contract, but cannot select another DB.
  static const String databaseId = String.fromEnvironment(
    'JEEB_FIRESTORE_DATABASE_ID',
    defaultValue: '(default)',
  );

  /// Reject configuration drift instead of silently choosing a different DB.
  static String resolveDatabaseId(String value) {
    if (value != defaultDatabaseId) {
      throw StateError('Jeeb requires the canonical Firestore database.');
    }
    return defaultDatabaseId;
  }

  static String get effectiveDatabaseId => resolveDatabaseId(databaseId);

  static bool get usesDefaultDatabase =>
      effectiveDatabaseId == defaultDatabaseId;

  /// Preserve the diagnostic seam while using only Firebase's default DB.
  static FirebaseFirestore instance() {
    resolveDatabaseId(databaseId);
    return FirebaseFirestore.instance;
  }
}

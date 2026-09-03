import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// The one place the app decides which Firestore database chat reads from.
/// Default pinned to `contracts/jeeb-firebase-v1.json`.`firestoreDatabaseId`.
abstract final class JeebFirestore {
  /// Firestore's own name for the unnamed database.
  static const String defaultDatabaseId = '(default)';

  /// Contract default; overridable per build for a named-database backend.
  static const String databaseId = String.fromEnvironment(
    'JEEB_FIRESTORE_DATABASE_ID',
    defaultValue: '(default)',
  );

  /// An empty define (an unset CI variable interpolated into a build command)
  /// must not reach native as database "" — `instanceFor` passes '' through.
  static String resolveDatabaseId(String value) =>
      value.trim().isEmpty ? defaultDatabaseId : value;

  static String get effectiveDatabaseId => resolveDatabaseId(databaseId);

  static bool get usesDefaultDatabase =>
      effectiveDatabaseId == defaultDatabaseId;

  /// `instanceFor(databaseId: '(default)')` is byte-identical to `.instance`
  /// (same `'${app.name}|(default)'` cache key), so the default is a no-op.
  static FirebaseFirestore instance() => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: effectiveDatabaseId,
  );
}

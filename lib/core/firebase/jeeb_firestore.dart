import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// The ONE place the app decides which Firestore database chat reads from.
///
/// chat-service made the database id a free variable (`Firestore__DatabaseId`,
/// 2026-08-19) while mobile still hardcoded `FirebaseFirestore.instance`, i.e.
/// `(default)`. A backend move to a named database was therefore invisible to
/// the app. The default here is pinned to `contracts/jeeb-firebase-v1.json`
/// (`firestoreDatabaseId`) and asserted by `tool/firebase_doctor.sh` and
/// `test/core/firebase/jeeb_firestore_test.dart`.
abstract final class JeebFirestore {
  /// Firestore's own name for the unnamed database.
  static const String defaultDatabaseId = '(default)';

  /// Contract default; overridable per build for a named-database backend.
  static const String databaseId = String.fromEnvironment(
    'JEEB_FIRESTORE_DATABASE_ID',
    defaultValue: '(default)',
  );

  static bool get usesDefaultDatabase => databaseId == defaultDatabaseId;

  /// `instanceFor(databaseId: '(default)')` is byte-identical to `.instance`
  /// (same `'${app.name}|(default)'` cache key), so the default is a no-op.
  static FirebaseFirestore instance() => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: databaseId,
  );
}

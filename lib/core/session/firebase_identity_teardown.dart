import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../diagnostics/diag.dart';














































typedef FirebaseIdentityTeardown = Future<void> Function();










Future<void> signOutFirebaseIdentity() async {
  try {
    if (Firebase.apps.isEmpty) return;
    await FirebaseAuth.instance.signOut();
    Diag.event('firebase_identity_teardown', const <String, Object?>{
      'result': 'signed_out',
    });
  } catch (error) {
    Diag.event('firebase_identity_teardown', <String, Object?>{
      'result': 'failed',
      'error': error.runtimeType.toString(),
    });
  }
}

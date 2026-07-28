import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../diagnostics/diag.dart';

/// Ends the app's FIREBASE session — the second identity this app holds.
///
/// # Why this exists
///
/// Jeeb signs in to Firebase with a CUSTOM TOKEN minted from the Jeeb JWT
/// (`FirebaseCustomTokenIdentity`), so that `request.auth.uid` in a Firestore
/// security rule means the same subject as `AuthorId` on a chat message and
/// `Participants[].UserId` on a conversation. That is the whole basis on which a
/// device is allowed to read `Conversations/{id}/Messages` directly.
///
/// What `signInWithCustomToken` returns is NOT bounded by the custom token's
/// lifetime: it is a Firebase session the SDK then refreshes on its own,
/// indefinitely, without ever calling the gateway again. So clearing the Jeeb
/// keystore does not end it. Before this seam existed,
/// `grep -rn "FirebaseAuth.instance.signOut" lib/` returned ZERO hits while
/// `DioAccountService.signOut` / `DioAccountSessionTerminator.logout` cleared
/// only the Jeeb tokens — meaning a signed-out (or switched) user left a live
/// Firebase identity behind, still authorised by the membership rule for every
/// conversation the PREVIOUS user was a participant of.
///
/// **The invariant: the Firebase identity must never outlive the Jeeb keystore
/// clear.** Every call site that clears the keystore calls this.
///
/// # Fail-soft by contract
///
/// `FirebaseAuth.instance` THROWS when no Firebase app has been initialised —
/// which is a legitimate state here, because `Firebase.initializeApp()` runs in
/// the deferred post-first-frame phase behind a timeout (`bootstrap.dart`) and
/// can fail outright. `Firebase.apps` is the cheap, synchronous check that does
/// not throw, so it is asked first. Nothing here may propagate: a failed
/// Firebase sign-out must never strand a user in a signed-in shell, which is the
/// same fail-safe rule the Jeeb logout already follows.
typedef FirebaseIdentityTeardown = Future<void> Function();

/// The production [FirebaseIdentityTeardown]. Signs out of `FirebaseAuth` when —
/// and only when — a Firebase app actually exists. Never throws.
///
/// NOTE FOR ANYONE READING A GREEN TEST RUN: `Firebase.apps` is EMPTY in every
/// widget test in this repo, so in-suite this function returns at the first line
/// and `FirebaseAuth.instance` is never touched. A test that exercises the
/// default therefore proves only "it does not throw with no app" — it cannot
/// prove the sign-out happens. The call sites take an injectable seam precisely
/// so the "was it called" half can be asserted for real.
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

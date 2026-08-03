import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/chat_firebase_identity.dart';

class FirebaseCustomTokenIdentity implements ChatFirebaseIdentity {
  FirebaseCustomTokenIdentity({
    required FirebaseAuth auth,
    required ChatFirebaseTokenMinter minter,
    required String jeebUserId,
  })  : _auth = auth,
        _minter = minter,
        _jeebUserId = jeebUserId;

  final FirebaseAuth _auth;
  final ChatFirebaseTokenMinter _minter;

  final String _jeebUserId;

  @override
  Future<String?> ensureSignedIn() async {
    if (_jeebUserId.isEmpty) {
      Diag.event('chat_firebase_identity', <String, Object?>{
        'result': 'no_jeeb_user',
      });
      return null;
    }
    try {
      final existing = _auth.currentUser;
      if (existing != null) {
        if (existing.uid == _jeebUserId) return _jeebUserId;
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'uid_mismatch',
        });
        await _auth.signOut();
      }
      final token = await _minter.mintCustomToken();
      if (token == null || token.isEmpty) {
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'no_token',
        });
        return null;
      }
      final credential = await _auth.signInWithCustomToken(token);
      final user = credential.user;
      if (user == null) {
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'no_user',
        });
        return null;
      }
      if (user.uid != _jeebUserId) {
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'minted_uid_mismatch',
        });
        await _auth.signOut();
        return null;
      }
      Diag.event('chat_firebase_identity', <String, Object?>{
        'result': 'signed_in',
      });
      return _jeebUserId;
    } catch (error) {
      Diag.event('chat_firebase_identity', <String, Object?>{
        'result': 'failed',
        'error': error.runtimeType.toString(),
      });
      return null;
    }
  }
}

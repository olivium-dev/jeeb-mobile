import 'package:shared_preferences/shared_preferences.dart';

/// Stub created by sanity-build pass (2026-05-17).
///
/// Wave-2-4 PR drift: app.dart imports this path, but the actual hash/PIN
/// logic was never committed. This stub satisfies the constructor signature
/// so the build links. Real implementation is T-mobile-005 follow-up.
class SharedPrefsPinRepository {
  SharedPrefsPinRepository({required SharedPreferences prefs}) : _prefs = prefs;

  // ignore: unused_field
  final SharedPreferences _prefs;

  Future<bool> hasPin() async => false;
  Future<void> setPin(String pin) async {}
  Future<bool> verifyPin(String pin) async => false;
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_role.dart';

/// Cubit owning the active [UserRole] (client vs jeeber).
///
/// Persisted to [SharedPreferences] so the user's last-active surface is
/// preserved across launches.
class RoleCubit extends Cubit<UserRole> {
  RoleCubit({required SharedPreferences prefs})
      : _prefs = prefs,
        super(UserRole.fromStorage(prefs.getString(_kRolePrefKey)));

  static const String _kRolePrefKey = 'app.role';

  final SharedPreferences _prefs;

  Future<void> setRole(UserRole role) async {
    if (role == state) return;
    emit(role);
    await _prefs.setString(_kRolePrefKey, role.storageKey);
  }

  Future<void> toggle() async {
    final next =
        state == UserRole.client ? UserRole.jeeber : UserRole.client;
    await setRole(next);
  }
}

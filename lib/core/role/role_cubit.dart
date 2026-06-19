import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_role.dart';

/// Cubit owning the active [UserRole] (client vs jeeber).
///
/// Persisted to [SharedPreferences] so the user's last-active surface is
/// preserved across launches.
class RoleCubit extends Cubit<UserRole> {
  RoleCubit({required SharedPreferences prefs, UserRole? initialRole})
      : _prefs = prefs,
        super(
          initialRole ?? UserRole.fromStorage(prefs.getString(rolePrefKey)),
        );

  /// SharedPreferences key for the active role. Public so the debug-only
  /// [SessionSeamBootstrap] seeds the SAME key this cubit reads in its
  /// constructor (single source of truth — no parallel role store).
  static const String rolePrefKey = 'app.role';

  final SharedPreferences _prefs;

  Future<void> setRole(UserRole role) async {
    if (role == state) return;
    emit(role);
    await _prefs.setString(rolePrefKey, role.storageKey);
  }

  Future<void> toggle() async {
    final next =
        state == UserRole.client ? UserRole.jeeber : UserRole.client;
    await setRole(next);
  }
}

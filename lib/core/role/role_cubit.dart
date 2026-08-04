import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/diag.dart';
import 'user_role.dart';

class RoleCubit extends Cubit<UserRole> {
  RoleCubit({required SharedPreferences prefs, UserRole? initialRole})
      : _prefs = prefs,
        super(
          initialRole ?? UserRole.fromStorage(prefs.getString(rolePrefKey)),
        );

  static const String rolePrefKey = 'app.role';

  final SharedPreferences _prefs;

  Future<void> setRole(UserRole role) async {
    if (role == state) return;
    Diag.event('role_switch', <String, Object?>{
      'from': state.storageKey,
      'to': role.storageKey,
    });
    emit(role);
    await _prefs.setString(rolePrefKey, role.storageKey);
  }

  Future<void> toggle() async {
    final next =
        state == UserRole.client ? UserRole.jeeber : UserRole.client;
    await setRole(next);
  }
}

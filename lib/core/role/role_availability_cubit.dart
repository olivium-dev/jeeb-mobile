import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleAvailabilityCubit extends Cubit<RoleAvailability> {
  RoleAvailabilityCubit([
    super.initial = const RoleAvailability(),
    SharedPreferences? prefs,
  ]) : _prefs = prefs;

  /// Snapshot the FCM background isolate reads to audience-gate inbox rows.
  static const String availableRolesPrefKey = 'app.available_roles';

  final SharedPreferences? _prefs;

  void setAvailableRoles(List<String> roles) {
    final next = RoleAvailability(roles: List<String>.unmodifiable(roles));
    if (next == state) return;
    emit(next);
    unawaited(_prefs?.setStringList(availableRolesPrefKey, roles));
  }
}

class RoleAvailability extends Equatable {
  const RoleAvailability({this.roles = const <String>[]});

  final List<String> roles;

  bool get isDualRole => roles.contains('client') && roles.contains('jeeber');

  @override
  List<Object?> get props => [roles];
}

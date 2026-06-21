import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// DEFECT-C: holds the authenticated user's `available_roles` from getMe so the
/// UI can gate the in-app role toggle.
///
/// A single-role client (`['client']`) must NOT see the Client↔Jeeber toggle;
/// a dual-role user (`['client', 'jeeber']`) does. This cubit is seeded empty
/// (toggle hidden) and is updated by [RoleSync] once `GET /v1/users/me`
/// resolves at login / app-resume. Display state only — it never gates a
/// screen, so the shell renders immediately and the toggle appears once the
/// roles are known.
class RoleAvailabilityCubit extends Cubit<RoleAvailability> {
  RoleAvailabilityCubit([super.initial = const RoleAvailability()]);

  /// Replace the known available roles (from a getMe refresh). A no-op when the
  /// list is unchanged so listeners don't rebuild needlessly.
  void setAvailableRoles(List<String> roles) {
    final next = RoleAvailability(roles: List<String>.unmodifiable(roles));
    if (next == state) return;
    emit(next);
  }
}

/// Immutable view of which roles the signed-in user may act as.
class RoleAvailability extends Equatable {
  const RoleAvailability({this.roles = const <String>[]});

  /// Role identifiers the user may act as, e.g. `['client', 'jeeber']`.
  final List<String> roles;

  /// True when the user can act as BOTH client and jeeber — the only case where
  /// the in-app role toggle (and driver surface) is offered.
  bool get isDualRole => roles.contains('client') && roles.contains('jeeber');

  @override
  List<Object?> get props => [roles];
}

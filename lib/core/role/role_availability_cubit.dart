import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/app_failure.dart';

/// How far the `available_roles` read got. F2/F3: without this, "getMe failed"
/// and "this account is not a jeeber" were the same two-valued answer.
enum RoleAvailabilityStatus { unknown, loading, resolved, failed }

class RoleAvailabilityCubit extends Cubit<RoleAvailability> {
  RoleAvailabilityCubit([
    super.initial = const RoleAvailability(),
    SharedPreferences? prefs,
    Future<String?> Function()? ownerIdProvider,
  ])  : _prefs = prefs,
        _ownerIdProvider = ownerIdProvider;

  /// Snapshot the FCM background isolate reads to audience-gate inbox rows.
  static const String availableRolesPrefKey = 'app.available_roles';

  /// The user id [availableRolesPrefKey] was written for.
  static const String availableRolesOwnerPrefKey = 'app.available_roles_owner';

  final SharedPreferences? _prefs;

  /// Resolves the signed-in user id the cache is stamped with.
  final Future<String?> Function()? _ownerIdProvider;

  Future<void> Function()? _refresher;

  /// True once a re-read is wired, so a surface can offer Retry.
  bool get canRefresh => _refresher != null;

  /// Lets the shell retry the capability read without holding a `RoleSync`.
  void attachRefresher(Future<void> Function() refresher) =>
      _refresher = refresher;

  Future<void> refresh() async => _refresher?.call();

  /// Restores the last known roles from prefs, but ONLY for the account the
  /// cache is stamped for — another account's roles land a client on Dashboard.
  Future<void> hydrate() async {
    if (state.status == RoleAvailabilityStatus.resolved) return;
    final owner = await _ownerId();
    if (owner.isEmpty) return;
    if (_prefs?.getString(availableRolesOwnerPrefKey) != owner) return;
    final cached = _prefs?.getStringList(availableRolesPrefKey);
    if (cached == null || cached.isEmpty) return;
    if (state.status == RoleAvailabilityStatus.resolved) return;
    emit(state.copyWith(roles: List<String>.unmodifiable(cached)));
  }

  Future<String> _ownerId() async {
    try {
      return (await _ownerIdProvider?.call())?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  void beginLoad() {
    if (state.status == RoleAvailabilityStatus.loading) return;
    emit(state.copyWith(status: RoleAvailabilityStatus.loading));
  }

  /// The read failed; [state.roles] is left untouched so a cached truth still
  /// governs the shell.
  void failed(AppFailure failure) {
    emit(
      state.copyWith(
        status: RoleAvailabilityStatus.failed,
        failure: failure,
      ),
    );
  }

  void setAvailableRoles(List<String> roles) {
    final next = RoleAvailability(
      roles: List<String>.unmodifiable(roles),
      status: RoleAvailabilityStatus.resolved,
    );
    if (next != state) emit(next);
    unawaited(_persist(roles));
  }

  Future<void> _persist(List<String> roles) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setStringList(availableRolesPrefKey, roles);
    final owner = await _ownerId();
    // An unstamped cache is never hydrated, so a missing id fails closed.
    if (owner.isEmpty) {
      await prefs.remove(availableRolesOwnerPrefKey);
      return;
    }
    await prefs.setString(availableRolesOwnerPrefKey, owner);
  }
}

class RoleAvailability extends Equatable {
  const RoleAvailability({
    this.roles = const <String>[],
    this.status = RoleAvailabilityStatus.unknown,
    this.failure,
  });

  final List<String> roles;

  final RoleAvailabilityStatus status;

  /// Set only while [status] is `failed`.
  final AppFailure? failure;

  bool get isDualRole => roles.contains('client') && roles.contains('jeeber');

  bool get isJeeber => roles.contains('jeeber');

  RoleAvailability copyWith({
    List<String>? roles,
    RoleAvailabilityStatus? status,
    AppFailure? failure,
  }) {
    final next = status ?? this.status;
    return RoleAvailability(
      roles: roles ?? this.roles,
      status: next,
      // Only the failed rung carries a failure, so no stale one can leak.
      failure: next == RoleAvailabilityStatus.failed
          ? (failure ?? this.failure)
          : null,
    );
  }

  @override
  List<Object?> get props => [roles, status, failure];
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../features/customer_profile/domain/customer_profile_view_data.dart';

/// The personalized-greeting data the role-home headers render (P0-X06).
///
/// Carries the signed-in user's first name and avatar URL so the customer /
/// jeeber home header can show "Hello, {name}" + the real avatar instead of the
/// generic "Welcome back" + "?" placeholder. Both are nullable: until the live
/// `GET /users/me` resolves (or when the user genuinely has no name/avatar on
/// file) the header falls back to the localized generic greeting + initials
/// avatar — never a bare "?" when a name IS known.
class GreetingProfileState extends Equatable {
  const GreetingProfileState({this.name, this.avatarUrl});

  /// First name to greet the user with (full name is trimmed to the first
  /// token by the header), or `null` when unknown.
  final String? name;

  /// Avatar image URL, or `null` to fall back to the initials avatar.
  final String? avatarUrl;

  GreetingProfileState copyWith({String? name, String? avatarUrl}) {
    return GreetingProfileState(
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [name, avatarUrl];
}

/// Sources the personalized greeting (name + avatar) for the role-home headers
/// from the same profile read the Profile tab uses (`GET /users/me`, role-
/// agnostic getMe). P0-X06: replaces the hardcoded `null`/"Kamal" placeholders
/// the home tabs previously fed into the greeting.
///
/// Construction is fail-safe: a missing repository (bare widget test / fixture
/// mode) or a failed live fetch leaves the state on its [seed] (typically
/// `null`/empty) so the header degrades to the generic greeting rather than
/// crashing or flashing a broken asset. The cubit holds DISPLAY state only — it
/// never gates the screen, so the home surfaces render immediately and the name
/// /avatar populate in once getMe resolves.
class GreetingProfileCubit extends Cubit<GreetingProfileState> {
  GreetingProfileCubit({
    CustomerProfileRepository? repository,
    GreetingProfileState seed = const GreetingProfileState(),
  })  : _repository = repository,
        super(seed);

  final CustomerProfileRepository? _repository;

  /// Cold entry: refresh the greeting from the live getMe. A no-op when no
  /// repository is wired (the seeded greeting stays as-is). Never throws — a
  /// failed fetch keeps the current state (generic greeting), matching how
  /// [CustomerProfileCubit] degrades on a failed live refresh.
  Future<void> load() async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final profile = await repo.fetchProfile();
      _emitFrom(profile);
    } on CustomerProfileRepositoryException {
      // Keep the current (seeded/generic) greeting; never surface a broken
      // header on a transient getMe failure.
    } catch (_) {
      // Same fail-closed-to-generic behaviour for any unexpected error.
    }
  }

  void _emitFrom(CustomerProfileViewData profile) {
    final name = profile.name?.trim();
    final avatar = profile.avatarUrl?.trim();
    emit(GreetingProfileState(
      name: (name == null || name.isEmpty) ? null : name,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
    ));
  }
}

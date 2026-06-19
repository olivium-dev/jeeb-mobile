import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';
import 'customer_profile_state.dart';

/// Owns the customer-profile header lifecycle (JM-035).
///
/// Seeded with the caller-supplied [CustomerProfileViewData] so the first frame
/// renders the header immediately (no spinner flash — the profile is never
/// blank). [load] then refreshes the seed from the live `GET /users/me` so the
/// real name/avatar/rating replace the fixture. A failed live fetch keeps the
/// seeded header visible (the screen degrades gracefully, 40_GUARDRAILS §4) and
/// only records the typed failure for an optional inline retry.
class CustomerProfileCubit extends Cubit<CustomerProfileState> {
  CustomerProfileCubit({
    required CustomerProfileViewData seed,
    CustomerProfileRepository? repository,
  })  : _repository = repository,
        super(CustomerProfileState(data: seed));

  final CustomerProfileRepository? _repository;

  /// Cold entry: refresh the seeded header from the live getMe. Guards re-entry
  /// so a remount doesn't re-fetch. A no-op when no repository is wired (e.g.
  /// widget tests / release fixture mode) — the seeded header stays as-is.
  Future<void> load() async {
    if (state.status != CustomerProfileStatus.initial) return;
    final repo = _repository;
    if (repo == null) {
      emit(state.copyWith(status: CustomerProfileStatus.loaded));
      return;
    }
    emit(state.copyWith(status: CustomerProfileStatus.loading, clearError: true));
    await _fetch(repo);
  }

  /// Re-fetch without flipping back to a full-screen spinner (the header stays
  /// visible; a pull/retry uses this).
  Future<void> refresh() async {
    final repo = _repository;
    if (repo == null) return;
    await _fetch(repo);
  }

  Future<void> _fetch(CustomerProfileRepository repo) async {
    try {
      final fresh = await repo.fetchProfile();
      emit(state.copyWith(
        data: fresh,
        status: CustomerProfileStatus.loaded,
        clearError: true,
      ));
    } on CustomerProfileRepositoryException catch (e) {
      // Keep the seeded header visible; only record the failure.
      emit(state.copyWith(
        status: CustomerProfileStatus.loaded,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CustomerProfileStatus.loaded,
        error: CustomerProfileFailure.unknown,
      ));
    }
  }
}

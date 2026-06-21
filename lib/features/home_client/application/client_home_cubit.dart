import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/client_home_repository.dart';
import 'client_home_state.dart';

/// Owns the client home tab's load + refresh lifecycle.
///
/// Inputs:
///   - [ClientHomeRepository] — talks to jeeb-gateway's home-summary endpoint.
///   - [greetingNameProvider] — injected by DI so tests can pass a fixed
///     name without spinning up the auth-session cubit.
///
/// The cubit deliberately holds only display state. It does NOT own the
/// active-request stream — that's the tracking cubit's job (T-mobile-014).
/// On a successful tracking-state push, the calling shell triggers
/// [refresh] to re-pull the summary.
class ClientHomeCubit extends Cubit<ClientHomeState> {
  ClientHomeCubit({
    required ClientHomeRepository repository,
    required String? Function() greetingNameProvider,
  }) : _repository = repository,
       _greetingNameProvider = greetingNameProvider,
       super(const ClientHomeState());

  final ClientHomeRepository _repository;
  final String? Function() _greetingNameProvider;

  /// Initial load. Safe to call from `initState` — re-entrant calls while
  /// a load is in flight are dropped on the floor.
  Future<void> load() async {
    if (state.status == ClientHomeStatus.loading) return;
    emit(
      state.copyWith(
        status: ClientHomeStatus.loading,
        greetingName: _greetingNameProvider(),
      ),
    );
    await _fetch();
  }

  /// Updates the free-text search query (home-disc-customer-home-search). The
  /// raw request lists stay as the server snapshot; the screen renders the
  /// query-filtered `visible*` views. A no-op emit is avoided so an unchanged
  /// query doesn't churn the bloc.
  void setQuery(String value) {
    if (value == state.query) return;
    emit(state.copyWith(query: value));
  }

  /// Triggered by pull-to-refresh + the post-action handlers (e.g. after a
  /// new request is created or one finishes). Keeps the previously-rendered
  /// data visible while the network call is in flight to avoid a jarring
  /// empty flash.
  Future<void> refresh() async {
    if (state.status == ClientHomeStatus.loading) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final snapshot = await _repository.loadSnapshot();
      emit(
        state.copyWith(
          status: ClientHomeStatus.ready,
          inProgress: snapshot.inProgress,
          pending: snapshot.pending,
          replies: snapshot.replies,
          // Cap the "Order again" strip at one entry — anything more belongs
          // on the Orders tab, not the home summary.
          recentDeliveries: snapshot.recentDeliveries.take(1).toList(),
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: ClientHomeStatus.failed));
    }
  }
}

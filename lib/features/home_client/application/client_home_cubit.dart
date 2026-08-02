import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../domain/client_home_repository.dart';
import 'client_home_state.dart';

const Duration kClientHomeRateLimitFallbackWindow = Duration(seconds: 10);

class ClientHomeCubit extends Cubit<ClientHomeState>
    implements PollingVisibility {
  ClientHomeCubit({
    required ClientHomeRepository repository,
    required String? Function() greetingNameProvider,
    Stream<void>? refreshSignals,
  }) : _repository = repository,
       _greetingNameProvider = greetingNameProvider,
       super(const ClientHomeState()) {
    _refreshGate = DeferredRefreshGate(
      onRefresh: refresh,
      signals: refreshSignals,
      debugLabel: 'ClientHomeCubit',
    );
  }

  final ClientHomeRepository _repository;
  final String? Function() _greetingNameProvider;
  late final DeferredRefreshGate _refreshGate;

  @visibleForTesting
  int get debugFetchCount => _fetchCount;
  int _fetchCount = 0;

  DateTime? _rateLimitedUntil;

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

  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (state.status == ClientHomeStatus.loading) return;
    if (_refreshInFlight) return;
    final backoffUntil = _rateLimitedUntil;
    if (backoffUntil != null && DateTime.now().isBefore(backoffUntil)) return;
    _refreshInFlight = true;
    try {
      await _fetch();
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  void setPollingVisible(bool visible) =>
      _refreshGate.setPollingVisible(visible);

  Future<void> _fetch() async {
    _fetchCount++;
    try {
      final snapshot = await _repository.loadSnapshot();
      if (isClosed) return;

      if (snapshot.rateLimited) {
        _rateLimitedUntil = DateTime.now().add(
          snapshot.retryAfter ?? kClientHomeRateLimitFallbackWindow,
        );
        if (state.status == ClientHomeStatus.ready) return;
      } else {
        _rateLimitedUntil = null;
      }

      emit(
        state.copyWith(
          status: ClientHomeStatus.ready,
          inProgress: snapshot.inProgress,
          pending: snapshot.pending,
          replies: snapshot.replies,
          recentDeliveries: snapshot.recentDeliveries.take(1).toList(),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      if (state.status == ClientHomeStatus.ready) return;
      emit(state.copyWith(status: ClientHomeStatus.failed));
    }
  }

  @override
  Future<void> close() {
    unawaited(_refreshGate.dispose());
    return super.close();
  }
}

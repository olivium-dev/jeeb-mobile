import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

/// `latency` defaults to zero: a non-zero delay here is a FRAMELESS timer that
/// `pumpAndSettle` never advances to, so callers that want it must opt in.
class InMemoryClientHomeRepository implements ClientHomeRepository {
  InMemoryClientHomeRepository({
    List<ClientHomeRequest>? seedActive,
    List<RecentDeliverySummary>? seedRecent,
    Duration latency = Duration.zero,
  }) : _snapshot = ClientHomeSnapshot(
         inProgress: seedActive ?? const [],
         recentDeliveries: seedRecent ?? const [],
       ),
       _latency = latency;

  InMemoryClientHomeRepository.fromSnapshot(
    ClientHomeSnapshot snapshot, {
    Duration latency = Duration.zero,
  }) : _snapshot = snapshot,
       _latency = latency;

  final ClientHomeSnapshot _snapshot;
  final Duration _latency;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    if (_latency > Duration.zero) await Future<void>.delayed(_latency);
    return _snapshot;
  }
}

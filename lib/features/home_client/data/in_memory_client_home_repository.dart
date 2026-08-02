import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

class InMemoryClientHomeRepository implements ClientHomeRepository {
  InMemoryClientHomeRepository({
    List<ClientHomeRequest>? seedActive,
    List<RecentDeliverySummary>? seedRecent,
    Duration latency = const Duration(milliseconds: 150),
  }) : _snapshot = ClientHomeSnapshot(
         inProgress: seedActive ?? const [],
         recentDeliveries: seedRecent ?? const [],
       ),
       _latency = latency;

  InMemoryClientHomeRepository.fromSnapshot(
    ClientHomeSnapshot snapshot, {
    Duration latency = const Duration(milliseconds: 150),
  }) : _snapshot = snapshot,
       _latency = latency;

  final ClientHomeSnapshot _snapshot;
  final Duration _latency;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    await Future<void>.delayed(_latency);
    return _snapshot;
  }
}

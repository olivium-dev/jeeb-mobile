import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import '../domain/recent_delivery_summary.dart';

/// Deterministic in-memory stand-in for the jeeb-gateway home endpoint.
///
/// MVP-only — wires the home tab into the BLoC pipeline so the screen is
/// usable in dev / under tests before the gateway endpoint exists. Replace
/// with a Dio-backed client at `data/http_client_home_repository.dart`
/// once the gateway side ships.
class InMemoryClientHomeRepository implements ClientHomeRepository {
  InMemoryClientHomeRepository({
    List<ClientHomeRequest>? seedActive,
    List<RecentDeliverySummary>? seedRecent,
    Duration latency = const Duration(milliseconds: 150),
  }) : _active = seedActive ?? const [],
       _recent = seedRecent ?? const [],
       _latency = latency;

  final List<ClientHomeRequest> _active;
  final List<RecentDeliverySummary> _recent;
  final Duration _latency;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    await Future<void>.delayed(_latency);
    return ClientHomeSnapshot(
      inProgress: List.unmodifiable(_active),
      recentDeliveries: List.unmodifiable(_recent),
    );
  }
}

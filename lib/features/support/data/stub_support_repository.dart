import '../domain/support_repository.dart';

/// DEBUG / catalog only: it fabricates a ticket id. Release builds resolve
/// [UnavailableSupportRepository] instead (WP7-N4).
class StubSupportRepository implements SupportRepository {
  const StubSupportRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    return const SupportTicket(id: 'stub-ticket-001', status: 'open');
  }
}

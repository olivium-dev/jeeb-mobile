import '../domain/support_repository.dart';

class StubSupportRepository implements SupportRepository {
  const StubSupportRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    return const SupportTicket(id: 'stub-ticket-001', status: 'open');
  }
}

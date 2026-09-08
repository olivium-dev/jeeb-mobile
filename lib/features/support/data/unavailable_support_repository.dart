import '../domain/support_repository.dart';

/// The release fallback when no [SupportRepository] is registered: it fails
/// loudly rather than confirming a ticket that was never created (WP7-N4).
class UnavailableSupportRepository implements SupportRepository {
  const UnavailableSupportRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) {
    throw const SupportRepositoryException(
      SupportFailure.unknown,
      'SupportRepository unregistered',
    );
  }
}

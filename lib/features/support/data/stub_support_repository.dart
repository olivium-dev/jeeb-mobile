import '../domain/support_repository.dart';

/// INTEGRATOR-STUB(JM-063): the support-ticket service (S1) is backend-owned and
/// NOT yet mounted on `:4010` (42_GUARDRAILS_MOCK §4). This in-memory stub is
/// the DI default so the support form (`SupportTicketScreen`, JM-063) + every
/// inbound edge (account-status / dispute-status / kyc-rejected → support, D76)
/// build and render NOW, before S1 lands. The data-bound ACs validate once the
/// real service exists.
///
/// DELIBERATELY a non-fake, DI-registerable stub (not a `Fake*` test seam, which
/// DO-NOT forbids in DI — 40_GUARDRAILS_ARCH §6). Accepts the submit and returns
/// a deterministic ticket reference so the form's success path renders.
///
/// SWAP WHEN S1 LANDS: replace the `injection_container.dart` registration's
/// `StubSupportRepository()` with `DioSupportRepository(sl<Dio>())`.
class StubSupportRepository implements SupportRepository {
  const StubSupportRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    return const SupportTicket(id: 'stub-ticket-001', status: 'open');
  }
}

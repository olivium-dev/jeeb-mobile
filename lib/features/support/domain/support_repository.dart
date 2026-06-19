// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Support-ticket domain contract (JM-063). The support-ticket service (S1) is
// backend-owned and NOT yet mounted on :4010 (42_GUARDRAILS_MOCK §4: "no
// support-ticket routes; compliment-service is disputes-only"), so the DI
// default is an INTEGRATOR-STUB (`injection_container.dart`); the data-bound ACs
// validate once S1 lands and DI is repointed to `DioSupportRepository`.
// Decision: D76.

/// The category of a support ticket (JM-063).
enum SupportCategory {
  account,
  payment,
  delivery,
  kycAppeal,
  dispute,
  other,
}

/// The payload submitted from the support form (`support_*` ids).
class SupportTicketDraft {
  const SupportTicketDraft({
    required this.category,
    required this.body,
    this.orderRef,
    this.attachmentPaths = const <String>[],
  });

  final SupportCategory category;
  final String body;

  /// Optional linked order/delivery (`support_order_link`).
  final String? orderRef;

  /// Optional local attachment file paths (`support_attach`).
  final List<String> attachmentPaths;
}

/// The created-ticket reference returned on submit.
class SupportTicket {
  const SupportTicket({required this.id, required this.status});

  final String id;
  final String status;
}

enum SupportFailure { network, unauthorized, unknown }

class SupportRepositoryException implements Exception {
  const SupportRepositoryException(this.failure, [this.message]);

  final SupportFailure failure;
  final String? message;

  @override
  String toString() => 'SupportRepositoryException($failure, $message)';
}

/// Domain contract for the support-ticket / contact-us screen (JM-063).
abstract class SupportRepository {
  /// Create a support ticket (S1). Throws [SupportRepositoryException] on
  /// failure.
  Future<SupportTicket> submitTicket(SupportTicketDraft draft);
}

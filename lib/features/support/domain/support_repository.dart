enum SupportCategory {
  account,
  payment,
  delivery,
  kycAppeal,
  dispute,
  other,
}

class SupportTicketDraft {
  const SupportTicketDraft({
    required this.category,
    required this.body,
    this.orderRef,
    this.attachmentPaths = const <String>[],
  });

  final SupportCategory category;
  final String body;

  final String? orderRef;

  final List<String> attachmentPaths;
}

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

abstract class SupportRepository {
  Future<SupportTicket> submitTicket(SupportTicketDraft draft);
}

import '../../case_evidence/domain/case_evidence.dart';

enum SupportCategory { account, payment, delivery, kycAppeal, dispute, other }

class SupportTicketDraft {
  const SupportTicketDraft({
    required this.category,
    required this.body,
    this.orderRef,
    this.attachmentPaths = const <String>[],
    this.attachments = const <CaseAttachmentDraft>[],
    this.operationId = '',
  });

  final SupportCategory category;
  final String body;

  final String? orderRef;

  final List<String> attachmentPaths;
  final List<CaseAttachmentDraft> attachments;
  final String operationId;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.status,
    this.ticketNumber,
    this.category,
    this.subject,
    this.body,
    this.orderRef,
    this.version = 0,
    this.createdAt,
    this.updatedAt,
    this.attachments = const <SupportAttachment>[],
    this.replies = const <SupportReply>[],
    this.isPartial = false,
  });

  final String id;
  final String status;
  final String? ticketNumber;
  final String? category;
  final String? subject;
  final String? body;
  final String? orderRef;
  final int version;
  final String? createdAt;
  final String? updatedAt;
  final List<SupportAttachment> attachments;
  final List<SupportReply> replies;
  final bool isPartial;

  SupportTicketStatus get canonicalStatus =>
      SupportTicketStatus.fromWire(status);

  SupportTicket copyWith({
    String? status,
    int? version,
    String? updatedAt,
    List<SupportAttachment>? attachments,
    List<SupportReply>? replies,
    bool? isPartial,
  }) {
    return SupportTicket(
      id: id,
      status: status ?? this.status,
      ticketNumber: ticketNumber,
      category: category,
      subject: subject,
      body: body,
      orderRef: orderRef,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
      replies: replies ?? this.replies,
      isPartial: isPartial ?? this.isPartial,
    );
  }
}

enum SupportTicketStatus {
  pending,
  fixed,
  closed,
  unknown;

  static SupportTicketStatus fromWire(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'pending' ||
      'open' ||
      'waiting' ||
      'waiting_on_support' ||
      'waiting_on_user' => pending,
      'fixed' || 'resolved' => fixed,
      'closed' => closed,
      _ => unknown,
    };
  }
}

class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.kind,
    required this.status,
    this.fileName,
    this.objectRef,
  });

  final String id;
  final String kind;
  final String status;
  final String? fileName;
  final String? objectRef;

  bool get failed => status == 'failed' || status == 'error';
}

class SupportReply {
  const SupportReply({
    required this.id,
    required this.body,
    required this.authorRole,
    required this.createdAt,
    this.attachments = const <SupportAttachment>[],
  });

  final String id;
  final String body;
  final String authorRole;
  final String createdAt;
  final List<SupportAttachment> attachments;

  bool get isMine => switch (authorRole.trim().toLowerCase()) {
    'user' || 'customer' || 'client' || 'jeeber' || 'requester' => true,
    _ => false,
  };
}

class SupportReplyDraft {
  const SupportReplyDraft({
    required this.operationId,
    required this.body,
    required this.version,
    this.attachments = const <CaseAttachmentDraft>[],
  });

  final String operationId;
  final String body;
  final int version;
  final List<CaseAttachmentDraft> attachments;
}

enum SupportFailure {
  network,
  unauthorized,
  notFound,
  conflict,
  upload,
  unknown,
}

class SupportRepositoryException implements Exception {
  const SupportRepositoryException(
    this.failure, [
    this.message,
    this.latestTicket,
  ]);

  final SupportFailure failure;
  final String? message;
  final SupportTicket? latestTicket;

  @override
  String toString() => 'SupportRepositoryException($failure, $message)';
}

abstract class SupportRepository {
  Future<SupportTicket> submitTicket(SupportTicketDraft draft);
}

abstract class SupportTicketV2Repository {
  Future<SupportTicket> submitTicketV2(
    SupportTicketDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  });
}

abstract class SupportThreadRepository {
  Future<SupportTicket> fetchTicket(String ticketId);

  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  });
}

class SupportThreadPage {
  const SupportThreadPage({required this.ticket, this.nextCursor});

  final SupportTicket ticket;
  final String? nextCursor;
}

abstract class PaginatedSupportThreadRepository {
  Future<SupportThreadPage> fetchInitialThread(
    String ticketId, {
    int limit = 20,
  });

  Future<SupportThreadPage> fetchMessages(
    String ticketId, {
    String? cursor,
    int limit = 20,
    String? initialRequestBody,
  });
}

class EmptySupportThreadRepository implements SupportThreadRepository {
  const EmptySupportThreadRepository();

  @override
  Future<SupportTicket> fetchTicket(String ticketId) {
    throw const SupportRepositoryException(SupportFailure.notFound);
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) {
    throw const SupportRepositoryException(SupportFailure.unknown);
  }
}

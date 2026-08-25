import '../../request_summary/domain/request_draft.dart';
import '../../request_summary/domain/request_submission_service.dart';
import '../domain/chat_gateway.dart' show kComposeConversationSentinel;
import '../domain/order_broadcast_service.dart';

/// Bridges order-chat compose→send to real create-request contract (JM-025/JM-024).
/// When no real request exists yet (sentinel id `new`), creates one via
/// RequestSubmissionService using first message as description, then broadcasts
class OrderComposeCoordinator {
  const OrderComposeCoordinator({
    required RequestSubmissionService submission,
    required OrderBroadcastService broadcast,
  }) : _submission = submission,
       _broadcast = broadcast;

  final RequestSubmissionService _submission;
  final OrderBroadcastService _broadcast;

  /// Sentinel route id before a request exists. Must never reach backend, broadcast, or waiting route.
  static const String composeSentinel = kComposeConversationSentinel;

  /// Resolves the real request id for compose→send and broadcasts it.
  /// Creates request from [firstMessage] if [existingRequestId] is empty/sentinel
  Future<String?> createAndBroadcast({
    required String existingRequestId,
    required String firstMessage,
    String? tierId,
  }) async {
    var requestId = existingRequestId;
    final needsCreate = requestId.isEmpty || requestId == composeSentinel;

    if (needsCreate) {
      final created = await _create(firstMessage, tierId);
      if (created == null) return null;
      requestId = created;
    }

    try {
      await _broadcast.broadcast(requestId: requestId);
    } on OrderBroadcastException {
      // Soft-fail: request is already created/pending; waiting screen reflects own coverage fetch.
    }
    return requestId;
  }

  Future<String?> _create(String firstMessage, String? tierId) async {
    final description = firstMessage.trim().isNotEmpty
        ? firstMessage.trim()
        : 'Delivery request';
    try {
      final id = await _submission.submit(
        RequestDraft(description: description, tierId: tierId),
      );
      // Defensive: empty/sentinel id from server is unusable.
      if (id.isEmpty || id == composeSentinel) return null;
      return id;
    } on RequestSubmissionException {
      return null;
    }
  }
}

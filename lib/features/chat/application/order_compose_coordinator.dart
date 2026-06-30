import '../../request_summary/domain/request_draft.dart';
import '../../request_summary/domain/request_submission_service.dart';
import '../domain/chat_gateway.dart' show kComposeConversationSentinel;
import '../domain/order_broadcast_service.dart';

/// Bridges the order-chat compose→send step (JM-025 AC1) to the REAL
/// create-request contract (JM-024).
///
/// THE BUG THIS FIXES (P0 #3): the live nav path tier → location → order-chat
/// previously pushed `chat-detail` with the literal sentinel id `new`, then on
/// the first composed message broadcast `requestId: "new"` and routed to
/// `waiting-no-coverage?id=new`. No request was ever created, so every
/// downstream call (`/v1/requests/new`, `/v1/chat/.../new`) 404'd and the user
/// dead-ended on "We couldn't load your request status."
///
/// The fix: when there is no real request yet (empty / `new` sentinel), CREATE
/// one via [RequestSubmissionService] (POST `/v1/requests`, verified 201 on the
/// live gateway) using the composed first message as the description, then
/// broadcast the SERVER-MINTED id. The literal `new` is NEVER forwarded to the
/// broadcast or waiting routes.
///
/// PURE application-layer coordinator — no Flutter / Dio / GetIt imports — so
/// the create-or-reuse decision is unit-testable in isolation.
class OrderComposeCoordinator {
  const OrderComposeCoordinator({
    required RequestSubmissionService submission,
    required OrderBroadcastService broadcast,
  })  : _submission = submission,
        _broadcast = broadcast;

  final RequestSubmissionService _submission;
  final OrderBroadcastService _broadcast;

  /// Sentinel route id the create-flow uses before a request exists. Must never
  /// reach the create body, the broadcast call, or the waiting route.
  ///
  /// Aliases the canonical [kComposeConversationSentinel] (chat domain) so the
  /// coordinator and the [ChatGateway] HTTP layer agree on the one literal that
  /// must never be sent to the backend.
  static const String composeSentinel = kComposeConversationSentinel;

  /// Resolves the REAL request id for the compose→send step and broadcasts it.
  ///
  /// When [existingRequestId] is empty or the [composeSentinel], a real request
  /// is created from [firstMessage] (the composed description; `tierId` is
  /// forwarded when known — it is optional on the live contract). The resolved
  /// real id is then broadcast to nearby Jeebers (a broadcast failure is soft —
  /// the request is already `pending`).
  ///
  /// Returns the server-minted request id, or `null` when creation failed — in
  /// which case the caller MUST stay in compose and surface a retry, and MUST
  /// NOT route anywhere (never to `new`).
  Future<String?> createAndBroadcast({
    required String existingRequestId,
    required String firstMessage,
    String? tierId,
  }) async {
    var requestId = existingRequestId;
    final needsCreate =
        requestId.isEmpty || requestId == composeSentinel;

    if (needsCreate) {
      final created = await _create(firstMessage, tierId);
      if (created == null) return null;
      requestId = created;
    }

    try {
      await _broadcast.broadcast(
        conversationId: requestId,
        requestId: requestId,
      );
    } on OrderBroadcastException {
      // Soft-fail: the request is already created/pending; the waiting screen
      // reflects coverage from its own fetch. Never trap the user in compose
      // over a broadcast hiccup.
    }
    return requestId;
  }

  Future<String?> _create(String firstMessage, String? tierId) async {
    final description =
        firstMessage.trim().isNotEmpty ? firstMessage.trim() : 'Delivery request';
    try {
      final id = await _submission.submit(
        RequestDraft(description: description, tierId: tierId),
      );
      // Defensive: a server that minted an empty / sentinel id is unusable.
      if (id.isEmpty || id == composeSentinel) return null;
      return id;
    } on RequestSubmissionException {
      return null;
    }
  }
}

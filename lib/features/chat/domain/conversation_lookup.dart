import 'package:dio/dio.dart';

/// What a conversation lookup actually LEARNED — three outcomes that the chat
/// stack used to collapse into one boolean.
///
/// The collapse was the defect. `resolveByCorrelationKey()` /
/// `resolveByMessagesProbe()` both caught `DioException` blanket and returned
/// `false`, so "the server told us there is no conversation" and "we could not
/// reach the server at all" produced the SAME state: the compose sentinel was
/// handed to the gateway, `loadHistory` short-circuited to `const []` with no
/// HTTP and no throw, `historyLoadFailed` was never raised, and `loadPhase`
/// hard-returned [ConversationPhase.broadcasting]. A transport failure was
/// laundered into a positive assertion about the world — observed live as
/// "Waiting for Jeebers… / No offers yet — sit tight." rendered over an
/// IN-TRANSIT delivery with an accepted offer and a named Jeeber.
///
/// Absence is a CLAIM ABOUT SERVER DATA. Only the server can make it.
enum ConversationLookup {
  /// A conversation row came back. We know what it is.
  resolved,

  /// The server ANSWERED and its answer was "there is no such conversation"
  /// (a 404 on the correlationKey lookup / messages probe). Pre-accept this is
  /// the truthful, expected outcome: the conversation is provisioned on accept,
  /// so before then there genuinely is nothing to open and the compose /
  /// broadcasting shell is correct.
  absent,

  /// We COULD NOT FIND OUT. No response at all (network down, DNS, TLS,
  /// timeout, cancelled) or a response that is not evidence of absence (5xx,
  /// 429, 401/403, an unparseable body). This must surface as an error with a
  /// retry — never as compose, never as "still broadcasting", never as an
  /// empty thread.
  unavailable,
}

/// Thrown by a chat read that could not determine the answer.
///
/// Deliberately a distinct type rather than a bare rethrow of the underlying
/// [DioException]: callers need to distinguish "the phase read could not find
/// out" from "the history read failed", and the two have different UI
/// consequences (see `ChatCubit.load`).
class ChatReadUnavailableException implements Exception {
  const ChatReadUnavailableException(this.operation, [this.cause]);

  /// The read that could not be completed, e.g. `loadPhase`.
  final String operation;

  /// The underlying transport/decode failure, when there was one.
  final Object? cause;

  @override
  String toString() =>
      'ChatReadUnavailableException($operation): could not determine the '
      'answer${cause == null ? '' : ' — $cause'}';
}

/// Classify a failed conversation read as [ConversationLookup.absent] (the
/// server answered "no such conversation") or [ConversationLookup.unavailable]
/// (we could not find out).
///
/// The bias is deliberate and asymmetric: ONLY a response-bearing failure whose
/// status is a definitive not-found counts as absence. Everything else — and in
/// particular every failure with NO response, which is exactly what "the
/// network is down" looks like to Dio — is `unavailable`. Getting this backwards
/// is what produced a confident "No offers yet" over a live delivery.
///
/// Status mapping:
///   * 404 / 410 → absent. The chat-service answers pre-accept reads with
///     `404 "Conversation '…' does not exist."` (physical-run8), and a jeeber's
///     `?correlationKey={conversationId}` read with the same (physical-run12).
///     Both are genuine absence.
///   * 400 → absent. The id is not a resolvable correlation key, so no
///     conversation is addressable by it. Kept as absence so a malformed /
///     non-key route param still lands in compose rather than an error page —
///     the pre-fix behaviour for that input, which no report has faulted.
///   * anything else with a response (5xx, 429, 401, 403, 408, 409…) →
///     unavailable. A server fault, a rate limit and an auth problem are all
///     silence about whether the conversation exists.
///   * no response at all (connectionError, connectionTimeout, sendTimeout,
///     receiveTimeout, badCertificate, cancel, unknown) → unavailable.
///     THIS IS THE NETWORK-DOWN CASE the DoD names.
ConversationLookup classifyLookupFailure(Object error) {
  if (error is! DioException) return ConversationLookup.unavailable;
  final status = error.response?.statusCode;
  if (status == null) return ConversationLookup.unavailable;
  return switch (status) {
    400 || 404 || 410 => ConversationLookup.absent,
    _ => ConversationLookup.unavailable,
  };
}

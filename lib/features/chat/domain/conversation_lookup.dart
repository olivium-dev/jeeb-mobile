import 'package:dio/dio.dart';

enum ConversationLookup {
  /// A conversation row came back. We know what it is.
  resolved,

  absent,

  /// We COULD NOT FIND OUT. No response at all (network down, DNS, TLS,
  /// timeout, cancelled) or a response that is not evidence of absence (5xx,
  unavailable,
}

class ChatReadUnavailableException implements Exception {
  const ChatReadUnavailableException(this.operation, [this.cause]);

  final String operation;

  final Object? cause;

  @override
  String toString() =>
      'ChatReadUnavailableException($operation): could not determine the '
      'answer${cause == null ? '' : ' — $cause'}';
}

ConversationLookup classifyLookupFailure(Object error) {
  if (error is! DioException) return ConversationLookup.unavailable;
  final status = error.response?.statusCode;
  if (status == null) return ConversationLookup.unavailable;
  return switch (status) {
    400 || 404 || 410 => ConversationLookup.absent,
    _ => ConversationLookup.unavailable,
  };
}

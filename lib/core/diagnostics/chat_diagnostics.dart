import 'package:flutter/foundation.dart';

/// Named stages of the chat identity chain, in the order they run.
abstract final class ChatDiagStage {
  static const String wrap = 'wrap';
  static const String mint = 'mint';
  static const String identity = 'identity';
  static const String firestore = 'firestore';
  static const String descriptor = 'descriptor';
  static const String socket = 'socket';
}

@immutable
class ChatDiagnosticEvent {
  const ChatDiagnosticEvent({
    required this.stage,
    required this.reason,
    required this.at,
    this.status,
    this.conversationId,
  });

  final String stage;
  final String reason;
  final DateTime at;
  final int? status;
  final String? conversationId;

  String get line =>
      'JEEB-CHAT-DEGRADED stage=$stage reason=$reason'
      '${status == null ? '' : ' status=$status'}'
      '${conversationId == null ? '' : ' conversation=$conversationId'}';
}

/// Ring of the last [capacity] silent chat degradations. Records WHY only —
/// every caller still takes exactly the branch it took before.
abstract final class ChatDiagnostics {
  static const int capacity = 40;

  static final ValueNotifier<List<ChatDiagnosticEvent>> listenable =
      ValueNotifier<List<ChatDiagnosticEvent>>(const <ChatDiagnosticEvent>[]);

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @visibleForTesting
  static void Function(String line)? sink;

  static List<ChatDiagnosticEvent> get events => listenable.value;

  static void degraded({
    required String stage,
    required String reason,
    int? status,
    String? conversationId,
  }) {
    final event = ChatDiagnosticEvent(
      stage: stage,
      reason: reason,
      at: clock(),
      status: status,
      conversationId: conversationId,
    );
    final next = <ChatDiagnosticEvent>[...listenable.value, event];
    listenable.value = next.length > capacity
        ? next.sublist(next.length - capacity)
        : next;
    final emit = sink;
    if (emit != null) {
      emit(event.line);
    } else if (kDebugMode) {
      debugPrint(event.line);
    }
  }

  static void clear() =>
      listenable.value = const <ChatDiagnosticEvent>[];

  @visibleForTesting
  static void resetForTest() {
    clear();
    clock = DateTime.now;
    sink = null;
  }
}

/// Last outcome of `PUT /api/PushNotification/register` — the silent half of
/// "push is dead" that no screen surfaces today.
@immutable
class PushRegistrationOutcome {
  const PushRegistrationOutcome({
    required this.reason,
    required this.at,
    this.status,
    this.error,
  });

  final String reason;
  final DateTime at;
  final int? status;
  final String? error;

  bool get succeeded => status != null && status! >= 200 && status! < 300;
}

abstract final class PushRegistrationDiagnostics {
  static final ValueNotifier<PushRegistrationOutcome?> listenable =
      ValueNotifier<PushRegistrationOutcome?>(null);

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static PushRegistrationOutcome? get last => listenable.value;

  static void record({required String reason, int? status, String? error}) {
    listenable.value = PushRegistrationOutcome(
      reason: reason,
      at: clock(),
      status: status,
      error: error,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    listenable.value = null;
    clock = DateTime.now;
  }
}

import 'package:equatable/equatable.dart';

import '../domain/support_repository.dart';

enum SupportPhase { inputting, submitting, success, error }

class SupportState extends Equatable {
  const SupportState({
    this.phase = SupportPhase.inputting,
    this.category,
    this.body = '',
    this.orderRef,
    this.attachmentPaths = const <String>[],
    this.ticketId,
    this.failure,
  });

  final SupportPhase phase;

  final SupportCategory? category;

  final String body;

  final String? orderRef;

  final List<String> attachmentPaths;

  final String? ticketId;

  final SupportFailure? failure;

  bool get canSubmit => category != null && body.trim().isNotEmpty;

  bool get canAttach => attachmentPaths.length < 5;

  SupportState copyWith({
    SupportPhase? phase,
    SupportCategory? category,
    String? body,
    String? orderRef,
    bool clearOrderRef = false,
    List<String>? attachmentPaths,
    String? ticketId,
    SupportFailure? failure,
    bool clearFailure = false,
  }) {
    return SupportState(
      phase: phase ?? this.phase,
      category: category ?? this.category,
      body: body ?? this.body,
      orderRef: clearOrderRef ? null : (orderRef ?? this.orderRef),
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      ticketId: ticketId ?? this.ticketId,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        phase,
        category,
        body,
        orderRef,
        attachmentPaths,
        ticketId,
        failure,
      ];
}

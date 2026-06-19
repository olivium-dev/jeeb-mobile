import 'package:equatable/equatable.dart';

import '../domain/support_repository.dart';

/// Lifecycle of the support-ticket form (JM-063).
///
/// `inputting` → (submit) → `submitting` → `success` | `error`.
/// `success` is the confirmation state the screen renders before routing to
/// customer-profile (D76 / 30_BACKLOG JM-063: "submit → confirmation →
/// customer-profile").
enum SupportPhase { inputting, submitting, success, error }

/// Immutable form/submit state for [SupportCubit].
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

  /// Selected `support_category`. Null until the user picks one.
  final SupportCategory? category;

  /// `support_body` free-text.
  final String body;

  /// Optional linked order/delivery (`support_order_link`).
  final String? orderRef;

  /// Local attachment file paths gathered via `support_attach` (≤5, mirroring
  /// the dispute-evidence cap in EscalateCubit).
  final List<String> attachmentPaths;

  /// Created-ticket reference, set once submit succeeds.
  final String? ticketId;

  /// Typed failure when [phase] is [SupportPhase.error].
  final SupportFailure? failure;

  /// Submit is allowed once a category is chosen and the body is non-empty
  /// (S1 rejects an empty body with 400 — guard it client-side, D30).
  bool get canSubmit => category != null && body.trim().isNotEmpty;

  /// Whether the attach affordance can add another photo (≤5).
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

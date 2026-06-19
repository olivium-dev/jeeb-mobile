import 'package:equatable/equatable.dart';

import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';

/// Canonical 4-state lifecycle (40_GUARDRAILS_ARCH §2/§3). There is no separate
/// "empty" — a blocked account always resolves to an [AccountStatusInfo].
enum AccountStatusScreenStatus { initial, loading, loaded, failed }

class AccountStatusState extends Equatable {
  const AccountStatusState({
    this.status = AccountStatusScreenStatus.initial,
    this.info,
    this.error,
  });

  final AccountStatusScreenStatus status;
  final AccountStatusInfo? info;
  final AccountStatusFailure? error;

  /// The resolved blocked-state value. Falls back to [AccountStatusValue.suspended]
  /// while loading / before the read resolves so the banner+CTAs always render a
  /// coherent blocked body (the screen is only shown behind the gate).
  AccountStatusValue get value => info?.value ?? AccountStatusValue.suspended;

  /// Server-supplied reason, when present.
  String? get reason => info?.reason;

  AccountStatusState copyWith({
    AccountStatusScreenStatus? status,
    AccountStatusInfo? info,
    AccountStatusFailure? error,
    bool clearError = false,
  }) =>
      AccountStatusState(
        status: status ?? this.status,
        info: info ?? this.info,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, info?.value, info?.reason, error];
}

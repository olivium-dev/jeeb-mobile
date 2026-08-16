import 'package:equatable/equatable.dart';

import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';

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

  AccountStatusValue get value => info?.value ?? AccountStatusValue.suspended;

  String? get reason => info?.reason;

  String? get reasonCode => info?.reasonCode;

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
  List<Object?> get props =>
      [status, info?.value, info?.reason, info?.reasonCode, error];
}

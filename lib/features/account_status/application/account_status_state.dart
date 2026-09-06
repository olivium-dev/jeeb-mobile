import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';

enum AccountStatusScreenStatus { initial, loading, loaded, failed }

class AccountStatusState extends Equatable {
  const AccountStatusState({
    this.status = AccountStatusScreenStatus.initial,
    this.info,
    this.error,
    this.appFailure,
    this.refreshError,
  });

  final AccountStatusScreenStatus status;
  final AccountStatusInfo? info;
  final AccountStatusFailure? error;

  /// The classified transport failure behind [error].
  final AppFailure? appFailure;

  /// A refresh that failed while a loaded banner is on screen.
  final AppFailure? refreshError;

  /// UX-43: null until a read succeeds. It used to default to `suspended`,
  /// which labelled every not-yet-loaded and failed read as a ban.
  AccountStatusValue? get value => info?.value;

  String? get reason => info?.reason;

  String? get reasonCode => info?.reasonCode;

  AccountStatusState copyWith({
    AccountStatusScreenStatus? status,
    AccountStatusInfo? info,
    AccountStatusFailure? error,
    bool clearError = false,
    AppFailure? appFailure,
    AppFailure? refreshError,
    bool clearRefreshError = false,
  }) =>
      AccountStatusState(
        status: status ?? this.status,
        info: info ?? this.info,
        error: clearError ? null : (error ?? this.error),
        appFailure: clearError ? null : (appFailure ?? this.appFailure),
        refreshError:
            clearRefreshError ? null : (refreshError ?? this.refreshError),
      );

  @override
  List<Object?> get props => [
        status,
        info?.value,
        info?.reason,
        info?.reasonCode,
        error,
        appFailure,
        refreshError,
      ];
}

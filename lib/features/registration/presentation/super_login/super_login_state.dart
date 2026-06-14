import 'package:equatable/equatable.dart';

import '../../data/super_login_service.dart';

/// UI status for the super-login credential sheet.
enum SuperLoginStatus { idle, submitting, error, success }

/// State for the super-login bottom sheet. Plain [Equatable] to match the
/// registration feature's existing state style (no codegen on the hot path —
/// see memory `jeeb-mob-fix-tickets-stale-vs-head`).
class SuperLoginState extends Equatable {
  const SuperLoginState({
    this.status = SuperLoginStatus.idle,
    this.error,
  });

  final SuperLoginStatus status;

  /// Set only when [status] == [SuperLoginStatus.error]. The sheet maps this
  /// to a localized message; it never carries the rejected passcode.
  final SuperLoginError? error;

  bool get isSubmitting => status == SuperLoginStatus.submitting;
  bool get isSuccess => status == SuperLoginStatus.success;

  SuperLoginState copyWith({
    SuperLoginStatus? status,
    Object? error = _sentinel,
  }) {
    return SuperLoginState(
      status: status ?? this.status,
      error: identical(error, _sentinel)
          ? this.error
          : error as SuperLoginError?,
    );
  }

  @override
  List<Object?> get props => [status, error];
}

const Object _sentinel = Object();

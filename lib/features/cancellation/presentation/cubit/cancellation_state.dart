import 'package:equatable/equatable.dart';

import '../../domain/cancellation_result.dart';

sealed class CancellationState extends Equatable {
  const CancellationState();

  @override
  List<Object?> get props => [];
}

final class CancellationIdle extends CancellationState {
  const CancellationIdle();
}

final class CancellationLoading extends CancellationState {
  const CancellationLoading();
}

/// Carries fee and week count data.
final class CancellationSuccess extends CancellationState {
  const CancellationSuccess(this.result);

  final CancellationResult result;

  @override
  List<Object?> get props => [result];
}

final class CancellationTooLate extends CancellationState {
  const CancellationTooLate();
}

/// Generic error; message never rendered to UI.
final class CancellationError extends CancellationState {
  const CancellationError([this.message]);

  final String? message;

  @override
  List<Object?> get props => [message];
}

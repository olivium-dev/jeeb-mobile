import 'package:equatable/equatable.dart';

enum OtpHandoverViewMode { loading, ready, submitting, success, error }

class OtpHandoverState extends Equatable {
  const OtpHandoverState({
    this.mode = OtpHandoverViewMode.loading,
    this.handoverCode,
    this.errorMessage,
  });

  final OtpHandoverViewMode mode;
  final String? handoverCode;
  final String? errorMessage;

  OtpHandoverState copyWith({
    OtpHandoverViewMode? mode,
    String? handoverCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OtpHandoverState(
      mode: mode ?? this.mode,
      handoverCode: handoverCode ?? this.handoverCode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [mode, handoverCode, errorMessage];
}

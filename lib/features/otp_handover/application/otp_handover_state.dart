import 'package:equatable/equatable.dart';

enum OtpHandoverViewMode { loading, ready, submitting, success, error }

class OtpHandoverState extends Equatable {
  const OtpHandoverState({
    this.mode = OtpHandoverViewMode.loading,
    this.handoverCode,
    this.errorMessage,
    this.wrongAttempts = 0,
    this.shakeKey = 0,
    this.escalate = false,
    this.smsSent = false,
  });

  final OtpHandoverViewMode mode;
  final String? handoverCode;
  final String? errorMessage;

  final bool smsSent;

  final int wrongAttempts;

  final int shakeKey;

  final bool escalate;

  static const int maxAttempts = 3;

  OtpHandoverState copyWith({
    OtpHandoverViewMode? mode,
    String? handoverCode,
    String? errorMessage,
    bool clearError = false,
    int? wrongAttempts,
    int? shakeKey,
    bool? escalate,
    bool? smsSent,
  }) {
    return OtpHandoverState(
      mode: mode ?? this.mode,
      handoverCode: handoverCode ?? this.handoverCode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      shakeKey: shakeKey ?? this.shakeKey,
      escalate: escalate ?? this.escalate,
      smsSent: smsSent ?? this.smsSent,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        handoverCode,
        errorMessage,
        wrongAttempts,
        shakeKey,
        escalate,
        smsSent,
      ];
}

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
  });

  final OtpHandoverViewMode mode;
  final String? handoverCode;
  final String? errorMessage;

  /// T-MOB-018 AC3/AC4: tracks failed attempts (max 3 before escalation).
  final int wrongAttempts;

  /// T-MOB-018 AC3: incrementing key triggers shake animation rebuild.
  final int shakeKey;

  /// T-MOB-018 AC4: set true after 3 wrong codes to show escalate dialog.
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
  }) {
    return OtpHandoverState(
      mode: mode ?? this.mode,
      handoverCode: handoverCode ?? this.handoverCode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      shakeKey: shakeKey ?? this.shakeKey,
      escalate: escalate ?? this.escalate,
    );
  }

  @override
  List<Object?> get props =>
      [mode, handoverCode, errorMessage, wrongAttempts, shakeKey, escalate];
}

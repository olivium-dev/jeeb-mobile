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
    this.allowManualEntry = false,
  });

  final OtpHandoverViewMode mode;
  final String? handoverCode;
  final String? errorMessage;

  /// iter6 OTP-phone v2: when true, the CLIENT screen renders a code-ENTRY
  /// surface (type the code → submit verify) instead of the code-DISPLAY.
  ///
  /// The live gateway `GET /v1/deliveries/{id}/otp` does NOT return a `code`
  /// field, so the client's code display has nothing to show and the screen
  /// used to fall to a generic "Something went wrong" error. The handover code
  /// is validated SERVER-side, so the client can still complete handover by
  /// entering the code (the live demo code `1234`) and submitting verify — this
  /// flag flips the client body to that usable entry path.
  final bool allowManualEntry;

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
    bool? allowManualEntry,
  }) {
    return OtpHandoverState(
      mode: mode ?? this.mode,
      handoverCode: handoverCode ?? this.handoverCode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      shakeKey: shakeKey ?? this.shakeKey,
      escalate: escalate ?? this.escalate,
      allowManualEntry: allowManualEntry ?? this.allowManualEntry,
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
        allowManualEntry,
      ];
}

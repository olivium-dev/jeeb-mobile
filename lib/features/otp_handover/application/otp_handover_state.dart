import 'package:equatable/equatable.dart';

import '../domain/handover_arrival.dart';
import '../domain/otp_handover_repository.dart';

enum OtpHandoverViewMode { loading, ready, submitting, success, error }

class OtpHandoverState extends Equatable {
  const OtpHandoverState({
    this.mode = OtpHandoverViewMode.loading,
    this.handoverCode,
    this.errorKind,
    this.attemptsRemaining,
    this.escalationId,
    this.lockedAt,
    this.wrongAttempts = 0,
    this.shakeKey = 0,
    this.escalate = false,
    this.smsSent = false,
    this.arrival,
    this.resending = false,
    this.resendFailed = false,
  });

  final OtpHandoverViewMode mode;
  final String? handoverCode;

  /// The typed failure the screen renders. Replaces the token strings the
  /// screen used to string-compare against.
  final OtpHandoverErrorKind? errorKind;

  /// Server-reported attempts left; preferred over the local subtraction.
  final int? attemptsRemaining;

  /// The case the gateway already opened on a 423 lockout.
  final String? escalationId;
  final DateTime? lockedAt;

  /// Screen 13's arrival banner payload. Null is the normal case — the read is
  /// best-effort garnish over a surface whose reason to exist is the code, so
  /// it never gates [mode] and never surfaces its own failure.
  final HandoverArrival? arrival;

  /// True while a user-initiated SMS resend is in flight. Deliberately NOT
  /// `mode: loading`: that blanked the whole screen and, on failure, dropped a
  /// displayed code into the error body.
  final bool resending;

  /// The last resend threw. Rendered as one inline line under the SMS row and
  /// cleared on the next tap.
  final bool resendFailed;

  /// G4 (sprint-009): true when the gateway reported it delivered the code by
  /// SMS to the recipient (`GET /otp` → `triggered: true`) and the app itself
  /// holds no code to display (no accept-time code in [HandoverCodeStore] —
  /// e.g. the app was reinstalled mid-delivery). The CLIENT screen then says
  /// exactly that ("We've sent your code by SMS…") with a resend affordance.
  ///
  /// This REPLACES the removed `allowManualEntry` flag: the customer is NEVER
  /// shown a code-ENTRY grid (that is the Jeeber's surface — asking the
  /// customer to type a code they were never shown was the G4 dead end).
  final bool smsSent;

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
    OtpHandoverErrorKind? errorKind,
    int? attemptsRemaining,
    String? escalationId,
    DateTime? lockedAt,
    bool clearError = false,
    int? wrongAttempts,
    int? shakeKey,
    bool? escalate,
    bool? smsSent,
    HandoverArrival? arrival,
    bool? resending,
    bool? resendFailed,
  }) {
    return OtpHandoverState(
      mode: mode ?? this.mode,
      handoverCode: handoverCode ?? this.handoverCode,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      attemptsRemaining:
          clearError ? null : (attemptsRemaining ?? this.attemptsRemaining),
      escalationId: clearError ? null : (escalationId ?? this.escalationId),
      lockedAt: clearError ? null : (lockedAt ?? this.lockedAt),
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      shakeKey: shakeKey ?? this.shakeKey,
      escalate: escalate ?? this.escalate,
      smsSent: smsSent ?? this.smsSent,
      arrival: arrival ?? this.arrival,
      resending: resending ?? this.resending,
      resendFailed: resendFailed ?? this.resendFailed,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        handoverCode,
        errorKind,
        attemptsRemaining,
        escalationId,
        lockedAt,
        wrongAttempts,
        shakeKey,
        escalate,
        smsSent,
        arrival,
        resending,
        resendFailed,
      ];
}

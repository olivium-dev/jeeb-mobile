import 'package:flutter/widgets.dart';

/// Feature-local stopgap for the **nine** redesign-2026-08 screen-13 strings
/// that do not exist in the shared ARBs yet.
///
/// The ARB files and the hand-authored `AppLocalizations` getter layer are
/// integrator-owned — a screen lane never edits them. The queued batch is
/// recorded verbatim in `docs/redesign-2026-08/wiring/13-otp-handover.md`; this
/// class supplies the same EN/AR values from a feature-local map until it
/// lands, so the feature compiles and its widget tests run today. It is the
/// `LiveTrackingL10n` precedent from screen 12's lane, deliberately kept to the
/// smallest possible surface:
///
///  * every string that ALREADY has a getter is read straight off
///    `AppLocalizations` at the call site — nothing is mirrored here;
///  * the three keys the batch **re-values** in place
///    (`otpHandoverClientTitle`, `otpClientShareInstruction`,
///    `otpClientDoNotShare`) are likewise read off `AppLocalizations`, so they
///    pick the board copy up automatically when the integrator re-values them.
///
/// Maestro asserts on `Semantics(identifier:)` only, and this lane's widget
/// tests assert through the getters rather than through literals, so the swap
/// is a no-op for every gate.
///
/// **Delete this file** once the integrator lands:
///   `otpClientShareSubtitle` · `otpClientShareSubtitleNamed` ·
///   `otpArrivalAtDoor` · `otpArrivalOnTheWay` · `otpArrivalSubtitle` ·
///   `otpClientResendSmsPrompt` · `otpClientResendSmsAction` ·
///   `otpDisputeCta` · `otpResendFailed`
/// and point its four call sites at `AppLocalizations.of(context)`.
class OtpHandoverL10n {
  const OtpHandoverL10n({required bool isArabic}) : _isArabic = isArabic;

  /// Resolves against the ambient locale — `Localizations.localeOf` is the same
  /// source `AppLocalizations.of` reads, so the two can never disagree.
  factory OtpHandoverL10n.of(BuildContext context) => OtpHandoverL10n(
        isArabic: Localizations.localeOf(context).languageCode == 'ar',
      );

  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  /// Instruction subtitle when the courier's name has not loaded.
  String get shareSubtitle => _pick(
        'Your Jeeber types this code to prove the handoff.',
        'يُدخل جيبرك هذا الرمز لإثبات التسليم.',
      );

  /// Instruction subtitle once the arrival read named the courier.
  String shareSubtitleNamed(String name) => _pick(
        '$name types this code to prove the handoff.',
        'يُدخل $name هذا الرمز لإثبات التسليم.',
      );

  /// Arrival-banner headline at the door.
  String arrivalAtDoor(String name) =>
      _pick('$name is at your door', '$name عند بابك');

  /// Arrival-banner headline before the at-door stage.
  String arrivalOnTheWay(String name) =>
      _pick('$name is on the way', '$name في الطريق');

  /// Arrival-banner subtitle. [amount] is `MoneyFormat` output (already wrapped
  /// in an LTR isolate), so it keeps its symbol placement inside Arabic copy.
  String arrivalSubtitle(String vehicle, String amount) => _pick(
        '$vehicle · $amount cash ready',
        '$vehicle · $amount نقدًا جاهز',
      );

  /// Muted lead-in of the code-surface SMS line. The trailing space is part of
  /// the string: the accent action sits inline after it.
  String get resendSmsPrompt => _pick('Didn\'t get it? ', 'لم يصلك الرمز؟ ');

  /// The accent-text action next to [resendSmsPrompt].
  String get resendSmsAction => _pick('Send by SMS', 'أرسله برسالة نصية');

  /// Outline footer pill — the honest exit when the handoff goes wrong.
  String get disputeCta =>
      _pick('Problem? Open a dispute', 'مشكلة؟ افتح نزاعًا');

  /// Inline failure line under the SMS row.
  String get resendFailed => _pick(
        "Couldn't send the SMS. Try again.",
        'تعذّر إرسال الرسالة النصية. حاول مرة أخرى.',
      );
}

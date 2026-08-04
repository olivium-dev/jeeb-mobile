import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// redesign-2026-08 screen 18 copy resolver.
///
/// `lib/l10n/*.arb` + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned; this lane may not edit them. The ten strings the redesign
/// introduces are therefore served here, from a feature-local EN/AR map, until
/// the integrator lands the batch queued in
/// `docs/redesign-2026-08/wiring/18-active-delivery-jeeber.md`.
///
/// Same shape as `live_tracking/presentation/live_tracking_l10n.dart`, which is
/// the shipped precedent for this situation. Every consumer on 18 reads its
/// copy through this one class, so landing the ARB keys is a one-file swap:
/// replace each `_pick(...)` body with `_l10n.<key>` and delete the file.
/// Maestro asserts on `Semantics(identifier:)` only, so the visible copy moving
/// from here to the ARBs changes nothing downstream.
///
/// Delete this file once the integrator adds:
///   activeDeliveryHandoffTitle · activeDeliveryProofPhotoTile
///   · activeDeliveryDoorCodePrompt · activeDeliveryCollectCash
///   · activeDeliveryCollectCashNoAmount
///   · activeDeliveryQuickActionMaps · activeDeliveryQuickActionChat
///   · activeDeliveryQuickActionCosts
///   and changes `activeDeliveryOtpSubmit` to "Verify code & complete".
class ActiveDeliveryJeeberL10n {
  ActiveDeliveryJeeberL10n(this._l10n, this._isArabic);

  factory ActiveDeliveryJeeberL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ActiveDeliveryJeeberL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  // ── handoff card ─────────────────────────────────────────────────────────

  /// Heading of the handoff action card (`tpl 1067`). Replaces the old
  /// "Done"-as-heading copy bug.
  String get handoffTitle => _pick('Complete the handoff', 'أكمل التسليم');

  /// Proof-photo tile label (`tpl 1072`). The board's ✓ is drawn as an icon,
  /// never baked into the string.
  String get proofPhotoTile => _pick('Proof photo', 'صورة الإثبات');

  /// The single prompt line above the door-code cells (`tpl 1076`). Replaces
  /// `activeDeliveryOtpTitle` + `activeDeliveryOtpInstruction`.
  String get doorCodePrompt => _pick(
        'Ask the customer for their 4-digit door code:',
        'اطلب من العميل رمز الباب المكوَّن من 4 أرقام:',
      );

  /// Door-code submit CTA (`tpl 1083`). The queued ARB change re-values the
  /// existing `activeDeliveryOtpSubmit` key to this string.
  String get otpSubmit =>
      _pick('Verify code & complete', 'تحقق من الرمز وأكمل');

  // ── drop-off card ────────────────────────────────────────────────────────

  /// D11 cash-on-delivery line (`tpl 1062`). [amount] arrives pre-formatted
  /// from `JeeberDelivery.amountText`.
  String collectCash(String amount) => _pick(
        'Collect $amount cash on delivery',
        'حصّل $amount نقدًا عند التسليم',
      );

  /// Run-22 P1-A degraded variant: the snapshot carries no amount. Never
  /// fabricate `$0.00` — say what is true and let the jeeber read the order.
  String get collectCashNoAmount => _pick(
        'Collect the order amount in cash on delivery',
        'حصّل قيمة الطلب نقدًا عند التسليم',
      );

  // ── footer pills ─────────────────────────────────────────────────────────
  //
  // Short visible words; the existing long forms
  // (`activeDeliveryOpenMapsButton` etc.) stay as the Semantics labels, so
  // TalkBack still hears a full sentence.

  String get quickActionMaps => _pick('Maps', 'الخرائط');
  String get quickActionChat => _pick('Chat', 'الدردشة');
  String get quickActionCosts => _pick('Costs', 'التكاليف');

  // ── reused, already localized ────────────────────────────────────────────

  /// "Note (optional)" — the existing offer-composer key is byte-identical to
  /// the board's tile label, so 18 adds no key for it.
  String get noteTile => _l10n.offerSubmissionNoteLabel;
}

import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// redesign-2026-08 screen 18 copy accessors.
///
/// Every string below now has a real ARB key in both locales, so this class is
/// a thin accessor layer — no `_pick`, no feature-local EN/AR map.
class ActiveDeliveryJeeberL10n {
  ActiveDeliveryJeeberL10n(this._l10n);

  factory ActiveDeliveryJeeberL10n.of(BuildContext context) =>
      ActiveDeliveryJeeberL10n(AppLocalizations.of(context));

  final AppLocalizations _l10n;

  // ── handoff card ─────────────────────────────────────────────────────────

  String get handoffTitle => _l10n.activeDeliveryHandoffTitle;

  String get proofPhotoTile => _l10n.activeDeliveryProofPhotoTile;

  String get doorCodePrompt => _l10n.activeDeliveryDoorCodePrompt;

  String get otpSubmit => _l10n.activeDeliveryOtpSubmit;

  // ── drop-off card ────────────────────────────────────────────────────────

  /// [amount] arrives pre-formatted from `JeeberDelivery.amountText`.
  String collectCash(String amount) => _l10n.activeDeliveryCollectCash(amount);

  /// Degraded variant: the snapshot carries no amount. Never fabricate
  /// `$0.00` — say what is true and let the jeeber read the order.
  String get collectCashNoAmount => _l10n.activeDeliveryCollectCashNoAmount;

  // ── footer pills ─────────────────────────────────────────────────────────

  String get quickActionMaps => _l10n.activeDeliveryQuickActionMaps;
  String get quickActionChat => _l10n.activeDeliveryQuickActionChat;
  String get quickActionCosts => _l10n.activeDeliveryQuickActionCosts;

  // ── reused, already localized ────────────────────────────────────────────

  /// "Note (optional)" — the existing offer-composer key is byte-identical.
  String get noteTile => _l10n.offerSubmissionNoteLabel;
}

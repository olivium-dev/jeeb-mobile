import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// JM-031 localized copy resolver (R-F, guardrail §9 l10n protocol).
///
/// The shared ARB files (`app_en.arb`/`app_ar.arb`) + the hand-authored
/// `AppLocalizations` getter layer are integrator-owned (50_EXECUTION_PLAN §S4:
/// "engineers reference keys; never inline-add"). The W1 integrator batched the
/// CTA/title keys (`orderSummaryTitle`/`OpenChat`/`Track`) but the field-label
/// + cash-reminder keys this widget needs are not yet present.
///
/// Per the JM-008 precedent in `50_ROUTE_REQUESTS.md`, this resolver references
/// the EXISTING localized getters where one fits (tier/ETA labels) and supplies
/// the genuinely-missing strings from a feature-local EN/AR map until the
/// integrator lands the dedicated keys (REQUESTED in `50_ROUTE_REQUESTS.md`,
/// "JM-031"). Maestro asserts on `Semantics(identifier:)` only, so the visible
/// copy is cosmetic — this swaps to the real getters with no call-site change.
///
/// Delete this file once the integrator adds:
///   orderSummaryPriceLabel · orderSummaryCashLabel · orderSummaryEtaLabel
///   · orderSummaryTierLabel · orderSummaryItemLabel · orderSummaryEtaMinutes
///   · orderSummaryEtaPending · orderSummaryRatingCount
class OrderSummaryL10n {
  OrderSummaryL10n(this._l10n, this._isArabic);

  factory OrderSummaryL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return OrderSummaryL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  /// `order_summary_pinned` app-bar/section title (integrator-batched).
  String get title => _l10n.orderSummaryTitle;

  /// `order_summary_open_chat` CTA (integrator-batched).
  String get openChat => _l10n.orderSummaryOpenChat;

  /// `order_summary_track` CTA (integrator-batched).
  String get track => _l10n.orderSummaryTrack;

  /// "Price" label above the accepted COD amount (D11).
  String get priceLabel => _pick('Price', 'السعر');

  /// "Pay cash on delivery" reminder (D11) — the customer pays the Jeeber in
  /// cash; NO commission/finance line is shown on this customer surface.
  String get cashLabel => _pick('Pay cash on delivery', 'ادفع نقداً عند التسليم');

  /// "ETA" label — reuses the existing tracking getter (already in both ARBs).
  String get etaLabel => _l10n.trackingEtaLabel;

  /// "{minutes} min" — reuses the existing tracking getter.
  String etaMinutes(int minutes) => _l10n.trackingEtaMinutes(minutes);

  /// ETA placeholder when unknown (renders a pending dash, not "0 min").
  String get etaPending => _pick('ETA pending', 'الوقت المقدّر قيد التحديد');

  /// "Tier" label — reuses the existing delivery-details getter.
  String get tierLabel => _l10n.deliveryTierLabel;

  /// "Item" label above the one-line order summary.
  String get itemLabel => _pick('Item', 'الطلب');

  /// Generic load-failure copy — reuses an existing localized getter present in
  /// both ARBs (i18n-safe; Maestro asserts ids, not copy).
  String get errorGeneric => _l10n.requestSummaryErrorGeneric;

  /// Retry CTA on the error state — reuses an existing localized getter.
  String get retryLabel => _l10n.trackingGpsLostRetry;

  /// Maps a tier id to its localized display name via the existing
  /// tier-selection getters; unknown ids fall back to the raw id.
  String tierName(String tierId) {
    switch (tierId.toLowerCase().replaceAll('_', '-')) {
      case 'flash':
        return _l10n.tierSelectionTierFlash;
      case 'express':
        return _l10n.tierSelectionTierExpress;
      case 'standard':
        return _l10n.tierSelectionTierStandard;
      case 'on-the-way':
      case 'ontheway':
        return _l10n.tierSelectionTierOnTheWay;
      case 'eco':
        return _l10n.tierSelectionTierEco;
      default:
        return tierId;
    }
  }
}

import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// JM-045 / JM-046 localized copy resolver (R-F, 40_GUARDRAILS_ARCH §9 l10n
/// protocol; JM-031 `order_summary_l10n.dart` precedent).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned (50_EXECUTION_PLAN §S4). The W2 integrator batched the
/// wallet/funding/gate keys, but the **offer-composer economics** lines (fee /
/// net / reserve / order-ref) and the **insufficient-balance sheet** copy this
/// screen needs are NOT yet present. Per the JM-008/JM-031 precedent, this
/// resolver reuses the EXISTING localized getters where one fits and supplies
/// the genuinely-missing strings from a feature-local EN/AR map until the
/// integrator lands the dedicated keys (REQUESTED in `50_ROUTE_REQUESTS.md`,
/// "JM-045"). Maestro asserts on `Semantics(identifier:)` only, so the visible
/// copy is cosmetic — this swaps to the real getters with no call-site change.
///
/// Delete this file once the integrator adds the `offerComposer*` /
/// `insufficientBalance*` keys requested in `50_ROUTE_REQUESTS.md`.
class OfferComposerL10n {
  OfferComposerL10n(this._l10n, this._isArabic);

  factory OfferComposerL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return OfferComposerL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  // ── App bar / header ────────────────────────────────────────────────────
  /// `offer_composer` app-bar title — reuses the existing offer-submission key.
  String get title => _l10n.offerSubmissionTitle;

  /// Withdraw/close tooltip on the leading button — reuses an existing getter.
  String get closeTooltip => _l10n.offerSubmitWithdrawTooltip;

  /// `offer_composer_order_ref` — "Your offer · ORD-…" header (AC3). The order
  /// reference itself (`ref`) is not localized.
  String orderRef(String ref) =>
      _pick('Your offer · $ref', 'عرضك · $ref');

  /// Short intro under the header — reuses the existing offer-submission intro.
  String get intro => _l10n.offerSubmissionIntro;

  // ── Price field ─────────────────────────────────────────────────────────
  /// `offer_composer_price_field` label — reuses the existing fee label.
  String get priceLabel => _l10n.offerSubmissionFeeLabel;

  // ── ETA dropdown (bounded by tier SLA, D14) ───────────────────────────────
  /// `offer_composer_eta_dropdown` label — reuses the existing ETA label.
  String get etaLabel => _l10n.offerSubmissionEtaLabel;

  /// Placeholder shown on the dropdown before the Jeeber picks an ETA.
  String get etaPlaceholder => _pick('Select pickup ETA', 'اختر وقت الاستلام');

  /// Title of the ETA picker sheet.
  String get etaSheetTitle => _pick('Pickup ETA', 'وقت الاستلام');

  /// "{minutes} min" — a single bounded ETA option label.
  String etaOption(int minutes) => _pick('$minutes min', '$minutes دقيقة');

  // ── Economics layer (D37 / D44 / D1) ──────────────────────────────────────
  /// `offer_composer_fee_line` — the exact 10% platform fee (D37/D44).
  String feeLine(String amount, String currency) => _pick(
        'Platform fee (10%): $amount $currency',
        'رسوم المنصة (١٠٪): $amount $currency',
      );

  /// Fee line shown before a price is entered (no amount yet).
  String get feeLinePending => _pick(
        'Platform fee: 10% of your offer',
        'رسوم المنصة: ١٠٪ من عرضك',
      );

  /// `offer_composer_net_line` — "You earn (cash)" net-per-offer (D44). The
  /// Jeeber is paid the full fee in cash by the customer; the 10% is taken from
  /// the pre-charged wallet, so the net the Jeeber keeps == the offer price.
  String netLine(String amount, String currency) => _pick(
        'You earn (cash): $amount $currency',
        'تربح (نقداً): $amount $currency',
      );

  /// Net line shown before a price is entered.
  String get netLinePending => _pick(
        'You earn (cash): your full offer, paid by the customer',
        'تربح (نقداً): كامل عرضك، يدفعه العميل',
      );

  /// `offer_composer_reserve_note` — reserve/charge/release copy (D1).
  String reserveNote(String amount, String currency) => _pick(
        '$amount $currency reserved now from your wallet · charged only if you '
            'win · released if you don’t.',
        'يُحجز الآن $amount $currency من محفظتك · يُخصم فقط إذا فزت · '
            'يُعاد إن لم تفز.',
      );

  /// Reserve note shown before a price is entered.
  String get reserveNotePending => _pick(
        '10% is reserved now from your wallet · charged only if you win · '
            'released if you don’t.',
        'يُحجز الآن ١٠٪ من محفظتك · يُخصم فقط إذا فزت · يُعاد إن لم تفز.',
      );

  // ── Send CTA ──────────────────────────────────────────────────────────────
  /// `offer_composer_send_cta` — reuses the existing submit-button key.
  String get sendCta => _l10n.offerSubmissionSubmitButton;

  // ── Transient feedback ────────────────────────────────────────────────────
  /// Request-gone snack — reuses the existing offer-submit getter.
  String get requestGone => _l10n.offerSubmitRequestGone;

  /// Generic submit-failure snack.
  String get errorGeneric =>
      _pick('Couldn’t send your offer. Please try again.',
          'تعذّر إرسال عرضك. يرجى المحاولة مجدداً.');

  /// Network-failure snack.
  String get errorNetwork =>
      _pick('No connection. Check your network and try again.',
          'لا يوجد اتصال. تحقق من شبكتك وحاول مجدداً.');

  // ── Insufficient-balance sheet (JM-046) ───────────────────────────────────
  /// `insufficient_balance_sheet` heading.
  String get insufficientTitle =>
      _pick('Not enough balance', 'الرصيد غير كافٍ');

  /// Body explaining the gap.
  String get insufficientBody => _pick(
        'Top up your wallet to reserve the 10% and send this offer.',
        'اشحن محفظتك لحجز الـ ١٠٪ وإرسال هذا العرض.',
      );

  /// `insufficient_balance_needed_amount` — "Needed: X currency".
  String insufficientNeeded(String amount, String currency) =>
      _pick('Needed: $amount $currency', 'المطلوب: $amount $currency');

  /// `insufficient_balance_available_amount` — "Available: Y currency".
  String insufficientAvailable(String amount, String currency) =>
      _pick('Available: $amount $currency', 'المتوفر: $amount $currency');

  /// `insufficient_topup_cta` — routes to wallet-charge-info. Reuses the
  /// existing wallet top-up CTA key.
  String get insufficientTopUpCta => _l10n.walletTopUpCta;

  /// `insufficient_keep_editing_cta` — dismiss, draft preserved.
  String get insufficientKeepEditingCta =>
      _pick('Keep editing', 'متابعة التعديل');
}

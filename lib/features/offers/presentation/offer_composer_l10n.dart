import 'package:flutter/widgets.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/jeeb_commission.dart';
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
/// "JM-045"; redesign-2026-08 wiring request WR-5). Maestro asserts on
/// `Semantics(identifier:)` only, so the visible copy is cosmetic — this swaps
/// to the real getters with no call-site change.
///
/// **Money is never interpolated raw.** Every amount goes through
/// [MoneyFormat.format], which wraps the token in a Unicode LTR isolate — that
/// is what keeps `$0.80` from scrambling inside an Arabic sentence (JEBV4-98).
/// Bare numeric runs (the ETA ceiling) go through [_ltr] for the same reason.
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

  /// U+2066 LEFT-TO-RIGHT ISOLATE.
  static const String _lri = '\u2066';

  /// U+2069 POP DIRECTIONAL ISOLATE.
  static const String _pdi = '\u2069';

  /// U+2212 MINUS SIGN — what the board draws on `−$0.80` and `−1`, not the
  /// ASCII hyphen.
  static const String minusSign = '\u2212';

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  /// Wraps [run] in an LTR isolate so a Western-digit run keeps its internal
  /// order (and its sign/symbol placement) inside an Arabic paragraph.
  String _ltr(String run) => '$_lri$run$_pdi';

  // ── Header ──────────────────────────────────────────────────────────────
  /// The top bar title (board `tpl 991`).
  String get title => _pick('Your offer', 'عرضك');

  /// Withdraw/close tooltip on the leading circle — reuses an existing getter.
  String get closeTooltip => _l10n.offerSubmitWithdrawTooltip;

  /// Short intro under the header. No consumer since the redesign moved the
  /// header into [title] + the order-ref subtitle; the ARB key is untouched.
  String get intro => _l10n.offerSubmissionIntro;

  // ── Price block ─────────────────────────────────────────────────────────
  /// `YOUR PRICE` section label (uppercasing belongs to `JeebSectionLabel`).
  String get priceSectionLabel => _pick('Your price', 'سعرك');

  /// Placeholder inside the money field before anything is typed. Digits stay
  /// Western in both locales (the [MoneyFormat] digit policy).
  String get pricePlaceholder => '0.00';

  /// The currency mark drawn beside the amount: `$` for USD (and for a blank
  /// currency, which the gateway treats as USD), else the ISO code.
  String currencyMark(String currency) {
    final code = currency.trim().toUpperCase();
    return code.isEmpty || code == 'USD' ? r'$' : code;
  }

  /// a11y label for the `−1` pill — `−1` alone reads badly.
  String get priceDecrementLabel => _pick(
        'Decrease offer by 1',
        'خفض العرض بمقدار ١',
      );

  /// a11y label for the `+1` pill.
  String get priceIncrementLabel => _pick(
        'Increase offer by 1',
        'زيادة العرض بمقدار ١',
      );

  // ── ETA block (bounded by the tier SLA, D14) ────────────────────────────
  /// `PICKUP ETA` section label.
  String get etaSectionLabel => _pick('Pickup ETA', 'وقت الاستلام');

  /// The section label's inline hint — the band ceiling. The board reads
  /// `· Flash allows ≤ 60 min`; the tier is not on this route (see the header
  /// TODO), so only the ceiling is rendered — never a guessed tier name.
  String etaCeilingHint(int minutes) => _pick(
        '· ${_ltr('≤ $minutes')} min',
        '· ${_ltr('≤ $minutes')} دقيقة',
      );

  /// The fourth pill that opens the full band when the inline three do not
  /// cover it.
  String get etaOther => _pick('Other', 'أخرى');

  /// Title of the ETA picker sheet.
  String get etaSheetTitle => _pick('Pickup ETA', 'وقت الاستلام');

  /// "{minutes} min" — a single bounded ETA option label.
  String etaOption(int minutes) =>
      _pick('${_ltr('$minutes')} min', '${_ltr('$minutes')} دقيقة');

  // ── Note field (optional free text, wire field `note`) ───────────────────
  /// `offer_composer_note_field` accessibility label. The redesigned field
  /// shows a placeholder only, so this is the field's a11y name.
  String get noteLabel =>
      _pick('Describe your offer (optional)', 'صِف عرضك (اختياري)');

  /// `offer_composer_note_field` placeholder (board `tpl 1009`).
  String get noteHint => _pick(
        'Add a note — "I\'m 5 mins from the pharmacy" (optional)',
        'أضف ملاحظة — "أنا على بعد ٥ دقائق من الصيدلية" (اختياري)',
      );

  // ── Economics layer (D37 / D44 / D1) ────────────────────────────────────
  /// `offer_composer_offer_line` label — the Jeeber's own bid.
  String get offerRowLabel => _pick('Your offer', 'عرضك');

  /// `offer_composer_fee_line` label. The percentage is interpolated from
  /// [kJeebCommissionPercent] so the word and the number cannot drift (D37/D44
  /// — "Platform fee", NEVER "Commission").
  String get feeRowLabel => _pick(
        'Platform fee ($kJeebCommissionPercent%)',
        'رسوم المنصة ($kJeebCommissionPercent٪)',
      );

  /// Fee line shown before a price is entered (no amount yet).
  String get feeLinePending => _pick(
        'Platform fee: $kJeebCommissionPercent% of your offer',
        'رسوم المنصة: $kJeebCommissionPercent٪ من عرضك',
      );

  /// `offer_composer_net_line` label — what the Jeeber keeps after the fee.
  ///
  /// This is the redesign's C2 decision: the board computes offer → −10% fee →
  /// "you keep", and `netPerOffer` (`earnings_summary.dart:170`) already
  /// defines net that way, so the composer and Earnings now agree. The board's
  /// `(cash)` qualifier is dropped on purpose — the cash in hand IS the full
  /// offer; the reserve footnote carries the wallet mechanics.
  String get keepRowLabel => _pick('You keep', 'تحتفظ بـ');

  /// Net line shown before a price is entered.
  String get netLinePending => _pick(
        'You keep: your offer minus the platform fee',
        'تحتفظ بـ: عرضك ناقص رسوم المنصة',
      );

  /// A formatted, LTR-isolated money token (`$8.00`, `LBP 15,000.00`).
  String money(double amount, String currency) =>
      MoneyFormat.format(amount, currency: currency);

  /// The same token carrying the board's U+2212 sign (`−$0.80`), kept inside
  /// one isolate so the sign stays glued to the digits under RTL.
  String negativeMoney(double amount, String currency) =>
      _ltr('$minusSign${money(amount, currency)}');

  /// `offer_composer_reserve_note` — reserve/charge/release copy (D1).
  /// [amount] arrives pre-formatted through [money].
  String reserveNote(String amount) => _pick(
        '$amount is reserved from your wallet now · charged only if you win · '
            'released if you’re not picked.',
        'يُحجز الآن $amount من محفظتك · يُخصم فقط إذا فزت · '
            'يُعاد إن لم يقع الاختيار عليك.',
      );

  /// Reserve note shown before a price is entered.
  String get reserveNotePending => _pick(
        '$kJeebCommissionPercent% is reserved now from your wallet · charged '
            'only if you win · released if you don’t.',
        'يُحجز الآن $kJeebCommissionPercent٪ من محفظتك · يُخصم فقط إذا فزت · '
            'يُعاد إن لم تفز.',
      );

  // ── Wallet strip ────────────────────────────────────────────────────────
  /// `offer_composer_wallet_strip` — the available balance. [amount] arrives
  /// pre-formatted through [money].
  String walletStrip(String amount) => _pick(
        'Wallet: $amount available',
        'المحفظة: $amount متاح',
      );

  /// `offer_composer_wallet_topup_cta` — reuses the shipped wallet key.
  String get walletTopUpCta => _l10n.walletTopUpCta;

  // ── Send CTA ────────────────────────────────────────────────────────────
  /// `offer_composer_send_cta` before a price is entered — reuses the existing
  /// submit-button key.
  String get sendCta => _l10n.offerSubmissionSubmitButton;

  /// `offer_composer_send_cta` with the kept amount restated (board `tpl
  /// 1031`). [amount] arrives pre-formatted through [money].
  String sendCtaWithNet(String amount) => _pick(
        'Send offer — keep $amount',
        'أرسل العرض — تحتفظ بـ $amount',
      );

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
        'Top up your wallet to reserve the $kJeebCommissionPercent% and send '
            'this offer.',
        'اشحن محفظتك لحجز الـ $kJeebCommissionPercent٪ وإرسال هذا العرض.',
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

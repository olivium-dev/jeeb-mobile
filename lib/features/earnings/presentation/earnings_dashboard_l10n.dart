import 'package:flutter/widgets.dart';

import '../../../core/jeeb_commission.dart';
import '../../../l10n/app_localizations.dart';

/// JM-052 earnings-fees-dashboard localized copy resolver (R-F,
/// 40_GUARDRAILS_ARCH §9 l10n protocol; JM-031 `order_summary_l10n.dart` /
/// JM-045 `offer_composer_l10n.dart` / JM-053 `wallet_hub_l10n.dart` precedent).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned (50_EXECUTION_PLAN §S4). The earnings dashboard is being
/// REFRAMED fee-only (D41/D44) — the previous gross/commission/net-payout copy
/// (`earningsGross`, `earningsCommission`, `earningsNet`) is the wrong economic
/// model and must NOT be reused for the new labels. No dedicated fee-only keys
/// (`earningsTotalCash`, `earningsFeesPaid`, `earningsNetPerOffer`,
/// `earningsMemberSince`, …) exist yet, so per the JM-031/045/053 precedent this
/// resolver supplies the genuinely-missing strings from a feature-local EN/AR
/// map until the integrator lands the dedicated keys (REQUESTED in
/// `50_ROUTE_REQUESTS.md`, "JM-052"). It reuses the EXISTING locale-safe getters
/// where one fits (title / period pills / load error + retry / export button).
/// Maestro asserts on `Semantics(identifier:)` only, so the visible copy is
/// cosmetic — this swaps to the real getters with no call-site change.
///
/// Delete this file (fold the `_pick` strings into the `earnings*` ARB getters)
/// once the integrator lands the keys requested in `50_ROUTE_REQUESTS.md`.
class EarningsDashboardL10n {
  EarningsDashboardL10n(this._l10n, this._isArabic);

  factory EarningsDashboardL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return EarningsDashboardL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  // ── Present keys (integrator-landed). ─────────────────────────────────────
  String get title => _l10n.earningsTitle;
  String get periodToday => _l10n.earningsPeriodToday;
  String get periodWeek => _l10n.earningsPeriodWeek;
  String get periodMonth => _l10n.earningsPeriodMonth;
  String get loadError => _l10n.earningsLoadFailed;
  String get retry => _l10n.earningsLoadRetry;
  String get exportButton => _l10n.earningsExportButton;
  String get empty => _l10n.earningsEmpty;

  // ── Fee-only headline (D41/D44). ──────────────────────────────────────────

  /// `earnings_total_cash` — total cash collected off-wallet (COD, D41).
  String get totalCashLabel =>
      _pick('Total cash earned', 'إجمالي النقد المكتسب');
  /// The trust line under the hero amount: cash never moves through Jeeb
  /// (D41). Shorter and more direct than the previous phrasing because the
  /// redesigned hero renders it as a single line under a 38px number.
  String get totalCashHint => _pick(
    'Paid to you directly — never through Jeeb.',
    'يُدفع لك مباشرة — لا يمر عبر جيب أبدًا.',
  );

  /// `earnings_fees_paid` — captured platform fees.
  String get feesPaidLabel =>
      _pick('Platform fees paid', 'رسوم المنصة المدفوعة');

  /// The rate is interpolated from [kJeebCommissionPercent], never typed: a
  /// literal "10%" beside a number derived from the constant would be free to
  /// disagree with it (see `core/jeeb_commission.dart`).
  String get feesPaidHint => _pick(
    '$kJeebCommissionPercent% per won offer, from your wallet',
    '$kJeebCommissionPercent٪ لكل عرض فائز، من محفظتك',
  );

  /// Net-per-offer (D44) — average cash kept per delivery after the fee.
  /// Sized for the hero's three-column stat slot, not a full-width card.
  String get netPerOfferLabel =>
      _pick('Avg kept / offer', 'متوسط المحتفظ به / عرض');
  String get netPerOfferHint => _pick(
    'Average cash you keep per delivery after fees.',
    'متوسط النقد الذي تحتفظ به لكل توصيلة بعد الرسوم.',
  );

  /// Deliveries count stat.
  String get deliveriesLabel => _pick('Deliveries', 'التوصيلات');

  /// `earnings_member_since` — the Jeeber's join date.
  String get memberSinceLabel => _pick('Member since', 'عضو منذ');

  // ── Honest empty / pending state (T11 / SW-01). ───────────────────────────
  /// Shown INSTEAD of "0.00 · 0 · 0.00" cards when the wire carries no earnings
  /// for the period — a truthful "nothing recorded yet" rather than a confident
  /// zero after a completed cash delivery.
  String get emptyTitle =>
      _pick('No earnings yet this period', 'لا أرباح بعد لهذه الفترة');
  String get emptyHint => _pick(
    'A completed delivery can take a few minutes to appear here. '
        'Pull to refresh, or check another period.',
    'قد تستغرق التوصيلة المكتملة بضع دقائق لتظهر هنا. '
        'اسحب للتحديث، أو تحقق من فترة أخرى.',
  );
  String get emptyRefresh => _pick('Refresh', 'تحديث');

  // ── Delivery breakdown rows. ──────────────────────────────────────────────
  String get breakdownTitle => _pick('Recent deliveries', 'التوصيلات الأخيرة');
  String deliveryRowTitle(String id) => _pick('Delivery $id', 'توصيلة $id');

  /// Row title with the delivery's weekday appended. The board shows an item
  /// name here (`Pharmacy run · Fri`); the wire carries no item name, so only
  /// the weekday — which IS derivable from the entry's date — is added.
  /// Falls back to [deliveryRowTitle] when the date is missing/unparseable.
  String deliveryRowTitleDated(String id, String weekday) =>
      _pick('Delivery $id · $weekday', 'توصيلة $id · $weekday');

  /// [money] is already a fully-formatted [MoneyFormat] string (e.g. `$1.20`),
  /// so the currency is not appended separately here.
  String deliveryRowFee(String money) => _pick('$money fee', 'رسوم $money');

  // ── Cross-feature links (real edges — W3 targets registered). ─────────────

  /// `earnings_wallet_link` → wallet-hub (JM-053). One word: the footer pill
  /// shares its row with the export CTA and appends the live balance.
  String get walletLink => _pick('Wallet', 'المحفظة');

  /// `earnings_activity_link` → wallet-activity-list (JM-055). Sized for a
  /// trailing link on the section header, not a settings row.
  String get activityLink => _pick('See all', 'عرض الكل');

  String period(String key) {
    switch (key) {
      case 'today':
        return periodToday;
      case 'month':
        return periodMonth;
      case 'week':
      default:
        return periodWeek;
    }
  }
}

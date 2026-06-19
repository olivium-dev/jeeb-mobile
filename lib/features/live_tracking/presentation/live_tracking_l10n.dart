import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// JM-032 localized copy resolver (R-F, 40_GUARDRAILS_ARCH §9 l10n protocol).
///
/// The shared ARB files (`app_en.arb`/`app_ar.arb`) + the hand-authored
/// `AppLocalizations` getter layer are integrator-owned (50_EXECUTION_PLAN §S4:
/// "engineers reference keys; never inline-add"). The W1 integrator batched the
/// tracking + order-summary keys this screen reuses, but the dispute / no-show /
/// 4th-step labels are not yet present.
///
/// Per the JM-008/JM-031 precedent in `50_ROUTE_REQUESTS.md`, this resolver
/// references the EXISTING localized getters where one fits (step labels,
/// tier/ETA labels, order-summary CTAs) and supplies the genuinely-missing
/// strings from a feature-local EN/AR map until the integrator lands the
/// dedicated keys (REQUESTED in `50_ROUTE_REQUESTS.md`, "JM-032"). Maestro
/// asserts on `Semantics(identifier:)` only, so the visible copy is cosmetic —
/// this swaps to the real getters with no call-site change.
///
/// Delete this file once the integrator adds:
///   trackingDisputeCta · trackingNoShowCta · trackingNoShowTitle
///   · trackingNoShowBody · trackingNoShowReassignCta
///   · trackingNoShowRebroadcastCta · trackingStepDelivered
///   · orderSummaryPriceLabel · orderSummaryCashLabel
class LiveTrackingL10n {
  LiveTrackingL10n(this._l10n, this._isArabic);

  factory LiveTrackingL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return LiveTrackingL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  // ── stepper step labels (reuse existing tracking getters) ────────────────
  String get stepOrdered => _l10n.trackingStepOrdered;
  String get stepPicked => _l10n.trackingStepPicked;
  String get stepInTransit => _l10n.trackingStepInTransit;

  /// 4th step — reuses the existing "Delivered" getter (`trackingStepCompleted`
  /// renders "Delivered" in both ARBs).
  String get stepDelivered => _l10n.trackingStepCompleted;

  // ── action bar CTAs ──────────────────────────────────────────────────────
  String get disputeCta => _pick('Report a problem', 'الإبلاغ عن مشكلة');
  String get noShowCta =>
      _pick("Jeeber didn't show up", 'لم يصل الجيبر');

  // ── no-show sheet ────────────────────────────────────────────────────────
  String get noShowTitle =>
      _pick('Jeeber didn’t show up?', 'لم يصل الجيبر؟');
  String get noShowBody => _pick(
        'You can pick another offer for this request, or send it out again to nearby Jeebers.',
        'يمكنك اختيار عرض آخر لهذا الطلب، أو إعادة إرساله إلى الجيبرز القريبين.',
      );
  String get noShowReassignCta =>
      _pick('Choose another offer', 'اختيار عرض آخر');
  String get noShowRebroadcastCta =>
      _pick('Send request again', 'إعادة إرسال الطلب');
  String get noShowKeepCta => _pick('Keep waiting', 'متابعة الانتظار');

  // ── pinned summary header (reuse existing getters where present) ─────────
  String get summaryPriceLabel => _pick('Price', 'السعر');
  String get summaryCashLabel =>
      _pick('Pay cash on delivery', 'ادفع نقداً عند التسليم');
  String get summaryEtaLabel => _l10n.trackingEtaLabel;
  String summaryEtaMinutes(int minutes) => _l10n.trackingEtaMinutes(minutes);
  String get summaryEtaPending =>
      _pick('ETA pending', 'الوقت المقدّر قيد التحديد');
  String get summaryTierLabel => _l10n.deliveryTierLabel;
  String get summaryOpenChat => _l10n.orderSummaryOpenChat;
  String get summaryTrack => _l10n.orderSummaryTrack;

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

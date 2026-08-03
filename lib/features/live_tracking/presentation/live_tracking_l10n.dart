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
///   · trackingArrivingIn · trackingCourierOnTheWay · trackingCashOnDelivery
///   · trackingDoorCodeNote · trackingCashShort
///   (the redesign-2026-08 batch — see
///    `docs/redesign-2026-08/wiring/12-live-tracking.md`)
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

  /// P6/A5: the third step's at-the-door label. Reuses the existing
  /// `activeDeliveryStatusAtDoor` key ("At Door" / "عند الباب") — no new ARB
  /// key, and the step's semantics identifier is unchanged.
  String get stepAtDoor => _l10n.activeDeliveryStatusAtDoor;

  /// 4th step — reuses the existing "Delivered" getter (`trackingStepCompleted`
  /// renders "Delivered" in both ARBs).
  String get stepDelivered => _l10n.trackingStepCompleted;

  // ── action bar CTAs ──────────────────────────────────────────────────────
  //
  // redesign-2026-08 board copy (`12-live-tracking.html` tpl 781-783). The
  // longer sentence forms were the pre-redesign wording; no test asserts them.
  String get disputeCta => _pick('Open dispute', 'فتح نزاع');
  String get noShowCta =>
      _pick('Report no-show', 'الإبلاغ عن عدم الحضور');

  // ── redesign-2026-08 additions (screen 12) ───────────────────────────────
  //
  // Stopgaps only: each one has a queued ARB key (see the class doc). Every
  // consumer reads them through this resolver, so landing the real keys is a
  // one-file swap.

  /// Floating ETA pill over the map (`tpl 764`). [minutes] is the live ETA.
  String arrivingIn(int minutes) => _pick(
        'Arriving in $minutes min',
        'الوصول خلال $minutes دقيقة',
      );

  /// Courier-card title (`tpl 768`). [name] is the in-flight display name.
  String courierOnTheWay(String name) => _pick(
        '$name is on the way',
        '$name في الطريق',
      );

  /// Courier-card money qualifier (`tpl 769`). D11: customer-facing, cash on
  /// delivery, never a commission line. [amount] is already formatted.
  String cashOnDelivery(String amount) => _pick(
        '$amount cash on delivery',
        '$amount نقداً عند التسليم',
      );

  /// Door-code strip label (`tpl 778`). One line — the strip has no sub-line.
  String get doorCodeNote => _pick(
        'Door code — share only at handoff',
        'رمز الباب — شاركه عند التسليم فقط',
      );

  /// The short cash qualifier drawn in the top-bar meta line (`tpl 724`).
  /// Screen readers get the full [summaryCashLabel] sentence instead.
  String get cashShort => _pick('cash', 'نقداً');

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

  // ── courier-position freshness (the phantom-pin affordance) ──────────────
  //
  // The map hides the marker as soon as the gateway stops vouching for the fix
  // (`markerIsLive`). Hiding it SILENTLY is its own small dishonesty: from the
  // customer's seat a pin that disappears and a pin that was never there look
  // identical, and neither explains itself. These two lines are what turns
  // "the pin is gone" into "here is what we know and when we last knew it".
  //
  // Two distinct copies for two distinct wire states, because the difference
  // matters to the customer's next action:
  //  * STALE — the gateway still has coordinates, just aging ones. The customer
  //    should wait; the courier is probably stationary (the uploader only
  //    reports every 10 m).
  //  * LOST  — the gateway has no coordinates at all any more. The customer
  //    should consider calling, or the no-show path.

  /// Aging-but-present fix. [minutes] is the floor of the reported age.
  String positionStaleNotice(int minutes) => _pick(
        "Jeeber's location is $minutes min old",
        'موقع الجيبر قديم منذ $minutes دقيقة',
      );

  /// No coordinates at all any more — we had this courier and lost them.
  String positionLostNotice(int minutes) => _pick(
        'No signal from the Jeeber — last seen $minutes min ago',
        'لا إشارة من الجيبر — آخر ظهور قبل $minutes دقيقة',
      );

  /// Used when the gateway reports an age below one minute (or none at all),
  /// so the numeric copy above would read "0 min".
  String get positionLostNoticeNoAge =>
      _pick('No signal from the Jeeber', 'لا إشارة من الجيبر');

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

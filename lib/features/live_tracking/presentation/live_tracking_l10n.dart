import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

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

  String get stepOrdered => _l10n.trackingStepOrdered;
  String get stepPicked => _l10n.trackingStepPicked;
  String get stepInTransit => _l10n.trackingStepInTransit;

  String get stepAtDoor => _l10n.activeDeliveryStatusAtDoor;

  String get stepDelivered => _l10n.trackingStepCompleted;

  String get disputeCta => _pick('Report a problem', 'الإبلاغ عن مشكلة');
  String get noShowCta =>
      _pick("Jeeber didn't show up", 'لم يصل الجيبر');

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


  String positionStaleNotice(int minutes) => _pick(
        "Jeeber's location is $minutes min old",
        'موقع الجيبر قديم منذ $minutes دقيقة',
      );

  String positionLostNotice(int minutes) => _pick(
        'No signal from the Jeeber — last seen $minutes min ago',
        'لا إشارة من الجيبر — آخر ظهور قبل $minutes دقيقة',
      );

  String get positionLostNoticeNoAge =>
      _pick('No signal from the Jeeber', 'لا إشارة من الجيبر');

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

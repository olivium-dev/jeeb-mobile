import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// model and must NOT be reused for the new labels. No dedicated fee-only keys
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

  String get title => _l10n.earningsTitle;
  String get periodToday => _l10n.earningsPeriodToday;
  String get periodWeek => _l10n.earningsPeriodWeek;
  String get periodMonth => _l10n.earningsPeriodMonth;
  String get loadError => _l10n.earningsLoadFailed;
  String get retry => _l10n.earningsLoadRetry;
  String get exportButton => _l10n.earningsExportButton;
  String get empty => _l10n.earningsEmpty;

  String get totalCashLabel =>
      _pick('Total cash earned', 'إجمالي النقد المكتسب');
  String get totalCashHint => _pick(
    'Cash collected directly from customers, off-wallet.',
    'النقد الذي حصّلته مباشرة من العملاء، خارج المحفظة.',
  );

  String get feesPaidLabel =>
      _pick('Platform fees paid', 'رسوم المنصة المدفوعة');
  String get feesPaidHint => _pick(
    'Fees captured from your wallet on offers you won.',
    'رسوم تُخصم من محفظتك على العروض التي فزت بها.',
  );

  String get netPerOfferLabel => _pick('Net per offer', 'الصافي لكل عرض');
  String get netPerOfferHint => _pick(
    'Average cash you keep per delivery after fees.',
    'متوسط النقد الذي تحتفظ به لكل توصيلة بعد الرسوم.',
  );

  String get deliveriesLabel => _pick('Deliveries', 'التوصيلات');

  String get memberSinceLabel => _pick('Member since', 'عضو منذ');

  String get emptyTitle =>
      _pick('No earnings yet this period', 'لا أرباح بعد لهذه الفترة');
  String get emptyHint => _pick(
    'A completed delivery can take a few minutes to appear here. '
        'Pull to refresh, or check another period.',
    'قد تستغرق التوصيلة المكتملة بضع دقائق لتظهر هنا. '
        'اسحب للتحديث، أو تحقق من فترة أخرى.',
  );
  String get emptyRefresh => _pick('Refresh', 'تحديث');

  String get breakdownTitle => _pick('Recent deliveries', 'التوصيلات الأخيرة');
  String deliveryRowTitle(String id) => _pick('Delivery $id', 'توصيلة $id');

  String deliveryRowFee(String money) => _pick('$money fee', 'رسوم $money');

  String get walletLink => _pick('Open wallet', 'فتح المحفظة');
  String get walletLinkSubtitle =>
      _pick('Balance, reserves and top-ups.', 'الرصيد والحجوزات والشحن.');

  String get activityLink => _pick('See all activity', 'عرض كل النشاط');
  String get activityLinkSubtitle => _pick(
    'Reserves, fees, refunds and top-ups.',
    'الحجوزات والرسوم والمستردات والشحن.',
  );

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

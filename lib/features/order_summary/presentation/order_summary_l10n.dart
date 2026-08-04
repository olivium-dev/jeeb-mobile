import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

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

  String get title => _l10n.orderSummaryTitle;

  String get openChat => _l10n.orderSummaryOpenChat;

  String get track => _l10n.orderSummaryTrack;

  String get priceLabel => _pick('Price', 'السعر');

  String get cashLabel => _pick('Pay cash on delivery', 'ادفع نقداً عند التسليم');

  String get etaLabel => _l10n.trackingEtaLabel;

  String etaMinutes(int minutes) => _l10n.trackingEtaMinutes(minutes);

  String get etaPending => _pick('ETA pending', 'الوقت المقدّر قيد التحديد');

  String get tierLabel => _l10n.deliveryTierLabel;

  String get tierPending => _l10n.orderSummaryValuePending;

  String get itemLabel => _pick('Item', 'الطلب');

  /// TODO(midnight): l10n-queued — `orderSummaryErrorTitle`; this two-sentence
  /// blob repeats "try again" over the network body.
  String get errorGeneric => _l10n.requestSummaryErrorGeneric;

  /// TODO(midnight): l10n-queued — `orderSummaryNotFoundTitle`.
  String get notFoundTitle => _l10n.receiptErrorNotFound;

  String get errorNetworkBody => _l10n.orderHistoryErrorNetwork;

  String get errorServerBody => _l10n.orderHistoryErrorServer;

  String get retryLabel => _l10n.trackingGpsLostRetry;

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

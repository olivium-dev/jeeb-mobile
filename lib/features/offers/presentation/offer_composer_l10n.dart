import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// JM-045 / JM-046 localized copy resolver (R-F, 40_GUARDRAILS_ARCH §9 l10n
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

  String get title => _l10n.offerSubmissionTitle;

  String get closeTooltip => _l10n.offerSubmitWithdrawTooltip;

  String orderRef(String ref) =>
      _pick('Your offer · $ref', 'عرضك · $ref');

  String get intro => _l10n.offerSubmissionIntro;

  String get priceLabel => _l10n.offerSubmissionFeeLabel;

  String get etaLabel => _l10n.offerSubmissionEtaLabel;

  String get noteLabel =>
      _pick('Describe your offer (optional)', 'صِف عرضك (اختياري)');

  String get noteHint => _pick(
        'e.g. On my way now — I can pick up in 5 minutes.',
        'مثال: أنا في الطريق الآن — يمكنني الاستلام خلال ٥ دقائق.',
      );

  String get etaPlaceholder => _pick('Select pickup ETA', 'اختر وقت الاستلام');

  String get etaSheetTitle => _pick('Pickup ETA', 'وقت الاستلام');

  String etaOption(int minutes) => _pick('$minutes min', '$minutes دقيقة');

  String feeLine(String amount, String currency) => _pick(
        'Platform fee (10%): $amount $currency',
        'رسوم المنصة (١٠٪): $amount $currency',
      );

  String get feeLinePending => _pick(
        'Platform fee: 10% of your offer',
        'رسوم المنصة: ١٠٪ من عرضك',
      );

  String netLine(String amount, String currency) => _pick(
        'You earn (cash): $amount $currency',
        'تربح (نقداً): $amount $currency',
      );

  String get netLinePending => _pick(
        'You earn (cash): your full offer, paid by the customer',
        'تربح (نقداً): كامل عرضك، يدفعه العميل',
      );

  String reserveNote(String amount, String currency) => _pick(
        '$amount $currency reserved now from your wallet · charged only if you '
            'win · released if you don’t.',
        'يُحجز الآن $amount $currency من محفظتك · يُخصم فقط إذا فزت · '
            'يُعاد إن لم تفز.',
      );

  String get reserveNotePending => _pick(
        '10% is reserved now from your wallet · charged only if you win · '
            'released if you don’t.',
        'يُحجز الآن ١٠٪ من محفظتك · يُخصم فقط إذا فزت · يُعاد إن لم تفز.',
      );

  String get sendCta => _l10n.offerSubmissionSubmitButton;

  String get requestGone => _l10n.offerSubmitRequestGone;

  String get errorGeneric =>
      _pick('Couldn’t send your offer. Please try again.',
          'تعذّر إرسال عرضك. يرجى المحاولة مجدداً.');

  String get errorNetwork =>
      _pick('No connection. Check your network and try again.',
          'لا يوجد اتصال. تحقق من شبكتك وحاول مجدداً.');

  String get insufficientTitle =>
      _pick('Not enough balance', 'الرصيد غير كافٍ');

  String get insufficientBody => _pick(
        'Top up your wallet to reserve the 10% and send this offer.',
        'اشحن محفظتك لحجز الـ ١٠٪ وإرسال هذا العرض.',
      );

  String insufficientNeeded(String amount, String currency) =>
      _pick('Needed: $amount $currency', 'المطلوب: $amount $currency');

  String insufficientAvailable(String amount, String currency) =>
      _pick('Available: $amount $currency', 'المتوفر: $amount $currency');

  String get insufficientTopUpCta => _l10n.walletTopUpCta;

  String get insufficientKeepEditingCta =>
      _pick('Keep editing', 'متابعة التعديل');
}

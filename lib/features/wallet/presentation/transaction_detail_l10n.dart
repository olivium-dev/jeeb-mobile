import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/wallet_ledger_repository.dart';

class TransactionDetailL10n {
  TransactionDetailL10n(this._l10n, this._isArabic);

  factory TransactionDetailL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return TransactionDetailL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  String get title => _l10n.txnDetailTitle;
  String get orderLink => _l10n.txnDetailOrderLink;
  String get disputeLink => _l10n.txnDetailDisputeLink;
  String get loadingHeadline => _l10n.txnDetailLoadingHeadline;
  String get errorTitle => _l10n.txnDetailErrorTitle;

  String typeHeading(WalletLedgerType type) {
    switch (type) {
      case WalletLedgerType.reserve:
        return _pick('Offer reserve held', 'حجز العرض محتجز');
      case WalletLedgerType.feeWon:
        return _pick('Platform fee', 'رسوم المنصة');
      case WalletLedgerType.released:
        return _pick('Reserve released', 'تم تحرير الحجز');
      case WalletLedgerType.refund:
        return _pick('Fee balance adjustment', 'تسوية رصيد الرسوم');
      case WalletLedgerType.penalty:
        return _pick('Dispute penalty', 'غرامة نزاع');
      case WalletLedgerType.topup:
        return _pick('Fee balance added', 'إضافة رصيد الرسوم');
      case WalletLedgerType.gift:
        return _pick('Starter credit', 'رصيد بداية');
      case WalletLedgerType.unknown:
        return _pick('Transaction', 'معاملة');
    }
  }

  String typeBody(WalletLedgerType type) {
    switch (type) {
      case WalletLedgerType.reserve:
        return _pick(
          'A 10% reserve is held against this offer. It is released if you '
              'do not win, or captured as the fee if you do.',
          'يُحتجز حجز ١٠٪ مقابل هذا العرض. يُعاد إن لم تفز، أو يُؤخذ كرسوم إن '
              'فزت.',
        );
      case WalletLedgerType.feeWon:
        return _pick(
          'The flat 10% platform fee for an offer you won, taken from your '
              'pre-charged balance.',
          'رسوم المنصة الثابتة ١٠٪ عن عرض فزت به، تُؤخذ من رصيدك المشحون مسبقاً.',
        );
      case WalletLedgerType.released:
        return _pick(
          'The reserve held against this offer was returned to your '
              'available balance.',
          'أُعيد الحجز المحتجز مقابل هذا العرض إلى رصيدك المتاح.',
        );
      case WalletLedgerType.refund:
        return _pick(
          'An internal fee-balance adjustment recorded after a resolved '
              'dispute.',
          'تسوية داخلية لرصيد الرسوم سُجّلت بعد حسم نزاع.',
        );
      case WalletLedgerType.penalty:
        return _pick(
          'A penalty charged to your wallet from a resolved dispute.',
          'غرامة خُصمت من محفظتك من نزاع تم حله.',
        );
      case WalletLedgerType.topup:
        return _pick(
          'Cash added to your Jeeber fee balance at an authorized store.',
          'رصيد رسوم أُضيف نقداً في متجر معتمد.',
        );
      case WalletLedgerType.gift:
        return _pick(
          'Non-cash, non-withdrawable starter credit granted after '
              'verification.',
          'رصيد بداية غير نقدي وغير قابل للسحب مُنح بعد التحقق.',
        );
      case WalletLedgerType.unknown:
        return _l10n.txnDetailBody;
    }
  }

  String get amountLabel => _pick('Amount', 'المبلغ');
  String get dateLabel => _pick('Date', 'التاريخ');
  String get referenceLabel => _pick('Reference', 'المرجع');
  String get feeRateLabel => _pick('Platform fee', 'رسوم المنصة');
  String get pinnedPriceLabel => _pick('Accepted price', 'السعر المقبول');
  String get disputeRefLabel => _pick('Dispute', 'النزاع');

  String signedAmount(int sign, String formattedAmount, String currency) {
    final prefix = sign < 0 ? '-' : '+';
    final ccy = currency.isEmpty ? '' : ' $currency';
    return '$prefix$formattedAmount$ccy';
  }

  String feePercentText(double percent) {
    final whole = percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return '$whole%';
  }

  String get loadErrorNotFound => _pick(
    'This transaction could not be found.',
    'تعذّر العثور على هذه المعاملة.',
  );
  String get loadErrorGeneric => _pick(
    'We couldn’t load this transaction. Please try again.',
    'تعذّر تحميل هذه المعاملة. حاول مرة أخرى.',
  );
  String get retry => _pick('Retry', 'إعادة المحاولة');
}

import 'package:flutter/widgets.dart';

import '../../../core/formatting/server_time.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wallet_ledger_repository.dart';

class WalletActivityL10n {
  WalletActivityL10n(this._l10n, this._isArabic);

  factory WalletActivityL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return WalletActivityL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  String get title => _l10n.walletActivityTitle;
  String get emptyTitle => _l10n.walletActivityEmptyTitle;
  String get emptyBody => _l10n.walletActivityEmptyBody;
  String get loadingHeadline => _l10n.walletActivityLoadingHeadline;
  String get errorTitle => _l10n.walletActivityErrorTitle;

  String get networkError => _l10n.errorNetworkBody;
  String get retry => _l10n.actionRetry;

  String get loadMoreError => _l10n.walletActivityLoadMoreFailed;

  /// Footer line naming rows the gateway sent that could not be read (UX-17).
  String get unrenderable => _l10n.walletEntryUnrenderable;

  String typeLabel(WalletLedgerType type) {
    switch (type) {
      case WalletLedgerType.reserve:
        return _pick('Reserved', 'محجوز');
      case WalletLedgerType.feeWon:
        return _pick('Fee', 'رسوم');
      case WalletLedgerType.released:
        return _pick('Released', 'تم الإفراج');
      case WalletLedgerType.refund:
        return _pick('Fee balance adjustment', 'تسوية رصيد الرسوم');
      case WalletLedgerType.penalty:
        return _pick('Penalty', 'غرامة');
      case WalletLedgerType.topup:
        return _pick('Fee balance added', 'إضافة رصيد الرسوم');
      case WalletLedgerType.gift:
        return _pick('Starter credit', 'رصيد بداية');
      case WalletLedgerType.unknown:
        return _pick('Activity', 'حركة');
    }
  }

  String refLabel(String ref) =>
      ref.isEmpty ? '' : _pick('Ref: $ref', 'مرجع: $ref');

  String signedAmount(double amount, int sign, String? currency) {
    final magnitude = amount.abs().toStringAsFixed(2);
    final prefix = sign < 0 ? '-' : '+';
    final suffix = (currency != null && currency.isNotEmpty)
        ? ' $currency'
        : '';
    return '$prefix$magnitude$suffix';
  }

  String relativeTime(String timestamp, {DateTime? now}) {
    final ts = ServerTime.parse(timestamp);
    if (ts == null) return timestamp;
    final reference = now ?? DateTime.now();
    final diff = reference.difference(ts);
    if (diff.isNegative || diff.inMinutes < 1) return _pick('Just now', 'الآن');
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return _pick('${m}m ago', 'قبل $m د');
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return _pick('${h}h ago', 'قبل $h س');
    }
    final d = diff.inDays;
    return _pick('${d}d ago', 'قبل $d ي');
  }
}

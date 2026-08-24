import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/notifications_repository.dart';

class NotificationsL10n {
  NotificationsL10n(this._l10n, this._isArabic);

  factory NotificationsL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return NotificationsL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  String get title => _l10n.notificationsTitle;
  String get emptyTitle => _l10n.notificationsEmptyTitle;
  String get emptyBody => _l10n.notificationsEmptyBody;
  String get loadingHeadline => _l10n.notificationsLoadingHeadline;
  String get errorTitle => _l10n.notificationsErrorTitle;

  String get networkError => _pick(
    'No connection. Check your network and try again.',
    'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
  );
  String get retry => _pick('Retry', 'إعادة المحاولة');

  String categoryLabel(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.offer:
        return _pick('New offer', 'عرض جديد');
      case NotificationKind.offerAccepted:
        return _pick('Offer accepted', 'تم قبول العرض');
      case NotificationKind.status:
        return _pick('Order update', 'تحديث الطلب');
      case NotificationKind.lowBalance:
        return _pick('Low balance', 'رصيد منخفض');
      case NotificationKind.feeWon:
        return _pick('Fee captured', 'تم خصم الرسوم');
      case NotificationKind.refundPenalty:
        return _pick('Dispute outcome', 'نتيجة النزاع');
      case NotificationKind.topup:
        return _pick('Top-up received', 'تم شحن الرصيد');
      case NotificationKind.kycApproved:
        return _pick('KYC approved', 'تمت الموافقة على التحقق');
      case NotificationKind.kycRejected:
        return _pick('KYC rejected', 'تم رفض التحقق');
      case NotificationKind.requestExpired:
        return _pick('Request expired', 'انتهت صلاحية الطلب');
      case NotificationKind.newRequest:
        return _pick('New request', 'طلب جديد');
      case NotificationKind.confirmReceipt:
        return _pick('Confirm receipt', 'تأكيد الاستلام');
      case NotificationKind.marketing:
        return _pick('Jeeb', 'جيب');
      case NotificationKind.dispute:
        return _pick('Dispute', 'نزاع');
      case NotificationKind.support:
        return _pick('Support', 'الدعم');
      case NotificationKind.offerWithdrawnInsufficientBalance:
        return _l10n.notificationsKindWalletWithdrawnLabel;
      case NotificationKind.unknown:
        return _pick('Notification', 'إشعار');
    }
  }

  String get unreadLabel => _pick('Unread', 'غير مقروء');

  // CONTRACT §5 P-1/P-2 — rendered locally so the wallet-guard push reads in
  // Arabic; the gateway's EN wire copy is byte-identical by contract.
  String get offerWithdrawnTitle => _l10n.walletGuardPushOfferWithdrawnTitle;
  String get offerWithdrawnBody => _l10n.walletGuardPushOfferWithdrawnBody;

  String get newRequestFallbackTitle =>
      _pick('New request nearby', 'طلب جديد بالقرب منك');
  String get newRequestFallbackBody => _pick(
    'A customer is looking for a jeeber. Tap to view.',
    'أحد الزبائن يبحث عن جيب. اضغط لعرض الطلب.',
  );

  String relativeTime(String timestamp, {DateTime? now}) {
    var ts = DateTime.tryParse(timestamp);
    if (ts == null) return timestamp;
    if (!ts.isUtc) {
      ts = DateTime.utc(
        ts.year,
        ts.month,
        ts.day,
        ts.hour,
        ts.minute,
        ts.second,
        ts.millisecond,
        ts.microsecond,
      );
    }
    final reference = now ?? DateTime.now();
    final diff = reference.difference(ts);
    if (diff.isNegative) return _pick('Just now', 'الآن');
    if (diff.inMinutes < 1) return _pick('Just now', 'الآن');
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

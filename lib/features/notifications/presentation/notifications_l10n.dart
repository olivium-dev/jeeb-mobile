import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/notifications_repository.dart';

/// Notifications copy accessors. Failure copy never lives here — it comes
/// from `failureCopy`.
class NotificationsL10n {
  NotificationsL10n(this._l10n);

  factory NotificationsL10n.of(BuildContext context) =>
      NotificationsL10n(AppLocalizations.of(context));

  final AppLocalizations _l10n;

  String get title => _l10n.notificationsTitle;
  String get emptyTitle => _l10n.notificationsEmptyTitle;
  String get emptyBody => _l10n.notificationsEmptyBody;
  String get loadingHeadline => _l10n.notificationsLoadingHeadline;
  String get errorTitle => _l10n.notificationsErrorTitle;

  String categoryLabel(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.offer:
        return _l10n.notificationsCategoryLabelOffer;
      case NotificationKind.offerAccepted:
        return _l10n.notificationsCategoryLabelOfferAccepted;
      case NotificationKind.status:
        return _l10n.notificationsCategoryLabelStatus;
      case NotificationKind.lowBalance:
        return _l10n.notificationsCategoryLabelLowBalance;
      case NotificationKind.feeWon:
        return _l10n.notificationsCategoryLabelFeeWon;
      case NotificationKind.refundPenalty:
        return _l10n.notificationsCategoryLabelRefundPenalty;
      case NotificationKind.topup:
        return _l10n.notificationsCategoryLabelTopup;
      case NotificationKind.kycApproved:
        return _l10n.notificationsCategoryLabelKycApproved;
      case NotificationKind.kycRejected:
        return _l10n.notificationsCategoryLabelKycRejected;
      case NotificationKind.requestExpired:
        return _l10n.notificationsCategoryLabelRequestExpired;
      case NotificationKind.newRequest:
        return _l10n.notificationsCategoryLabelNewRequest;
      case NotificationKind.confirmReceipt:
        return _l10n.notificationsCategoryLabelConfirmReceipt;
      case NotificationKind.marketing:
        return _l10n.notificationsCategoryLabelMarketing;
      case NotificationKind.dispute:
        return _l10n.notificationsCategoryLabelDispute;
      case NotificationKind.support:
        return _l10n.notificationsCategoryLabelSupport;
      case NotificationKind.unknown:
        return _l10n.notificationsCategoryLabelUnknown;
      case NotificationKind.chat:
        return _l10n.notificationsCategoryLabelChat;
      case NotificationKind.availability:
        return _l10n.notificationsCategoryLabelAvailability;
    }
  }

  String get unreadLabel => _l10n.notificationsUnreadLabel;

  String get newRequestFallbackTitle =>
      _l10n.notificationsNewRequestFallbackTitle;
  String get newRequestFallbackBody =>
      _l10n.notificationsNewRequestFallbackBody;

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
    if (diff.isNegative || diff.inMinutes < 1) return _l10n.timeJustNow;
    if (diff.inMinutes < 60) return _l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return _l10n.timeHoursAgo(diff.inHours);
    return _l10n.timeDaysAgo(diff.inDays);
  }
}

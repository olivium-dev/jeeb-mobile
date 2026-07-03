import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/notifications_repository.dart';

/// JM-057 notifications-list localized copy resolver (R-F; the
/// `wallet_hub_l10n.dart` / `offer_composer_l10n.dart` precedent,
/// 40_GUARDRAILS_ARCH §9 l10n protocol).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned (50_EXECUTION_PLAN §S4). The W4 integrator batched THREE
/// notifications keys (title / empty-title / empty-body), but the rest of the
/// inbox copy — the load-error + retry, the eight typed-row category labels, and
/// the relative timestamp — is NOT yet present. Per the JM-053 precedent this
/// resolver reuses the EXISTING getters where one fits and supplies the
/// genuinely-missing strings from a feature-local EN/AR map until the integrator
/// lands the dedicated keys (REQUESTED in `50_ROUTE_REQUESTS.md`, "JM-057").
///
/// Maestro asserts on `Semantics(identifier:)` ONLY (41_GUARDRAILS_TESTING §4),
/// so the visible copy is cosmetic — this swaps to the real getters with no
/// call-site change. Delete this file (fold the `_pick` strings into `notif*`
/// ARB getters) once the integrator lands the requested keys.
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

  // ── Present keys (integrator-landed). ──────────────────────────────────────
  String get title => _l10n.notificationsTitle;
  String get emptyTitle => _l10n.notificationsEmptyTitle;
  String get emptyBody => _l10n.notificationsEmptyBody;

  // ── Genuinely-missing copy (feature-local until the integrator lands keys). ─
  String get loadError =>
      _pick('Could not load notifications.', 'تعذّر تحميل الإشعارات.');
  String get networkError => _pick(
        'No connection. Check your network and try again.',
        'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
      );
  String get retry => _pick('Retry', 'إعادة المحاولة');

  /// Per-kind category label rendered as the row's leading line (cosmetic — the
  /// row's actual `title`/`body` come from the notification payload). Mirrors
  /// the D84 dispatch classes.
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
      case NotificationKind.unknown:
        return _pick('Notification', 'إشعار');
    }
  }

  /// "Unread" affordance label (accessibility only — the badge itself is a dot).
  String get unreadLabel => _pick('Unread', 'غير مقروء');

  /// Coarse relative time for a parsed [timestamp]. Locale-agnostic enough to
  /// stay cosmetic (flows never assert on it). Falls back to the raw string
  /// when the timestamp is unparseable.
  ///
  /// SW-03/G3 device-local correctness: notification-service timestamps are
  /// UTC instants. A zone-less ISO string (no `Z`, no `±hh:mm`) would parse
  /// as device-LOCAL and skew the age by the device's UTC offset (a fresh
  /// row reading "2h ago"), so it is re-interpreted as UTC before diffing.
  /// The subtraction itself is epoch-based, so mixing a UTC instant with the
  /// local `now` is exact.
  String relativeTime(String timestamp, {DateTime? now}) {
    var ts = DateTime.tryParse(timestamp);
    if (ts == null) return timestamp;
    if (!ts.isUtc) {
      // Parsed without an explicit zone → Dart assumed device-local.
      // Re-stamp the same wall-clock fields as UTC (the server's zone).
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

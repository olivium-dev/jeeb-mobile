import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/account_status.dart';

class AccountStatusL10n {
  AccountStatusL10n(this._l10n, this._isArabic);

  factory AccountStatusL10n.of(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AccountStatusL10n(l10n, l10n.locale.languageCode == 'ar');
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String get title => _l10n.accountStatusTitle;
  String get genericBody => _l10n.accountStatusBody;
  String get supportCta => _l10n.accountStatusSupportCta;
  String get signoutCta => _l10n.accountStatusSignoutCta;

  String banner(AccountStatusValue value) => _pick(
        value,
        suspendedEn: 'Your account is suspended',
        suspendedAr: 'تم تعليق حسابك',
        lockedEn: 'Your account is locked',
        lockedAr: 'تم قفل حسابك',
      );

  String defaultReason(AccountStatusValue value) => _pick(
        value,
        suspendedEn:
            'Your account is under review. Contact support to resolve it, '
            'or sign out.',
        suspendedAr:
            'حسابك قيد المراجعة. تواصل مع الدعم لحلّ المشكلة، أو سجّل الخروج.',
        lockedEn:
            'Your account has been locked for security. Contact support to '
            'restore access, or sign out.',
        lockedAr:
            'تم قفل حسابك لأسباب أمنية. تواصل مع الدعم لاستعادة الوصول، '
            'أو سجّل الخروج.',
      );

  /// Phase V D16 — localized copy for ban-service's own policy keys.
  ///
  /// ban-service is generic: it ships `Label{{Ban.Label.…}}` templates and has
  /// neither a locale nor a string catalogue, so the KEY is the only thing it
  /// can meaningfully hand a client. This is that lookup. Returns null for a
  /// key this build does not know, so the caller falls back to
  /// [defaultReason] rather than printing a raw key at the user.
  String? reasonForCode(String? code) {
    switch (code?.trim()) {
      case 'Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS':
        return _isArabic
            ? 'تم تعليق حسابك لمدة 3 أيام. تواصل مع الدعم، أو سجّل الخروج.'
            : 'Your account is suspended for 3 days. Contact support, or '
                'sign out.';
      case 'Ban.Label.YOU_ARE_BANNED_FOR_1_HOUR':
        return _isArabic
            ? 'تم تعليق حسابك لمدة ساعة واحدة. تواصل مع الدعم، أو سجّل الخروج.'
            : 'Your account is suspended for 1 hour. Contact support, or '
                'sign out.';
      case 'Ban.Label.YOU_ARE_BANNED':
        return _isArabic
            ? 'تم حظر حسابك نهائيًا. تواصل مع الدعم، أو سجّل الخروج.'
            : 'Your account has been permanently banned. Contact support, or '
                'sign out.';
      case 'Ban.Label.YOU_WILL_BE_BANNED_AFTER_ONE_WARNING':
        return _isArabic
            ? 'هذا تحذير أخير: مخالفة أخرى تؤدي إلى حظر حسابك.'
            : 'This is a final warning: one more violation will ban your '
                'account.';
      default:
        return null;
    }
  }

  String get loadingHeadline => _l10n.accountStatusLoadingHeadline;

  /// The two halves of the shipped `loadError` sentence, split at its own full
  /// stop so the Midnight error block gets a headline + body with nothing
  /// invented and nothing dropped.
  String get loadErrorTitle => _isArabic
      ? 'تعذّر تحميل حالة الحساب'
      : "Couldn't load your account status";

  String get loadError => _isArabic
      ? 'تحقّق من اتصالك وحاول مجددًا.'
      : 'Check your connection and try again.';

  String get retry => _isArabic ? 'إعادة المحاولة' : 'Retry';

  String _pick(
    AccountStatusValue value, {
    required String suspendedEn,
    required String suspendedAr,
    required String lockedEn,
    required String lockedAr,
  }) {
    switch (value) {
      case AccountStatusValue.locked:
        return _isArabic ? lockedAr : lockedEn;
      case AccountStatusValue.suspended:
        return _isArabic ? suspendedAr : suspendedEn;
    }
  }
}

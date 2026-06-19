import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/account_status.dart';

/// Feature-local EN/AR copy resolver for `account-status` (JM-066), following
/// the JM-008 / JM-031 precedent: the ARB is integrator-owned, so the
/// per-blocked-state banner + reason strings live here (feature-local map) and
/// reuse the EXISTING integrator-batched `accountStatus*` getters where one
/// fits. Maestro asserts on `Semantics(identifier:)` only (R-B), so these
/// strings are cosmetic — an l10n KEY REQUEST is filed in 50_ROUTE_REQUESTS so
/// a polish pass can move them into the ARB and delete this resolver.
///
/// Reused (already in both ARBs, via [AppLocalizations]):
///   title           → `accountStatusTitle`   ("Account unavailable")
///   genericBody     → `accountStatusBody`     ("…suspended or locked…")
///   supportCta      → `accountStatusSupportCta`
///   signoutCta      → `accountStatusSignoutCta`
class AccountStatusL10n {
  AccountStatusL10n(this._l10n, this._isArabic);

  factory AccountStatusL10n.of(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AccountStatusL10n(l10n, l10n.locale.languageCode == 'ar');
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  // --- reused integrator-batched keys ---
  String get title => _l10n.accountStatusTitle;
  String get genericBody => _l10n.accountStatusBody;
  String get supportCta => _l10n.accountStatusSupportCta;
  String get signoutCta => _l10n.accountStatusSignoutCta;

  // --- feature-local per-state copy (l10n KEY REQUEST filed) ---

  /// Short banner headline for the blocked state.
  String banner(AccountStatusValue value) => _pick(
        value,
        suspendedEn: 'Your account is suspended',
        suspendedAr: 'تم تعليق حسابك',
        lockedEn: 'Your account is locked',
        lockedAr: 'تم قفل حسابك',
      );

  /// Default per-state reason (used when the server supplies no explicit
  /// `statusReason`). The screen prefers the server reason when present.
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

  /// Transport-failure copy for the status read (D30 error state). Reuses no
  /// ARB key (none scoped); kept feature-local.
  String get loadError => _isArabic
      ? 'تعذّر تحميل حالة الحساب. تحقّق من اتصالك وحاول مجددًا.'
      : "Couldn't load your account status. Check your connection and try again.";

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

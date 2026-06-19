import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/wallet_repository.dart';

/// JM-053 wallet-hub localized copy resolver (R-F, 40_GUARDRAILS_ARCH §9 l10n
/// protocol; JM-031 `order_summary_l10n.dart` / JM-045 `offer_composer_l10n.dart`
/// precedent).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned (50_EXECUTION_PLAN §S4). The W2 integrator batched FIVE
/// wallet-hub keys (title / available-balance / top-up / load-error / retry),
/// but the rest of the hub copy — the gift badge (D42), the four affordability
/// states (D43), reserved-now (D1), the how-fees explainer (D41/D44), the
/// earnings + activity rows, and the KYC-pending banner (D38/D39) — is NOT yet
/// present. Per the JM-031/JM-045 precedent, this resolver reuses the EXISTING
/// localized getters where one fits and supplies the genuinely-missing strings
/// from a feature-local EN/AR map until the integrator lands the dedicated keys
/// (REQUESTED in `50_ROUTE_REQUESTS.md`, "JM-053"). Maestro asserts on
/// `Semantics(identifier:)` only, so the visible copy is cosmetic — this swaps
/// to the real getters with no call-site change.
///
/// Delete this file (fold the `_pick` strings into the `wallet*` ARB getters)
/// once the integrator lands the keys requested in `50_ROUTE_REQUESTS.md`.
class WalletHubL10n {
  WalletHubL10n(this._l10n, this._isArabic, {this.kycPending = false});

  factory WalletHubL10n.of(BuildContext context, {bool kycPending = false}) {
    final locale = Localizations.localeOf(context);
    return WalletHubL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
      kycPending: kycPending,
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  /// True when the Jeeber's KYC is pending (AC7) — drives the pending banner.
  final bool kycPending;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  // ── Present keys (integrator-landed). ─────────────────────────────────────
  String get title => _l10n.walletHubTitle;
  String get availableBalanceLabel => _l10n.walletAvailableBalanceLabel;
  String get topUpCta => _l10n.walletTopUpCta;
  String get loadError => _l10n.walletHubLoadError;
  String get retry => _l10n.walletHubRetry;

  // ── Gift / starter-credit badge (D42). ────────────────────────────────────
  String giftBadge(String amount, String currency) => _pick(
        '$amount $currency starter credit',
        'رصيد بداية $amount $currency',
      );

  // ── Reserved-now (sum of live 10% reserves, D1). ──────────────────────────
  String get reservedNowLabel => _pick('Reserved now', 'محجوز الآن');
  String get reservedNowHint => _pick(
        'Held against your live offers — released when each offer is decided.',
        'محجوز مقابل عروضك النشطة — يُعاد عند البتّ في كل عرض.',
      );

  // ── How fees work explainer (fee-only economics, D41/D44). ────────────────
  String get howFeesWork => _pick('How fees work', 'كيف تعمل الرسوم');
  String get feesExplainerTitle => _pick('How fees work', 'كيف تعمل الرسوم');
  String get feesExplainerLine1 => _pick(
        'You only pay a flat 10% fee on offers you win.',
        'تدفع رسوماً ثابتة ١٠٪ فقط على العروض التي تفوز بها.',
      );
  String get feesExplainerLine2 => _pick(
        'The fee is taken from your pre-charged wallet balance — never in-app.',
        'تُؤخذ الرسوم من رصيد محفظتك المشحون مسبقاً — وليس داخل التطبيق.',
      );
  String get feesExplainerLine3 => _pick(
        'The customer pays you the delivery price in cash on delivery.',
        'يدفع لك العميل سعر التوصيل نقداً عند التسليم.',
      );
  String get feesExplainerGotIt => _pick('Got it', 'حسناً');

  // ── Earnings + activity rows (cross-wave, AP-9). ──────────────────────────
  String get earningsRow => _pick('Earnings & fees', 'الأرباح والرسوم');
  String get earningsRowSubtitle => _pick(
        'Your net cash and the fees you’ve paid.',
        'صافي النقد والرسوم التي دفعتها.',
      );
  String get seeAllActivity => _pick('See all activity', 'عرض كل النشاط');
  String get seeAllActivitySubtitle => _pick(
        'Reserves, fees, refunds and top-ups.',
        'الحجوزات والرسوم والمستردات والشحن.',
      );

  // ── KYC-pending banner (D38/D39). ─────────────────────────────────────────
  String get kycPendingTitle =>
      _pick('Verification in progress', 'التحقق قيد المعالجة');
  String get kycPendingBody => _pick(
        'You can top up now. You’ll be able to make offers once your '
            'verification is approved.',
        'يمكنك الشحن الآن. وستتمكن من تقديم العروض بمجرد الموافقة على تحققك.',
      );

  // ── Offline money guard (D35). ────────────────────────────────────────────
  String get offlineMoneyBlocked => _pick(
        'You’re offline — reconnect to add funds.',
        'أنت غير متصل — أعد الاتصال لإضافة رصيد.',
      );

  // ── Cross-wave guarded-CTA notice (AP-9). Reuses the shell "Coming soon". ──
  String get comingSoon => _l10n.shellComingSoon;

  // ── Affordability state copy (D43 — STATE, NOT a capacity number). ────────
  String affordabilityTitle(WalletAffordability a) {
    switch (a) {
      case WalletAffordability.enough:
        return _pick('Ready to bid', 'جاهز للمزايدة');
      case WalletAffordability.low:
        return _pick('Running low', 'الرصيد منخفض');
      case WalletAffordability.empty:
        return _pick('Top up to bid', 'اشحن لتزايد');
      case WalletAffordability.allReserved:
        return _pick('Everything is reserved', 'كل الرصيد محجوز');
    }
  }

  String affordabilityBody(WalletAffordability a) {
    switch (a) {
      case WalletAffordability.enough:
        return _pick(
          'You have enough to place offers.',
          'لديك ما يكفي لتقديم العروض.',
        );
      case WalletAffordability.low:
        return _pick(
          'Your balance is low — top up to keep bidding.',
          'رصيدك منخفض — اشحن لمتابعة المزايدة.',
        );
      case WalletAffordability.empty:
        return _pick(
          'Add funds to start making offers.',
          'أضف رصيداً لبدء تقديم العروض.',
        );
      case WalletAffordability.allReserved:
        return _pick(
          'Your funds are all held against live offers. Top up to bid on more.',
          'كل أموالك محجوزة مقابل عروض نشطة. اشحن لتزايد على المزيد.',
        );
    }
  }
}

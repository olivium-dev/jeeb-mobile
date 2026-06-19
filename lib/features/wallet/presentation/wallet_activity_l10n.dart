import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/wallet_ledger_repository.dart';

/// JM-055 wallet-activity-list localized copy resolver (R-F; the
/// `wallet_hub_l10n.dart` / `notifications_l10n.dart` precedent,
/// 40_GUARDRAILS_ARCH §9 l10n protocol).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned (50_EXECUTION_PLAN §S4). The W3 integrator batched FOUR
/// wallet-activity keys (title / empty-title / empty-body / back-cta), but the
/// rest of the ledger copy — the seven typed-row labels (Reserve / Fee-won /
/// Released / Refund / Penalty / Top up / Gift, D41/D1/D37/D2), the load-error +
/// retry, the load-more-error retry, and the relative timestamp — is NOT yet
/// present. Per the JM-053 precedent this resolver reuses the EXISTING getters
/// where one fits and supplies the genuinely-missing strings from a feature-local
/// EN/AR map until the integrator lands the dedicated keys (REQUESTED in
/// `50_ROUTE_REQUESTS.md`, "JM-055").
///
/// Maestro asserts on `Semantics(identifier:)` ONLY (41_GUARDRAILS_TESTING §4),
/// so the visible copy is cosmetic — this swaps to the real getters with no
/// call-site change. Delete this file (fold the `_pick` strings into
/// `walletActivity*` ARB getters) once the integrator lands the requested keys.
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

  // ── Present keys (integrator-landed). ──────────────────────────────────────
  String get title => _l10n.walletActivityTitle;
  String get emptyTitle => _l10n.walletActivityEmptyTitle;
  String get emptyBody => _l10n.walletActivityEmptyBody;

  // ── Genuinely-missing copy (feature-local until the integrator lands keys). ─
  String get loadError =>
      _pick('Could not load your activity.', 'تعذّر تحميل نشاطك.');
  String get networkError => _pick(
        'No connection. Check your network and try again.',
        'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
      );
  String get retry => _pick('Retry', 'إعادة المحاولة');

  /// Footer shown when a next-page (load-more) fetch fails — soft + retryable;
  /// the already-loaded rows stay visible.
  String get loadMoreError =>
      _pick('Could not load more.', 'تعذّر تحميل المزيد.');

  /// The typed-row label rendered as the row's leading line (Reserve / Fee-won /
  /// Released / Refund / Penalty / Top up / Gift — the W2m `type` enum, D41).
  String typeLabel(WalletLedgerType type) {
    switch (type) {
      case WalletLedgerType.reserve:
        return _pick('Reserved', 'محجوز');
      case WalletLedgerType.feeWon:
        return _pick('Fee', 'رسوم');
      case WalletLedgerType.released:
        return _pick('Released', 'تم الإفراج');
      case WalletLedgerType.refund:
        return _pick('Refund', 'استرداد');
      case WalletLedgerType.penalty:
        return _pick('Penalty', 'غرامة');
      case WalletLedgerType.topup:
        return _pick('Top up', 'شحن رصيد');
      case WalletLedgerType.gift:
        return _pick('Starter credit', 'رصيد بداية');
      case WalletLedgerType.unknown:
        return _pick('Activity', 'حركة');
    }
  }

  /// The row's reference sub-line (the originating offer / dispute / store
  /// charge id). Cosmetic — flows key on the row id, not this text.
  String refLabel(String ref) => ref.isEmpty
      ? ''
      : _pick('Ref: $ref', 'مرجع: $ref');

  /// A signed, currency-suffixed amount string for the row's trailing value.
  /// `sign` is the W2m `+1` (credit) / `-1` (debit). The sign is EXPLICIT on
  /// every row (JM-055 AC: "amount + sign") so a credit reads `+0.90 USD` and a
  /// debit `-0.90 USD`.
  String signedAmount(double amount, int sign, String? currency) {
    final magnitude = amount.abs().toStringAsFixed(2);
    final prefix = sign < 0 ? '-' : '+';
    final suffix = (currency != null && currency.isNotEmpty) ? ' $currency' : '';
    return '$prefix$magnitude$suffix';
  }

  /// Coarse relative time for a parsed [timestamp] (mirrors the JM-057 row).
  /// Locale-agnostic enough to stay cosmetic; falls back to the raw string when
  /// the timestamp is unparseable.
  String relativeTime(String timestamp, {DateTime? now}) {
    final ts = DateTime.tryParse(timestamp);
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

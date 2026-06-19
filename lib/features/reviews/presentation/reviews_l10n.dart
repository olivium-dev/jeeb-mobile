import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// JM-068 reviews-list localized copy resolver (R-F; the `wallet_activity_l10n`
/// / `notifications_l10n` precedent, 40_GUARDRAILS_ARCH §9 l10n protocol).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned (50_EXECUTION_PLAN §S4). The W4 integrator batched THREE
/// reviews keys (title / empty-title / empty-body); the rest of the list copy —
/// the New badge (D59), the hidden-score / cold-start note (D59), the report
/// action + confirm, the load/error/retry strings, the relative timestamp, and
/// the count/aggregate labels — is NOT yet present. Per the JM-055 precedent
/// this resolver reuses the EXISTING getters where one fits and supplies the
/// genuinely-missing strings from a feature-local EN/AR map until the integrator
/// lands the dedicated keys (REQUESTED in `50_ROUTE_REQUESTS.md`, "JM-068").
///
/// Maestro asserts on `Semantics(identifier:)` ONLY (41_GUARDRAILS_TESTING §4),
/// so the visible copy is cosmetic — this swaps to the real getters with no
/// call-site change. Delete this file (fold the `_pick` strings into `reviews*`
/// ARB getters) once the integrator lands the requested keys.
class ReviewsL10n {
  ReviewsL10n(this._l10n, this._isArabic);

  factory ReviewsL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ReviewsL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  // -- Present keys (integrator-landed). --------------------------------------
  String get title => _l10n.reviewsTitle;
  String get emptyTitle => _l10n.reviewsEmptyTitle;
  String get emptyBody => _l10n.reviewsEmptyBody;

  // -- Genuinely-missing copy (feature-local until the integrator lands keys). -
  String get loadError =>
      _pick('Could not load reviews.', 'تعذّر تحميل التقييمات.');
  String get networkError => _pick(
        'No connection. Check your network and try again.',
        'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
      );
  String get retry => _pick('Retry', 'إعادة المحاولة');

  /// Footer shown when a next-page (load-more) fetch fails — soft + retryable;
  /// the already-loaded rows stay visible.
  String get loadMoreError =>
      _pick('Could not load more.', 'تعذّر تحميل المزيد.');

  /// The D59 "New" badge — shown while the jeeber has < 5 ratings (cold-start).
  String get newBadge => _pick('New', 'جديد');

  /// The D59 cold-start note — explains the aggregate score is hidden until the
  /// jeeber has enough reviews.
  String get hiddenScoreNote => _pick(
        'New Jeeber — overall score appears after a few completed deliveries.',
        'جيبر جديد — تظهر النتيجة الإجمالية بعد إتمام عدد من عمليات التوصيل.',
      );

  /// Aggregate header line: `4.6 · 10 reviews` (shown only when NOT cold-start).
  String aggregate(double averageScore, int reviewCount) {
    final score = averageScore.toStringAsFixed(1);
    final reviews = _pick('reviews', 'تقييمات');
    return _isArabic
        ? '$score · $reviewCount $reviews'
        : '$score · $reviewCount $reviews';
  }

  /// The per-row report affordance label (D27).
  String get reportAction => _pick('Report', 'إبلاغ');

  /// Report confirm dialog copy (D27).
  String get reportConfirmTitle =>
      _pick('Report this review?', 'الإبلاغ عن هذا التقييم؟');
  String get reportConfirmBody => _pick(
        "We'll send this review to our team to check it against our guidelines.",
        'سنرسل هذا التقييم إلى فريقنا لمراجعته وفق إرشاداتنا.',
      );
  String get reportConfirmCta => _pick('Report', 'إبلاغ');
  String get reportCancelCta => _pick('Cancel', 'إلغاء');

  /// One-shot snackbar copy after a report finishes.
  String get reportSuccess =>
      _pick('Thanks — this review was reported.', 'شكرًا — تم الإبلاغ عن التقييم.');
  String get reportFailure => _pick(
        "Couldn't report this review. Try again.",
        'تعذّر الإبلاغ عن التقييم. حاول مجددًا.',
      );

  /// Coarse relative time for a parsed [timestamp] (mirrors the JM-055 row).
  /// Falls back to the raw string when the timestamp is unparseable.
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

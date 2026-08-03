import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

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

  String get title => _l10n.reviewsTitle;
  String get emptyTitle => _l10n.reviewsEmptyTitle;
  String get emptyBody => _l10n.reviewsEmptyBody;

  String get loadError =>
      _pick('Could not load reviews.', 'تعذّر تحميل التقييمات.');
  String get networkError => _pick(
        'No connection. Check your network and try again.',
        'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
      );
  String get retry => _pick('Retry', 'إعادة المحاولة');

  String get loadMoreError =>
      _pick('Could not load more.', 'تعذّر تحميل المزيد.');

  String get newBadge => _pick('New', 'جديد');

  String get hiddenScoreNote => _pick(
        'New Jeeber — overall score appears after a few completed deliveries.',
        'جيبر جديد — تظهر النتيجة الإجمالية بعد إتمام عدد من عمليات التوصيل.',
      );

  String aggregate(double averageScore, int reviewCount) {
    final score = averageScore.toStringAsFixed(1);
    final reviews = _pick('reviews', 'تقييمات');
    return _isArabic
        ? '$score · $reviewCount $reviews'
        : '$score · $reviewCount $reviews';
  }

  String get reportAction => _pick('Report', 'إبلاغ');

  String get reportConfirmTitle =>
      _pick('Report this review?', 'الإبلاغ عن هذا التقييم؟');
  String get reportConfirmBody => _pick(
        "We'll send this review to our team to check it against our guidelines.",
        'سنرسل هذا التقييم إلى فريقنا لمراجعته وفق إرشاداتنا.',
      );
  String get reportConfirmCta => _pick('Report', 'إبلاغ');
  String get reportCancelCta => _pick('Cancel', 'إلغاء');

  String get reportSuccess =>
      _pick('Thanks — this review was reported.', 'شكرًا — تم الإبلاغ عن التقييم.');
  String get reportFailure => _pick(
        "Couldn't report this review. Try again.",
        'تعذّر الإبلاغ عن التقييم. حاول مجددًا.',
      );

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

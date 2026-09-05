import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// Reviews copy accessors. Failure copy never lives here — it comes from
/// `failureCopy`.
class ReviewsL10n {
  ReviewsL10n(this._l10n);

  factory ReviewsL10n.of(BuildContext context) =>
      ReviewsL10n(AppLocalizations.of(context));

  final AppLocalizations _l10n;

  String get title => _l10n.reviewsTitle;
  String get emptyTitle => _l10n.reviewsEmptyTitle;
  String get emptyBody => _l10n.reviewsEmptyBody;

  /// No `*Title` key ever doubles as a loading headline (gate 10).
  String get loadingHeadline => _l10n.reviewsLoadingHeadline;

  String get loadMoreError => _l10n.reviewsLoadMoreError;

  String get newBadge => _l10n.reviewsNewBadge;

  String get hiddenScoreNote => _l10n.reviewsHiddenScoreNote;

  String aggregate(double averageScore, int reviewCount) =>
      _l10n.reviewsAggregate(averageScore.toStringAsFixed(1), reviewCount);

  String get reportAction => _l10n.reviewsReportAction;

  String get reportConfirmTitle => _l10n.reviewsReportConfirmTitle;
  String get reportConfirmBody => _l10n.reviewsReportConfirmBody;
  String get reportConfirmCta => _l10n.reviewsReportConfirmCta;
  String get reportCancelCta => _l10n.reviewsReportCancelCta;

  String get reportSuccess => _l10n.reviewsReportSuccess;
  String get reportFailure => _l10n.reviewsReportFailure;

  String relativeTime(String timestamp, {DateTime? now}) {
    final ts = DateTime.tryParse(timestamp);
    if (ts == null) return timestamp;
    final reference = now ?? DateTime.now();
    final diff = reference.difference(ts);
    if (diff.isNegative || diff.inMinutes < 1) return _l10n.timeJustNow;
    if (diff.inMinutes < 60) return _l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return _l10n.timeHoursAgo(diff.inHours);
    return _l10n.timeDaysAgo(diff.inDays);
  }
}

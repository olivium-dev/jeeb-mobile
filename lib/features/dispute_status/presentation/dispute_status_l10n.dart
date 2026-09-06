import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/dispute_status_repository.dart';

/// JM-065 dispute-status copy accessors.
///
/// Every string reads straight through `AppLocalizations`. Failure copy never
/// lives here — it comes from `failureCopy`.
class DisputeStatusL10n {
  DisputeStatusL10n(this._l10n);

  factory DisputeStatusL10n.of(BuildContext context) =>
      DisputeStatusL10n(AppLocalizations.of(context));

  final AppLocalizations _l10n;

  // ── Present keys (integrator-landed). ──────────────────────────────────────
  String get title => _l10n.disputeStatusTitle;
  String get openLabel => _l10n.disputeStatusOpenLabel;
  String get openBody => _l10n.disputeStatusBody;
  String get supportCta => _l10n.disputeStatusSupportCta;
  String get backCta => _l10n.disputeStatusBackCta;

  String get pendingLabel => _l10n.disputeStatusPendingLabel;
  String get fixedLabel => _l10n.disputeStatusFixedLabel;
  String get closedLabel => _l10n.disputeStatusClosedLabel;

  /// First node of the lifecycle stepper — always `done` (the dispute exists,
  /// so it was submitted). Short by design: a stepper label is 10.5/w700.
  String get stepSubmittedLabel => _l10n.disputeStatusStepSubmitted;

  /// Legacy label retained for existing generated localization compatibility.
  String get stepUnderReviewLabel => _l10n.disputeStatusStepUnderReview;

  String get resolutionHeading => _l10n.disputeStatusResolutionHeading;
  String get fixedBody => _l10n.disputeStatusFixedBody;
  String get closedBody => _l10n.disputeStatusClosedBody;
  String get historyHeading => _l10n.disputeStatusHistoryHeading;
  String get historyEmpty => _l10n.disputeStatusHistoryEmpty;

  /// Body copy for a dispute whose outcome could not be read — never the
  /// load-error sentence (WP7-N2).
  String get statusUnavailableBody => _l10n.disputeStatusStatusUnavailableBody;

  String statusLabel(DisputeState state) => switch (state) {
    DisputeState.pending || DisputeState.open => pendingLabel,
    DisputeState.fixed || DisputeState.resolved => fixedLabel,
    DisputeState.closed => closedLabel,
    DisputeState.unknown => _l10n.disputeStatusStatusUnavailable,
  };

  // ── Evidence summary (D53). ────────────────────────────────────────────────
  String get evidenceHeading => _l10n.disputeStatusEvidenceHeading;

  String reasonLabel(String? reason) {
    switch (reason) {
      case 'damaged':
      case 'damaged_item':
        return _l10n.disputeStatusReasonDamaged;
      case 'wrong_item':
      case 'wrong-item':
        return _l10n.disputeStatusReasonWrongItem;
      case 'no_show':
      case 'no-show':
        return _l10n.disputeStatusReasonNoShow;
      case 'fraud':
        return _l10n.disputeStatusReasonFraud;
      case 'abuse':
        return _l10n.disputeStatusReasonAbuse;
      case null:
        return _l10n.disputeStatusReasonUnspecified;
      default:
        return _l10n.disputeStatusReasonOther;
    }
  }

  /// Headline of the inline empty-evidence block.
  String get evidenceEmptyHeadline => _l10n.disputeStatusEvidenceEmpty;
  String get evidencePartial => _l10n.disputeStatusEvidencePartial;
  String get evidenceUploadFailed => _l10n.disputeStatusEvidenceUploadFailed;

  String get evidenceReasonLabel => _l10n.disputeStatusEvidenceReasonLabel;
  String get evidenceCommentLabel => _l10n.disputeStatusEvidenceCommentLabel;

  String photosLabel(int count) => _l10n.disputeStatusPhotosAttached(count);

  String get voiceLabel => _l10n.disputeStatusVoiceLabel;

  String chatLabel(int? messageCount) => messageCount == null
      ? _l10n.disputeStatusChatAttached
      : _l10n.disputeStatusChatAttachedCount(messageCount);

  String timelineLabel(int count) => _l10n.disputeStatusTimelineAttached(count);

  // ── Loading copy. Failure copy comes from `failureCopy`, never here. ──────

  /// Headline of the cold-read loading rung.
  String get loadingHeadline => _l10n.disputeStatusLoading;
}

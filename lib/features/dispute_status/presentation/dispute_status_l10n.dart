import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/dispute_status_repository.dart';

/// JM-065 dispute-status localized copy resolver (R-F; the
/// `notifications_l10n.dart` / `wallet_hub_l10n.dart` precedent,
/// 40_GUARDRAILS_ARCH §9 l10n protocol).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned (50_EXECUTION_PLAN §S4). The W4 integrator batched FIVE
/// dispute-status keys (title / open-label / body / support-cta / back-cta).
/// The rest — the canonical lifecycle labels, neutral resolution copy,
/// the evidence-summary heading + its per-item labels (D53),
/// and the load-error/retry copy — is NOT yet present. Per the JM-057/JM-058
/// precedent this resolver reuses the EXISTING getters where one fits and
/// supplies the genuinely-missing strings from a feature-local EN/AR map until
/// the integrator lands the dedicated keys (REQUESTED in `50_ROUTE_REQUESTS.md`,
/// "JM-065").
///
/// Maestro asserts on `Semantics(identifier:)` ONLY (41_GUARDRAILS_TESTING §4),
/// so the visible copy is cosmetic — this swaps to the real getters with no
/// call-site change. Delete this file (fold the `_pick` strings into `dispute*`
/// ARB getters) once the integrator lands the requested keys.
class DisputeStatusL10n {
  DisputeStatusL10n(this._l10n, this._isArabic);

  factory DisputeStatusL10n.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return DisputeStatusL10n(
      AppLocalizations.of(context),
      locale.languageCode == 'ar',
    );
  }

  final AppLocalizations _l10n;
  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  // ── Present keys (integrator-landed). ──────────────────────────────────────
  String get title => _l10n.disputeStatusTitle;
  String get openLabel => _l10n.disputeStatusOpenLabel;
  String get openBody => _l10n.disputeStatusBody;
  String get supportCta => _l10n.disputeStatusSupportCta;
  String get backCta => _l10n.disputeStatusBackCta;

  // ── Genuinely-missing copy (feature-local until the integrator lands keys). ─

  String get pendingLabel => _pick('Pending', 'قيد المراجعة');
  String get fixedLabel => _pick('Fixed', 'تم الإصلاح');
  String get closedLabel => _pick('Closed', 'مغلق');

  /// First node of the lifecycle stepper — always `done` (the dispute exists,
  /// so it was submitted). Short by design: a stepper label is 10.5/w700.
  String get stepSubmittedLabel => _l10n.disputeStatusStepSubmitted;

  /// Legacy label retained for existing generated localization compatibility.
  String get stepUnderReviewLabel => _l10n.disputeStatusStepUnderReview;

  String get resolutionHeading => _pick('Resolution', 'المعالجة');
  String get fixedBody => _pick(
    'Support marked the reported issue as fixed.',
    'حدّد فريق الدعم المشكلة المبلّغ عنها كمشكلة تم إصلاحها.',
  );
  String get closedBody => _pick(
    'An administrator closed this dispute after review.',
    'أغلق أحد المشرفين هذا النزاع بعد المراجعة.',
  );
  String get historyHeading => _pick('Status history', 'سجل الحالة');

  String statusLabel(DisputeState state) => switch (state) {
    DisputeState.pending || DisputeState.open => pendingLabel,
    DisputeState.fixed || DisputeState.resolved => fixedLabel,
    DisputeState.closed => closedLabel,
    DisputeState.unknown => _pick('Status unavailable', 'الحالة غير متاحة'),
  };

  // ── Evidence summary (D53). ────────────────────────────────────────────────
  String get evidenceHeading => _pick('Evidence summary', 'ملخص الأدلة');

  String reasonLabel(String? reason) {
    switch (reason) {
      case 'damaged':
      case 'damaged_item':
        return _pick('Damaged item', 'سلعة تالفة');
      case 'wrong_item':
      case 'wrong-item':
        return _pick('Wrong item delivered', 'تم تسليم سلعة خاطئة');
      case 'no_show':
      case 'no-show':
        return _pick('No-show', 'عدم الحضور');
      case 'fraud':
        return _pick('Fraud', 'احتيال');
      case 'abuse':
        return _pick('Abusive behavior', 'سلوك مسيء');
      case null:
        return _pick('Reason', 'السبب');
      default:
        return _pick('Other', 'أخرى');
    }
  }

  /// MIDNIGHT M3-32: headline of the inline empty evidence block.
  /// TODO(midnight): l10n-queued `disputeStatusEvidenceEmpty` —
  /// docs/redesign-midnight/l10n-queue/M3-32.md.
  String get evidenceEmptyHeadline =>
      _pick('No evidence attached', 'لا توجد أدلة مرفقة');
  String get evidencePartial => _pick(
    'Some evidence could not be attached. Support can still review the available items.',
    'تعذر إرفاق بعض الأدلة. لا يزال بإمكان الدعم مراجعة العناصر المتاحة.',
  );
  String get evidenceUploadFailed =>
      _pick('Attachment unavailable', 'المرفق غير متاح');

  String get evidenceReasonLabel => _pick('Reason', 'السبب');
  String get evidenceCommentLabel => _pick('Your note', 'ملاحظتك');

  String photosLabel(int count) => count == 1
      ? _pick('1 photo attached', 'صورة واحدة مرفقة')
      : _pick('$count photos attached', '$count صور مرفقة');

  String get voiceLabel => _pick('Voice note attached', 'ملاحظة صوتية مرفقة');

  String chatLabel(int? messageCount) => messageCount == null
      ? _pick('Chat thread attached', 'تم إرفاق المحادثة')
      : _pick(
          'Chat thread attached ($messageCount messages)',
          'تم إرفاق المحادثة ($messageCount رسالة)',
        );

  String timelineLabel(int count) => _pick(
    'Delivery timeline attached ($count steps)',
    'تم إرفاق مسار التوصيل ($count خطوات)',
  );

  // ── D30 error / loading copy. ──────────────────────────────────────────────

  /// MIDNIGHT M3-32: headline of the cold-read `JeebEmptyState`.
  /// TODO(midnight): l10n-queued `disputeStatusLoading` —
  /// docs/redesign-midnight/l10n-queue/M3-32.md.
  String get loadingHeadline =>
      _pick('Checking this dispute', 'جارٍ التحقق من هذا النزاع');

  String get loadError =>
      _pick('Could not load this dispute.', 'تعذّر تحميل هذا النزاع.');
  String get notFoundError =>
      _pick('This dispute could not be found.', 'تعذّر العثور على هذا النزاع.');
  String get networkError => _pick(
    'No connection. Check your network and try again.',
    'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
  );
  String get retry => _pick('Retry', 'إعادة المحاولة');
}

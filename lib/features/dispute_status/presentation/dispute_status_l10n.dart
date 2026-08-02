import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/dispute_status_repository.dart';

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

  String get title => _l10n.disputeStatusTitle;
  String get openLabel => _l10n.disputeStatusOpenLabel;
  String get openBody => _l10n.disputeStatusBody;
  String get supportCta => _l10n.disputeStatusSupportCta;
  String get backCta => _l10n.disputeStatusBackCta;

  String get resolvedLabel => _pick('Resolved', 'تم الحل');

  String get outcomeHeading => _pick('Outcome', 'النتيجة');

  String outcomeLine(DisputeOutcome outcome, {String? amount}) {
    switch (outcome) {
      case DisputeOutcome.refund:
        return amount == null
            ? _pick('A refund was issued to you.', 'تمت إعادة المبلغ إليك.')
            : _pick(
                'A refund of $amount was issued to you.',
                'تمت إعادة مبلغ $amount إليك.',
              );
      case DisputeOutcome.penalty:
        return amount == null
            ? _pick(
                'A penalty was applied to the other party.',
                'تم تطبيق غرامة على الطرف الآخر.',
              )
            : _pick(
                'A penalty of $amount was applied.',
                'تم تطبيق غرامة قدرها $amount.',
              );
      case DisputeOutcome.dismissed:
        return _pick(
          'This dispute was reviewed and dismissed.',
          'تمت مراجعة هذا النزاع ورفضه.',
        );
      case DisputeOutcome.other:
      case DisputeOutcome.none:
        return _pick(
          'This dispute has been resolved.',
          'تم حل هذا النزاع.',
        );
    }
  }

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

  String get loadError =>
      _pick('Could not load this dispute.', 'تعذّر تحميل هذا النزاع.');
  String get notFoundError => _pick(
        'This dispute could not be found.',
        'تعذّر العثور على هذا النزاع.',
      );
  String get networkError => _pick(
        'No connection. Check your network and try again.',
        'لا يوجد اتصال. تحقّق من الشبكة وحاول مجددًا.',
      );
  String get retry => _pick('Retry', 'إعادة المحاولة');
}

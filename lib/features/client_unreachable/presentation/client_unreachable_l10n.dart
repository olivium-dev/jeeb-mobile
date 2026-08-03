import 'package:flutter/widgets.dart';

/// Localized copy resolver for `client_unreachable` (the
/// `live_tracking_l10n.dart` / `dispute_status_l10n.dart` precedent).
///
/// The shared ARB files + the hand-authored `AppLocalizations` getter layer are
/// integrator-owned, and this screen has **no** keys there today — every string
/// it renders was inlined in English at the call site, so an Arabic user read
/// English. This resolver keeps the EN wording byte-identical (no copy meaning
/// changes in the redesign-2026-08 re-skin) and supplies the AR side from a
/// feature-local map until the integrator lands the dedicated keys (REQUESTED
/// in `docs/redesign-2026-08/wiring/w4-client-unreachable.md`).
///
/// Maestro/widget tests assert on `Semantics(identifier:)` only, so swapping
/// these getters to the real ARB keys later needs no call-site change.
///
/// Delete this file once the integrator adds:
///   clientUnreachableTitle · clientUnreachableNoticeTitle
///   · clientUnreachableNoticeBody · clientUnreachableCallAgainCta
///   · clientUnreachableChatCta · clientUnreachableFlagCta
class ClientUnreachableL10n {
  ClientUnreachableL10n(this._isArabic);

  factory ClientUnreachableL10n.of(BuildContext context) =>
      ClientUnreachableL10n(
        Localizations.localeOf(context).languageCode == 'ar',
      );

  final bool _isArabic;

  /// Top-bar title.
  String get title =>
      _pick('Client Unreachable', 'تعذّر الوصول إلى العميل');

  /// Notice headline — the state the jeeber is in.
  String get noticeTitle =>
      _pick('Cannot reach the Client', 'لا يمكن الوصول إلى العميل');

  /// Notice body — what flagging does and the 15-minute grace window.
  String get noticeBody => _pick(
        'If the Client is not responding, you can flag them as unreachable. '
            'They will have 15 minutes to respond before the delivery is '
            'escalated.',
        'إذا لم يستجب العميل، يمكنك الإبلاغ عن تعذّر الوصول إليه. سيكون أمامه '
            '15 دقيقة للرد قبل تصعيد التوصيل.',
      );

  /// Retry-the-call affordance.
  String get callAgainCta => _pick('Try Calling Again', 'حاول الاتصال مجددًا');

  /// Reach-out-in-chat affordance.
  String get chatCta => _pick('Send Chat Message', 'إرسال رسالة في المحادثة');

  /// The escalating edge — docked, and the only primary action here.
  String get flagCta =>
      _pick('Flag as Unreachable', 'الإبلاغ عن تعذّر الوصول');

  String _pick(String en, String ar) => _isArabic ? ar : en;
}

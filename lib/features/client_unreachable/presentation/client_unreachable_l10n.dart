import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// Screen 33 copy accessors. Every key exists in both ARBs, so this is a thin
/// accessor layer rather than a feature-local EN/AR map.
class ClientUnreachableL10n {
  ClientUnreachableL10n(this._l10n);

  factory ClientUnreachableL10n.of(BuildContext context) =>
      ClientUnreachableL10n(AppLocalizations.of(context));

  final AppLocalizations _l10n;

  /// Top-bar title.
  String get title => _l10n.clientUnreachableTitle;

  /// Notice headline — the state the jeeber is in.
  String get noticeTitle => _l10n.clientUnreachableNoticeTitle;

  /// Notice body — what flagging does and the 15-minute grace window.
  String get noticeBody => _l10n.clientUnreachableNoticeBody;

  /// Retry-the-call affordance.
  String get callAgainCta => _l10n.clientUnreachableCallAgainCta;

  /// Reach-out-in-chat affordance.
  String get chatCta => _l10n.clientUnreachableChatCta;

  /// The escalating edge — docked, and the only primary action here.
  String get flagCta => _l10n.clientUnreachableFlagCta;
}

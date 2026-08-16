enum AccountStatusValue {
  suspended,

  locked;

  static AccountStatusValue fromWire(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'locked':
        return AccountStatusValue.locked;
      case 'suspended':
        return AccountStatusValue.suspended;
      default:
        return AccountStatusValue.suspended;
    }
  }
}

class AccountStatusInfo {
  const AccountStatusInfo({required this.value, this.reason, this.reasonCode});

  final AccountStatusValue value;

  /// Human-safe text ONLY. Never an unresolved i18n template — see
  /// [ModerationReasonWire.humanReason].
  final String? reason;

  /// Ban-policy i18n key (e.g. `Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS`) when the
  /// server had one. The screen looks this up in the viewer's language.
  final String? reasonCode;
}

/// Phase V D16. ban-service is generic and stores i18n TEMPLATES as its
/// message, so `Label{{Ban.Label.YOU_ARE_BANNED_FOR_3_DAYS}}` can arrive where
/// prose is expected. The account-status screen renders the server reason
/// VERBATIM, so the app must refuse a template itself rather than trust that
/// every deployed gateway already strips one.
class ModerationReasonWire {
  const ModerationReasonWire._();

  static const String _templateOpen = 'Label{{';
  static const String _templateClose = '}}';
  static const String _anyPlaceholder = '{{';

  /// The key inside a whole-string `Label{{...}}`, else null.
  static String? codeOf(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith(_templateOpen)) return null;
    if (!value.endsWith(_templateClose)) return null;
    final code = value
        .substring(_templateOpen.length, value.length - _templateClose.length)
        .trim();
    return code.isEmpty ? null : code;
  }

  /// Prose passes through; anything still carrying `{{` is withheld so the
  /// caller falls back to its own localized copy.
  static String? humanReason(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value.contains(_anyPlaceholder) ? null : value;
  }
}

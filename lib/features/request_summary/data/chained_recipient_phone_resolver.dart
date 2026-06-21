import '../domain/recipient_phone_resolver.dart';

/// Tries each delegate [RecipientPhoneResolver] in order and returns the FIRST
/// non-null/non-empty E.164 phone.
///
/// WHY (iter6 OTP-phone v2): the default recipient phone may live in several
/// places depending on how the client authenticated. The reliable order is:
///   1. the locally-persisted registration profile phone
///      ([SharedPrefsRecipientPhoneResolver]) — present for phone-OTP users and
///      NOT surfaced by the live `GET /v1/users/me`;
///   2. the gateway `GET /v1/users/me` `phone` ([DioRecipientPhoneResolver]) —
///      a best-effort fallback that works only if a future gateway adds `phone`.
///
/// Each delegate is best-effort (never throws); a delegate that returns null is
/// simply skipped. The whole chain returns null only when EVERY source misses,
/// in which case the create omits the optional `recipientPhone` (today's
/// behaviour). The explicit compose-form phone still wins over this default in
/// the submission service (the draft phone is checked before any resolver).
class ChainedRecipientPhoneResolver implements RecipientPhoneResolver {
  const ChainedRecipientPhoneResolver(this._delegates);

  final List<RecipientPhoneResolver> _delegates;

  @override
  Future<String?> resolve() async {
    for (final delegate in _delegates) {
      try {
        final phone = (await delegate.resolve())?.trim();
        if (phone != null && phone.isNotEmpty) return phone;
      } catch (_) {
        // Best-effort: a faulty delegate must not break the chain.
      }
    }
    return null;
  }
}

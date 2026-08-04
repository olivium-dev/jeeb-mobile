import '../domain/recipient_phone_resolver.dart';

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
      }
    }
    return null;
  }
}

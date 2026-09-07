import '../../../core/diagnostics/diag.dart';
import '../domain/recipient_phone_resolver.dart';

class ChainedRecipientPhoneResolver implements RecipientPhoneResolver {
  ChainedRecipientPhoneResolver(this._delegates);

  final List<RecipientPhoneResolver> _delegates;

  bool _failed = false;

  /// A delegate threw on the last [resolve]: a null result is "we could not
  /// read a phone", not "the user has none".
  bool get lastResolveErrored => _failed;

  @override
  Future<String?> resolve() async {
    _failed = false;
    for (final delegate in _delegates) {
      try {
        final phone = (await delegate.resolve())?.trim();
        if (phone != null && phone.isNotEmpty) return phone;
      } catch (_) {
        _failed = true;
        Diag.event('recipient_phone_resolver_failed', <String, Object?>{
          'delegate': delegate.runtimeType.toString(),
        });
      }
    }
    return null;
  }
}

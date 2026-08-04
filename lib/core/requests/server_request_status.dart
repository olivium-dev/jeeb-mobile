/// Shared interpretation of the gateway-owned request lifecycle.
/// A request is actionable only while the server reports one of the live
abstract final class ServerRequestStatus {
  static const Set<String> live = {
    'pending',
    'open',
    'broadcasting',
    'offers-received',
  };

  static String normalize(Object? value) {
    if (value is! String) return '';
    return value.trim().toLowerCase().replaceAll('_', '-');
  }

  static bool isOpen(Object? value) => live.contains(normalize(value));

  static bool isExpired(Object? value) => normalize(value) == 'expired';
}

/// Shared interpretation of the gateway-owned request lifecycle.
///
/// A request is actionable only while the server reports one of the live
/// statuses below. Consumers must not infer lifecycle from a local clock or
/// from the mere presence of a row in a response.
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

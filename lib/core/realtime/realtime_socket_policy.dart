import '../config/app_config.dart';

/// Validates the one compile-time Phoenix socket authority used by mobile.
class RealtimeSocketPolicy {
  const RealtimeSocketPolicy({
    this.configuredUrl = AppConfig.realtimeSocketUrl,
    this.isDevelopment = AppConfig.appFlavor == 'dev',
  });

  final String configuredUrl;
  final bool isDevelopment;

  /// Resolves the configured socket without trusting a gateway-supplied host.
  Uri? configuredUri({Uri? developmentOverride}) {
    if (isDevelopment && developmentOverride != null) {
      return _validUri(developmentOverride, allowCleartext: true);
    }
    return _configuredUri();
  }

  /// Requires a descriptor URL to normalize exactly to the configured URL.
  Uri? descriptorUri(String? descriptorUrl) {
    final configured = _configuredUri();
    if (configured == null || descriptorUrl == null || descriptorUrl.isEmpty) {
      return null;
    }
    final descriptor = Uri.tryParse(descriptorUrl);
    final validDescriptor = descriptor == null
        ? null
        : _validUri(descriptor, allowCleartext: isDevelopment);
    if (validDescriptor == null ||
        !_sameAuthority(configured, validDescriptor)) {
      return null;
    }
    return configured;
  }

  Uri? _configuredUri() {
    if (configuredUrl.isEmpty) return null;
    final parsed = Uri.tryParse(configuredUrl);
    if (parsed == null) return null;
    return _validUri(parsed, allowCleartext: isDevelopment);
  }

  Uri? _validUri(Uri uri, {required bool allowCleartext}) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'wss' && !(allowCleartext && scheme == 'ws')) return null;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    if (uri.path != '/socket/websocket') return null;
    if (uri.hasQuery || uri.hasFragment) return null;
    return uri;
  }

  bool _sameAuthority(Uri configured, Uri descriptor) =>
      configured.scheme.toLowerCase() == descriptor.scheme.toLowerCase() &&
      configured.host.toLowerCase() == descriptor.host.toLowerCase() &&
      configured.port == descriptor.port &&
      configured.path == descriptor.path;
}

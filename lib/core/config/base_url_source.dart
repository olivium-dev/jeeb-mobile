import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'dev_base_url.dart';

/// Where the REST base URL in force actually came from.
enum BaseUrlSource {
  /// Persisted `dev.base_url_override` — outranks every dart-define and
  /// survives a reinstall.
  devToolOverride('override', DevBaseUrl.prefsKey),
  mockBaseUrlDefine('JEEB_MOCK_BASE_URL', 'JEEB_MOCK_BASE_URL'),
  devGatewayBaseUrlDefine(
    'JEEB_DEV_GATEWAY_BASE_URL',
    'JEEB_DEV_GATEWAY_BASE_URL',
  ),
  gatewayBaseUrlDefine('GATEWAY_BASE_URL', 'GATEWAY_BASE_URL'),

  /// Nothing supplied one; the client fails closed.
  unset('unset', '');

  const BaseUrlSource(this.label, this.key);
  final String label;
  final String key;
}

@immutable
class ResolvedBaseUrl {
  const ResolvedBaseUrl({
    required this.value,
    required this.source,
    required this.buildValue,
  });

  final String value;
  final BaseUrlSource source;

  /// What the build would have used with no override — the value the app
  /// reverts to when the override is cleared.
  final String buildValue;

  bool get isOverridden => source == BaseUrlSource.devToolOverride;

  bool get overrideDivergesFromBuild => isOverridden && value != buildValue;
}

/// Pure mirror of `MockGatewayClient.mockBaseUrl` + [DevBaseUrl], so the Dev
/// Tool can name the winning layer instead of only showing its value.
ResolvedBaseUrl resolveBaseUrl({
  required String? override,
  required String mockDefine,
  required String devGatewayDefine,
  required String gatewayDefine,
  required bool developmentBuild,
}) {
  final fallback = developmentBuild ? devGatewayDefine : gatewayDefine;
  final fallbackSource = developmentBuild
      ? BaseUrlSource.devGatewayBaseUrlDefine
      : BaseUrlSource.gatewayBaseUrlDefine;
  final buildValue = mockDefine.isNotEmpty ? mockDefine : fallback;
  final buildSource = mockDefine.isNotEmpty
      ? BaseUrlSource.mockBaseUrlDefine
      : (fallback.isEmpty ? BaseUrlSource.unset : fallbackSource);

  final trimmed = override?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return ResolvedBaseUrl(
      value: trimmed,
      source: BaseUrlSource.devToolOverride,
      buildValue: buildValue,
    );
  }
  return ResolvedBaseUrl(
    value: buildValue,
    source: buildSource,
    buildValue: buildValue,
  );
}

/// [resolveBaseUrl] bound to this build's compile-time constants.
ResolvedBaseUrl resolveBaseUrlForBuild({required String? override}) =>
    resolveBaseUrl(
      override: override,
      mockDefine: kMockBaseUrlDefine,
      devGatewayDefine: kDevGatewayBaseUrlDefine,
      gatewayDefine: AppConfig.gatewayBaseUrl,
      developmentBuild: kDebugMode || AppConfig.isDevelopmentFlavor,
    );

/// Boot tripwire: one greppable line naming the layer that actually won.
void logEffectiveBaseUrl(String? override) {
  if (!kDebugMode) return;
  final resolved = resolveBaseUrlForBuild(override: override);
  debugPrint(
    'JEEB-BASEURL source=${resolved.source.label} value=${resolved.value}'
    '${resolved.overrideDivergesFromBuild ? ' build=${resolved.buildValue}' : ''}',
  );
}

const String kMockBaseUrlDefine = String.fromEnvironment('JEEB_MOCK_BASE_URL');

const String kDevGatewayBaseUrlDefine = String.fromEnvironment(
  'JEEB_DEV_GATEWAY_BASE_URL',
  defaultValue: 'https://gateway.dev.invalid',
);

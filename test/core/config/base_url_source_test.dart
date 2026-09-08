import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/base_url_source.dart';

ResolvedBaseUrl _resolve({
  String? override,
  String mock = '',
  String devGateway = 'https://gateway.dev.invalid',
  String gateway = '',
  bool development = true,
}) => resolveBaseUrl(
  override: override,
  mockDefine: mock,
  devGatewayDefine: devGateway,
  gatewayDefine: gateway,
  developmentBuild: development,
);

void main() {
  test('a persisted override outranks every dart-define', () {
    final resolved = _resolve(
      override: 'https://msi.olivium.space/gateway',
      mock: 'https://app.jeeb.fds-1.com',
    );
    expect(resolved.value, 'https://msi.olivium.space/gateway');
    expect(resolved.source, BaseUrlSource.devToolOverride);
    expect(resolved.buildValue, 'https://app.jeeb.fds-1.com');
    expect(resolved.overrideDivergesFromBuild, isTrue);
  });

  test('an override equal to the build value is not a divergence', () {
    final resolved = _resolve(
      override: 'https://app.jeeb.fds-1.com',
      mock: 'https://app.jeeb.fds-1.com',
    );
    expect(resolved.isOverridden, isTrue);
    expect(resolved.overrideDivergesFromBuild, isFalse);
  });

  test('a blank or whitespace override falls through to the defines', () {
    for (final blank in <String?>[null, '', '   ']) {
      final resolved = _resolve(override: blank, mock: 'https://mock.example');
      expect(resolved.source, BaseUrlSource.mockBaseUrlDefine);
      expect(resolved.value, 'https://mock.example');
    }
  });

  test('a development build without JEEB_MOCK_BASE_URL uses the dev define', () {
    final resolved = _resolve(devGateway: 'https://dev.example');
    expect(resolved.source, BaseUrlSource.devGatewayBaseUrlDefine);
    expect(resolved.value, 'https://dev.example');
  });

  test('a non-development build reads GATEWAY_BASE_URL, never the dev one', () {
    final resolved = _resolve(
      development: false,
      devGateway: 'https://dev.example',
      gateway: 'https://app.jeeb.fds-1.com',
    );
    expect(resolved.source, BaseUrlSource.gatewayBaseUrlDefine);
    expect(resolved.value, 'https://app.jeeb.fds-1.com');
  });

  test('nothing configured resolves to unset, not to a guessed host', () {
    final resolved = _resolve(development: false, devGateway: '', gateway: '');
    expect(resolved.source, BaseUrlSource.unset);
    expect(resolved.value, isEmpty);
  });

  test('the override source names the SharedPreferences key it lives in', () {
    expect(BaseUrlSource.devToolOverride.key, 'dev.base_url_override');
  });
}

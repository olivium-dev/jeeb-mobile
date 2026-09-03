import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

/// One environment from the published index (olivium-dev/jeeb-static-apis).
class EnvIndexEntry {
  const EnvIndexEntry({
    required this.id,
    required this.label,
    required this.gatewayBaseUrl,
    required this.reachability,
    required this.cleartext,
    this.realtimeSocketUrl,
    this.cmsUrl,
    this.notes,
  });

  factory EnvIndexEntry.fromJson(Map<String, dynamic> json) => EnvIndexEntry(
    id: json['id'] as String,
    label: json['label'] as String,
    gatewayBaseUrl: json['gatewayBaseUrl'] as String,
    reachability: json['reachability'] as String? ?? 'public',
    cleartext: json['cleartext'] as bool? ?? false,
    realtimeSocketUrl: json['realtimeSocketUrl'] as String?,
    cmsUrl: json['cmsUrl'] as String?,
    notes: json['notes'] as String?,
  );

  final String id;
  final String label;
  final String gatewayBaseUrl;
  final String reachability;
  final bool cleartext;
  final String? realtimeSocketUrl;
  final String? cmsUrl;
  final String? notes;
}

/// Fetches and decrypts the AES-256-GCM environment-index envelope so the
/// Server URL page can offer real presets instead of hand-typed URLs.
class EnvIndexClient {
  EnvIndexClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  static const String indexUrl = String.fromEnvironment(
    'JEEB_ENV_INDEX_URL',
    defaultValue:
        'https://olivium-dev.github.io/jeeb-static-apis/v1/environments.json',
  );

  static const String _keyHexDefine = String.fromEnvironment(
    'JEEB_ENV_INDEX_KEY',
  );

  /// The index is unreadable without the out-of-band 64-hex key define.
  static bool get isConfigured => _keyHexDefine.length == 64;

  final Dio _dio;

  Future<List<EnvIndexEntry>> fetch({String? keyHex}) async {
    final response = await _dio.get<dynamic>(indexUrl);
    final data = response.data;
    final envelope = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : (data as Map).cast<String, dynamic>();
    return decryptEnvelope(envelope, keyHex: keyHex ?? _keyHexDefine);
  }

  /// Throws [SecretBoxAuthenticationError] on a wrong key and
  /// [FormatException] on a malformed envelope.
  static Future<List<EnvIndexEntry>> decryptEnvelope(
    Map<String, dynamic> envelope,
    {required String keyHex}
  ) async {
    final raw = base64Decode(envelope['ciphertext'] as String);
    if (raw.length <= 16) {
      throw const FormatException('ciphertext shorter than the GCM tag');
    }
    final box = SecretBox(
      raw.sublist(0, raw.length - 16),
      nonce: base64Decode(envelope['nonce'] as String),
      mac: Mac(raw.sublist(raw.length - 16)),
    );
    final clear = await AesGcm.with256bits().decrypt(
      box,
      secretKey: SecretKey(hexToBytes(keyHex)),
    );
    final doc = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final environments = doc['environments'] as List<dynamic>? ?? const [];
    return [
      for (final entry in environments)
        EnvIndexEntry.fromJson((entry as Map).cast<String, dynamic>()),
    ];
  }

  static List<int> hexToBytes(String hex) {
    if (hex.length.isOdd) {
      throw const FormatException('hex key has odd length');
    }
    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }
}

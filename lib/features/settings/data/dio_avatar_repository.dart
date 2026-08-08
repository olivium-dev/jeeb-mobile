import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../kyc/domain/cdn_asset_gateway.dart';
import '../domain/avatar_repository.dart';

/// Dio-backed [AvatarRepository]: CDN broker upload then `PUT /api/User/profile`
/// with the gateway public avatar URL (never the raw object_ref). See PR body.
class DioAvatarRepository implements AvatarRepository {
  DioAvatarRepository(this._dio, this._cdn);

  final Dio _dio;
  final CdnAssetGateway _cdn;

  static const String _profilePath = '/api/User/profile';
  static const String _mePath = '/v1/users/me';

  /// Client-side ceiling (UX only); the gateway's 15 MB edge cap is the real gate.
  static const int maxUploadBytes = 10 * 1024 * 1024;

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    if (bytes.length > maxUploadBytes) {
      throw const AvatarRepositoryException(AvatarUploadFailure.tooLarge);
    }
    try {
      await _cdn.uploadAsset(slot: CdnUploadSlot.avatar, bytes: bytes);
    } on CdnUploadException catch (e) {
      throw AvatarRepositoryException(AvatarUploadFailure.network, e.message);
    }
    final me = await _fetchMe();
    final url = _publicAvatarUrl(me.userId);
    await _putProfile(me: me, profilePic: url);
    return url;
  }

  @override
  Future<void> removeAvatar() async {
    final me = await _fetchMe();
    // Deliberate explicit clear (the one write shape capable of it); UM's
    // empty-string semantics are the open owner question, F5 plan §5.
    await _putProfile(me: me, profilePic: '');
  }

  Future<_Me> _fetchMe() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_mePath);
      final json = res.data ?? const <String, dynamic>{};
      return _Me(
        userId: _str(json['userId'] ?? json['user_id'] ?? json['id']) ?? '',
        email: _str(json['email']) ?? '',
        // Preserve the display name so this PUT never blanks `username`.
        username: _str(json['name'] ?? json['username']) ?? '',
      );
    } on DioException catch (e) {
      throw AvatarRepositoryException(_mapDioFailure(e), e.message);
    }
  }

  Future<void> _putProfile({required _Me me, required String profilePic}) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        _profilePath,
        data: <String, dynamic>{
          'userId': me.userId,
          'email': me.email,
          'username': me.username,
          'profilePic': profilePic,
        },
      );
    } on DioException catch (e) {
      throw AvatarRepositoryException(_mapDioFailure(e), e.message);
    }
  }

  String _publicAvatarUrl(String userId) {
    final base = _dio.options.baseUrl;
    final trimmedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final version = DateTime.now().millisecondsSinceEpoch;
    return '$trimmedBase/api/users/$userId/avatar?v=$version';
  }

  String? _str(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  AvatarUploadFailure _mapDioFailure(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) return AvatarUploadFailure.unauthorized;
    if (status != null && status >= 500) return AvatarUploadFailure.serverError;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return AvatarUploadFailure.network;
      default:
        return AvatarUploadFailure.unknown;
    }
  }
}

class _Me {
  const _Me({required this.userId, required this.email, required this.username});

  final String userId;
  final String email;
  final String username;
}

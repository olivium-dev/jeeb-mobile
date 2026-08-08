import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../kyc/domain/cdn_asset_gateway.dart';
import '../domain/avatar_repository.dart';

/// Dio-backed [AvatarRepository]: CDN broker upload (reusing
/// [CdnAssetGateway.uploadAsset] as-is, JEBV4/F5 §3.3.1) then
/// `PUT /api/User/profile` with the gateway's own public avatar URL —
/// never the raw CDN object_ref, which every counterparty avatar render site
/// (a bare `imageUrl` fed to an unauthenticated `OmdsCachedImage`) cannot
/// resolve on its own.
///
/// Gateway contract this expects (paired gateway PR, owner-gated on the
/// public-route security sign-off — see PR body):
///   - `profile_avatar` in `CdnController.AllowedUploadSlots`.
///   - `GET /api/users/{userId}/avatar` — public, server-resolved from the
///     UM profile (never a client-supplied object_ref).
///   - `PUT /api/User/profile` invalidates the 30s `/v1/users/me` cache key
///     so this flow's own read-after-write (`_fetchMe`) isn't racing a
///     stale cache entry.
class DioAvatarRepository implements AvatarRepository {
  DioAvatarRepository(this._dio, this._cdn);

  final Dio _dio;
  final CdnAssetGateway _cdn;

  static const String _profilePath = '/api/User/profile';
  static const String _mePath = '/v1/users/me';

  /// Client-side upload ceiling, mirroring creamati-mobile's explicit guard
  /// (UX only — the gateway's own `CdnUploadProxyController.MaxUploadBytes`
  /// 15 MB edge cap is the real enforcement boundary).
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
    // Deliberate, explicit clear — NOT the accidental blank the old
    // display-name PUT used to send on every unrelated name save. Whether UM
    // treats an empty string as "clear" is the open owner question (F5
    // plan §5); this is the one write shape structurally capable of it.
    await _putProfile(me: me, profilePic: '');
  }

  Future<_Me> _fetchMe() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_mePath);
      final json = res.data ?? const <String, dynamic>{};
      return _Me(
        userId: _str(json['userId'] ?? json['user_id'] ?? json['id']) ?? '',
        email: _str(json['email']) ?? '',
        // Preserve whatever the profile currently carries as the display
        // name — this PUT must never construct a blank `username`, the
        // photo-side twin of the `profilePic: ''` clobber this feature
        // fixes on the name side (dio_display_name_repository.dart).
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

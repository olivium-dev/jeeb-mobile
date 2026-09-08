import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../../kyc/domain/cdn_asset_gateway.dart';
import '../domain/avatar_repository.dart';

/// Dio-backed [AvatarRepository]: CDN broker upload, then `PUT /api/User/profile`
/// with the BARE object_ref; the display URL is returned to the UI, never committed.
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
    final String objectRef;
    try {
      final CdnAssetGateway cdn = _cdn;
      objectRef = cdn is IdempotentCdnAssetGateway
          ? await cdn.uploadAssetIdempotent(
              slot: CdnUploadSlot.avatar,
              bytes: bytes,
              operationId: newOperationId(),
            )
          : await cdn.uploadAsset(slot: CdnUploadSlot.avatar, bytes: bytes);
    } on CdnUploadException catch (e) {
      final AppFailure? failure = e.failure;
      throw AvatarRepositoryException(
        failure == null
            ? AvatarUploadFailure.network
            : _mapFailure(failure, e.status),
        e.message,
      );
    }
    final me = await _fetchMe();
    await _putProfile(me: me, profilePic: objectRef);
    return _publicAvatarUrl(me.userId);
  }

  @override
  Future<void> removeAvatar() async {
    final me = await _fetchMe();
    // Empty string is the canonical clear on the wire; the gateway forwards it
    // verbatim and every reader treats '' and NULL as "no avatar".
    await _putProfile(me: me, profilePic: '');
  }

  Future<_Me> _fetchMe() async {
    final Map<String, dynamic> json;
    try {
      final res = await _dio.get<Map<String, dynamic>>(_mePath);
      json = res.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      throw AvatarRepositoryException(_mapDioFailure(e), 'users_me');
    }
    // A `/v1/users/me` with no id cannot be PUT back without blanking the
    // stored identity (UX-23) — abort rather than write empty strings.
    final String? userId = _str(json['userId'] ?? json['user_id'] ?? json['id']);
    if (userId == null) {
      throw const AvatarRepositoryException(AvatarUploadFailure.unauthorized);
    }
    return _Me(
      userId: userId,
      email: _str(json['email']),
      // Preserve the display name so this PUT never blanks `username`.
      username: _str(json['name'] ?? json['username']),
    );
  }

  Future<void> _putProfile({required _Me me, required String profilePic}) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        _profilePath,
        data: <String, dynamic>{
          'userId': me.userId,
          if (me.email != null) 'email': me.email,
          if (me.username != null) 'username': me.username,
          'profilePic': profilePic,
        },
      );
    } on DioException catch (e) {
      throw AvatarRepositoryException(_mapDioFailure(e), 'users_profile_put');
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

  static AvatarUploadFailure _mapDioFailure(DioException e) =>
      _mapFailure(AppFailure.of(e), e.response?.statusCode);

  static AvatarUploadFailure _mapFailure(AppFailure failure, int? status) {
    if (failure is ValidationFailure) {
      final int? code = status ?? failure.problem?.status;
      return (code == 413 || code == 415)
          ? AvatarUploadFailure.tooLarge
          : AvatarUploadFailure.unknown;
    }
    return switch (failure.kind) {
      AppFailureKind.unauthorized ||
      AppFailureKind.forbidden =>
        AvatarUploadFailure.unauthorized,
      AppFailureKind.server => AvatarUploadFailure.serverError,
      AppFailureKind.network ||
      AppFailureKind.timeout =>
        AvatarUploadFailure.network,
      _ => AvatarUploadFailure.unknown,
    };
  }
}

class _Me {
  const _Me({required this.userId, this.email, this.username});

  final String userId;

  /// Null when `/v1/users/me` did not carry it — the PUT then OMITS the field
  /// rather than sending `''`, which would blank the stored value.
  final String? email;

  final String? username;
}

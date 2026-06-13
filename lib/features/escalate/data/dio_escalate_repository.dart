import 'dart:io';

import 'package:dio/dio.dart';

import '../domain/escalate_repository.dart';

/// Dio-backed [EscalateRepository].
///
/// Endpoint contract verified against Mockoon :3055 (useMockPrefixes=false):
///   POST /v1/deliveries/{deliveryId}/escalate
///     multipart: reason (text), comment? (text), photos (files, up to 5)
///   → 201 { caseId, status, sla }
class DioEscalateRepository implements EscalateRepository {
  const DioEscalateRepository(this._dio);

  final Dio _dio;

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    try {
      final formData = _buildFormData(reason, comment, photoPaths);
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/$deliveryId/escalate',
        data: formData,
      );
      final data = response.data ?? {};
      return EscalateResult.fromJson(data);
    } on DioException catch (e) {
      throw EscalateException(_mapDioError(e), e);
    } on IOException catch (e) {
      throw EscalateException(EscalateErrorKind.network, e);
    }
  }

  FormData _buildFormData(
    EscalateReason reason,
    String? comment,
    List<String> photoPaths,
  ) {
    final fields = <MapEntry<String, dynamic>>[
      MapEntry('reason', _reasonParam(reason)),
      if (comment != null && comment.isNotEmpty)
        MapEntry('comment', comment),
    ];
    final files = photoPaths
        .take(5)
        .map(
          (p) => MapEntry(
            'photos',
            MultipartFile.fromFileSync(p, filename: File(p).uri.pathSegments.last),
          ),
        )
        .toList();
    return FormData.fromMap({
      for (final e in fields) e.key: e.value,
      if (files.isNotEmpty) 'photos': files.map((f) => f.value).toList(),
    });
  }

  EscalateErrorKind _mapDioError(DioException e) {
    if (e.response == null) return EscalateErrorKind.network;
    switch (e.response!.statusCode) {
      case 404:
        return EscalateErrorKind.notFound;
      case 409:
        return EscalateErrorKind.alreadyOpen;
      default:
        return EscalateErrorKind.server;
    }
  }

  static String _reasonParam(EscalateReason reason) {
    switch (reason) {
      case EscalateReason.damaged:
        return 'damaged';
      case EscalateReason.wrongItem:
        return 'wrong_item';
      case EscalateReason.noShow:
        return 'no_show';
      case EscalateReason.fraud:
        return 'fraud';
      case EscalateReason.abuse:
        return 'abuse';
      case EscalateReason.other:
        return 'other';
    }
  }
}

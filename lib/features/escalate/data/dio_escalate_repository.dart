import 'dart:io';

import 'package:dio/dio.dart';

import '../domain/escalate_repository.dart';

/// Dio-backed [EscalateRepository] for `dispute-open-evidence` (JM-060).
///
/// Speaks the gateway contract (`/v1/...`); `MockGatewayClient` rewrites the
/// prefix to the `:4010` service (DO-NOT hardcode a prefix — 40_GUARDRAILS_ARCH
/// §4). Endpoints (42_GUARDRAILS_MOCK §4, all LIVE on :4010):
///   POST /v1/disputes                                       → open dispute
///   GET  /v1/chat/jeeb/conversations/by-request/:id         → resolve conv
///   GET  /v1/chat/jeeb/conversations/:convId/snapshot       → chat snapshot (D53)
///   GET  /v1/delivery/:id                                   → status (timeline, D53)
///
/// Mock convention: the customer's deliveryId == the originating requestId, so
/// the conversation resolves via `by-request/:deliveryId`.
class DioEscalateRepository implements EscalateRepository {
  const DioEscalateRepository(this._dio);

  final Dio _dio;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async {
    // Evidence auto-attach is best-effort (D53): a missing snapshot/timeline
    // must never block opening a dispute, so every failure degrades to empty.
    final snapshot = await _fetchChatSnapshot(deliveryId);
    final timeline = await _fetchTimeline(deliveryId);
    return EscalateEvidence(
      chatSnapshotUrl: snapshot?.url,
      chatMessageCount: snapshot?.messageCount,
      timeline: timeline,
    );
  }

  Future<_ChatSnapshot?> _fetchChatSnapshot(String deliveryId) async {
    try {
      final conv = await _dio.get<Map<String, dynamic>>(
        '/v1/chat/jeeb/conversations/by-request/$deliveryId',
      );
      final conversationId = conv.data?['id'] as String? ??
          conv.data?['conversationId'] as String?;
      if (conversationId == null || conversationId.isEmpty) return null;
      final snap = await _dio.get<Map<String, dynamic>>(
        '/v1/chat/jeeb/conversations/$conversationId/snapshot',
      );
      final url = snap.data?['snapshotUrl'] as String? ??
          snap.data?['url'] as String?;
      final count = snap.data?['messageCount'];
      return _ChatSnapshot(
        url: (url ?? '').isEmpty ? null : url,
        messageCount: count is num ? count.toInt() : null,
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<EscalateTimelineEntry>> _fetchTimeline(String deliveryId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/delivery/$deliveryId',
      );
      final data = res.data ?? const <String, dynamic>{};
      // Prefer an explicit status-history array if the row carries one;
      // otherwise synthesize a single current-status entry from `status`.
      final history = data['statusHistory'] ?? data['timeline'];
      if (history is List) {
        return history
            .whereType<Map>()
            .map(
              (e) => EscalateTimelineEntry(
                status: e['status'] as String? ?? e['to'] as String? ?? '',
                at: e['at'] as String? ??
                    e['ts'] as String? ??
                    e['updatedAt'] as String?,
              ),
            )
            .where((e) => e.status.isNotEmpty)
            .toList(growable: false);
      }
      final status = data['status'] as String?;
      if (status == null || status.isEmpty) {
        return const <EscalateTimelineEntry>[];
      }
      return <EscalateTimelineEntry>[
        EscalateTimelineEntry(
          status: status,
          at: data['updatedAt'] as String? ?? data['updated_at'] as String?,
        ),
      ];
    } on DioException {
      return const <EscalateTimelineEntry>[];
    } catch (_) {
      return const <EscalateTimelineEntry>[];
    }
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/disputes',
        data: _disputeBody(
          deliveryId: deliveryId,
          reason: reason,
          comment: comment,
          photoPaths: photoPaths,
          voicePath: voicePath,
          evidence: evidence,
        ),
        options: Options(
          // Idempotency keyed by the originating order so a double-tap on
          // submit cannot open two disputes for the same delivery.
          headers: <String, Object?>{'Idempotency-Key': 'dispute-$deliveryId'},
        ),
      );
      return EscalateResult.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw EscalateException(_mapDioError(e), e);
    } on IOException catch (e) {
      throw EscalateException(EscalateErrorKind.network, e);
    }
  }

  Map<String, Object?> _disputeBody({
    required String deliveryId,
    required EscalateReason reason,
    required String? comment,
    required List<String> photoPaths,
    required String? voicePath,
    required EscalateEvidence evidence,
  }) {
    final photos = photoPaths
        .take(5)
        .map((p) => File(p).uri.pathSegments.isEmpty
            ? p
            : File(p).uri.pathSegments.last)
        .toList(growable: false);
    return <String, Object?>{
      'deliveryId': deliveryId,
      // Mock convention: the customer's deliveryId is the originating request.
      'requestId': deliveryId,
      'reason': _reasonParam(reason),
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'photos': photos,
      if (voicePath != null && voicePath.isNotEmpty)
        'voiceUrl': File(voicePath).uri.pathSegments.isEmpty
            ? voicePath
            : File(voicePath).uri.pathSegments.last,
      // Auto-attached evidence (D53).
      'evidence': <String, Object?>{
        if (evidence.hasChatSnapshot) 'chatSnapshotUrl': evidence.chatSnapshotUrl,
        if (evidence.chatMessageCount != null)
          'chatMessageCount': evidence.chatMessageCount,
        if (evidence.hasTimeline)
          'timeline': evidence.timeline
              .map((e) => <String, Object?>{
                    'status': e.status,
                    if (e.at != null) 'at': e.at,
                  })
              .toList(growable: false),
      },
    };
  }

  EscalateErrorKind _mapDioError(DioException e) {
    if (e.response == null) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return EscalateErrorKind.network;
        default:
          return EscalateErrorKind.server;
      }
    }
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

/// Internal value object for the resolved chat snapshot.
class _ChatSnapshot {
  const _ChatSnapshot({this.url, this.messageCount});
  final String? url;
  final int? messageCount;
}

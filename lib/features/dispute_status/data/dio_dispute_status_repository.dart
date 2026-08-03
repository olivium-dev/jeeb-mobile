import 'package:dio/dio.dart';

import '../domain/dispute_status_repository.dart';

class DioDisputeStatusRepository implements DisputeStatusRepository {
  const DioDisputeStatusRepository(this._dio);

  final Dio _dio;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/disputes/$disputeId',
      );
      return _parse(res.data ?? const <String, dynamic>{}, disputeId);
    } on DioException catch (e) {
      throw DisputeStatusRepositoryException(_map(e), e.message);
    } catch (e) {
      throw DisputeStatusRepositoryException(
        DisputeStatusFailure.unknown,
        e.toString(),
      );
    }
  }

  DisputeStatus _parse(Map<String, dynamic> json, String fallbackId) {
    final state = _state(json['status'] ?? json['state']);
    final resolution = _str(json['resolution']);
    return DisputeStatus(
      id: _str(json['id'] ?? json['disputeId']) ?? fallbackId,
      state: state,
      outcome: _outcome(state, resolution),
      resolution: resolution,
      note: _str(json['note']),
      refundAmount: _numOrNull(json['refundAmount'] ?? json['refund_amount']),
      currency: _str(json['currency']),
      orderRef: _str(
        json['orderRef'] ?? json['deliveryId'] ?? json['requestId'] ?? json['ref'],
      ),
      conversationRef: _str(
        json['conversationId'] ?? json['conversation_id'] ?? json['conversationRef'],
      ),
      createdAt: _str(json['createdAt'] ?? json['created_at']),
      resolvedAt: _str(
        json['resolvedAt'] ?? json['resolved_at'] ?? json['updatedAt'] ?? json['updated_at'],
      ),
      evidence: _evidence(json),
    );
  }

  DisputeState _state(Object? v) {
    switch (v) {
      case 'open':
      case 'pending':
      case 'in_review':
        return DisputeState.open;
      case 'resolved':
      case 'closed':
        return DisputeState.resolved;
      default:
        return DisputeState.unknown;
    }
  }

  DisputeOutcome _outcome(DisputeState state, String? resolution) {
    if (state != DisputeState.resolved) return DisputeOutcome.none;
    final r = resolution?.toLowerCase().trim();
    if (r == null || r.isEmpty) return DisputeOutcome.other;
    if (r.contains('refund')) return DisputeOutcome.refund;
    if (r.contains('penalty') || r.contains('penalis') || r.contains('penaliz')) {
      return DisputeOutcome.penalty;
    }
    if (r.contains('dismiss') || r.contains('rejected') || r.contains('no_action')) {
      return DisputeOutcome.dismissed;
    }
    return DisputeOutcome.other;
  }

  DisputeEvidenceSummary _evidence(Map<String, dynamic> json) {
    final ev = json['evidence'];
    final evMap = ev is Map<String, dynamic> ? ev : const <String, dynamic>{};
    final timeline = evMap['timeline'];
    return DisputeEvidenceSummary(
      reason: _str(json['reason']),
      comment: _str(json['comment'] ?? json['note']),
      photoCount: _countOf(json['photos'] ?? json['photoUrls']),
      hasVoice: _str(json['voiceUrl'] ?? json['voice_url']) != null,
      hasChatSnapshot:
          _str(evMap['chatSnapshotUrl'] ?? evMap['chat_snapshot_url']) != null,
      chatMessageCount: _intOrNull(
        evMap['chatMessageCount'] ?? evMap['chat_message_count'],
      ),
      timelineCount: timeline is List ? timeline.length : 0,
    );
  }

  int _countOf(Object? v) => v is List ? v.length : 0;

  double? _numOrNull(Object? v) => (v is num) ? v.toDouble() : null;

  int? _intOrNull(Object? v) => (v is num) ? v.toInt() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  DisputeStatusFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 404) return DisputeStatusFailure.notFound;
    if (code == 401 || code == 403) {
      return DisputeStatusFailure.unauthorized;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return DisputeStatusFailure.network;
      default:
        return DisputeStatusFailure.unknown;
    }
  }
}

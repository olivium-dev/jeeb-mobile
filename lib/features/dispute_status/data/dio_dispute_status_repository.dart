import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/diagnostics/diag.dart';
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
      throw DisputeStatusRepositoryException.classified(
        _map(e),
        message: e.message,
        appFailure: AppFailure.of(e),
      );
    } catch (e) {
      Diag.event('dispute_status.parse_failed', <String, Object?>{
        'type': e.runtimeType.toString(),
      });
      throw DisputeStatusRepositoryException.classified(
        DisputeStatusFailure.unknown,
        appFailure: UnknownFailure(
          cause: e,
          parse: e is TypeError || e is FormatException,
        ),
      );
    }
  }

  DisputeStatus _parse(Map<String, dynamic> json, String fallbackId) {
    final state = _state(json['status'] ?? json['state']);
    return DisputeStatus(
      id: _str(json['id'] ?? json['disputeId']) ?? fallbackId,
      state: state,
      note: _str(
        json['resolutionNote'] ?? json['resolution_note'] ?? json['note'],
      ),
      orderRef: _str(
        json['orderRef'] ??
            json['deliveryId'] ??
            json['requestId'] ??
            json['ref'],
      ),
      conversationRef: _str(
        json['conversationId'] ??
            json['conversation_id'] ??
            json['conversationRef'] ??
            _chatPayload(json)['conversationId'],
      ),
      createdAt: _str(json['createdAt'] ?? json['created_at']),
      resolvedAt: _str(
        json['resolvedAt'] ??
            json['resolved_at'] ??
            json['updatedAt'] ??
            json['updated_at'],
      ),
      evidence: _evidence(json),
      statusHistory: _history(json),
      version: _intOrNull(json['version']),
    );
  }

  DisputeState _state(Object? v) {
    switch (v) {
      case 'Pending':
      case 'open':
      case 'pending':
      case 'in_review':
      case 'under_review':
      case 'filed':
        return DisputeState.pending;
      case 'Fixed':
      case 'fixed':
      case 'resolved':
      case 'resolved_refund':
      case 'resolved_no_action':
        return DisputeState.fixed;
      case 'Closed':
      case 'closed':
      case 'dismissed':
        return DisputeState.closed;
      default:
        return DisputeState.unknown;
    }
  }

  DisputeEvidenceSummary _evidence(Map<String, dynamic> json) {
    final ev = json['evidence'];
    final evMap = ev is Map<String, dynamic> ? ev : const <String, dynamic>{};
    final records = ev is List
        ? ev.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];
    Map<String, dynamic>? source(String name) {
      for (final item in records) {
        if (_str(item['source'])?.toLowerCase() == name) return item;
      }
      return null;
    }

    final chat = source('chat_snapshot');
    final deliveryHistory = source('delivery_history');
    final deliveryPayload = _jsonMap(deliveryHistory?['payload']);
    final statusHistory = deliveryPayload['statusHistory'];
    final legacyTimeline = evMap['timeline'];
    final attachments = _attachments(
      evMap['attachments'] ?? json['attachments'],
    );
    final photoCount = _countOf(json['photos'] ?? json['photoUrls']);
    final attachmentPhotoCount = attachments
        .where((item) => item.kind.toLowerCase() == 'photo')
        .length;
    return DisputeEvidenceSummary(
      reason: _str(json['reason']),
      comment: _str(json['comment'] ?? json['note']),
      photoCount: photoCount > 0 ? photoCount : attachmentPhotoCount,
      hasVoice:
          _str(json['voiceUrl'] ?? json['voice_url']) != null ||
          attachments.any((item) => item.kind.toLowerCase() == 'voice'),
      hasChatSnapshot:
          chat != null &&
              _str(chat['status'])?.toLowerCase() != 'unavailable' ||
          _str(evMap['chatSnapshotUrl'] ?? evMap['chat_snapshot_url']) != null,
      chatMessageCount: _intOrNull(
        chat?['count'] ??
            evMap['chatMessageCount'] ??
            evMap['chat_message_count'],
      ),
      timelineCount:
          _intOrNull(deliveryHistory?['count']) ??
          (statusHistory is List
              ? statusHistory.length
              : legacyTimeline is List
              ? legacyTimeline.length
              : 0),
      completeness: records.isEmpty
          ? _completeness(
              json['evidenceCompleteness'] ??
                  json['evidence_completeness'] ??
                  evMap['completeness'] ??
                  evMap['status'],
              partial:
                  json['partialEvidence'] == true || evMap['partial'] == true,
            )
          : records.any(
              (item) => _str(item['status'])?.toLowerCase() != 'complete',
            )
          ? EvidenceCompleteness.partial
          : EvidenceCompleteness.complete,
      attachments: attachments,
      missingSources: <String>{
        ..._strings(evMap['missingSources'] ?? evMap['missing_sources']),
        for (final item in records)
          if (_str(item['status'])?.toLowerCase() != 'complete')
            _str(item['source']) ?? _str(item['marker']) ?? 'unknown',
      }.toList(growable: false),
    );
  }

  List<DisputeStatusHistoryEntry> _history(Map<String, dynamic> json) {
    final raw =
        json['timeline'] ??
        json['statusHistory'] ??
        json['status_history'] ??
        json['history'];
    if (raw is! List) return const <DisputeStatusHistoryEntry>[];
    return raw
        .whereType<Map>()
        .map((item) {
          final data = _jsonMap(item['data']);
          final eventType = _str(item['eventType'] ?? item['type']);
          return DisputeStatusHistoryEntry(
            status: _state(
              item['status'] ??
                  item['to'] ??
                  data['status'] ??
                  data['newStatus'] ??
                  data['state'] ??
                  data['to'] ??
                  _statusFromEvent(eventType),
            ),
            at: _str(
              item['at'] ??
                  item['createdAt'] ??
                  item['created_at'] ??
                  item['ts'],
            ),
            note: _str(
              item['note'] ??
                  item['message'] ??
                  data['note'] ??
                  data['message'] ??
                  data['reason'],
            ),
          );
        })
        .where((item) => item.status != DisputeState.unknown)
        .toList(growable: false);
  }

  Object? _statusFromEvent(String? eventType) {
    final normalized = eventType?.toLowerCase() ?? '';
    if (normalized.contains('closed')) return 'closed';
    if (normalized.contains('fixed') || normalized.contains('resolved')) {
      return 'fixed';
    }
    if (normalized.contains('created') || normalized.contains('opened')) {
      return 'pending';
    }
    return null;
  }

  Map<String, dynamic> _chatPayload(Map<String, dynamic> json) {
    final evidence = json['evidence'];
    if (evidence is! List) return const <String, dynamic>{};
    for (final item in evidence.whereType<Map>()) {
      if (_str(item['source'])?.toLowerCase() == 'chat_snapshot') {
        return _jsonMap(item['payload']);
      }
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _jsonMap(Object? value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
  }

  List<DisputeEvidenceAttachment> _attachments(Object? raw) {
    if (raw is! List) return const <DisputeEvidenceAttachment>[];
    return raw.indexed
        .map((entry) {
          final index = entry.$1;
          final value = entry.$2;
          if (value is String) {
            return DisputeEvidenceAttachment(
              id: value,
              kind: 'file',
              status: EvidenceAttachmentStatus.uploaded,
              objectRef: value,
            );
          }
          if (value is! Map) {
            return DisputeEvidenceAttachment(
              id: 'attachment-$index',
              kind: 'file',
              status: EvidenceAttachmentStatus.unknown,
            );
          }
          return DisputeEvidenceAttachment(
            id:
                _str(value['id'] ?? value['attachmentId']) ??
                'attachment-$index',
            kind: _str(value['kind'] ?? value['type']) ?? 'file',
            status: _attachmentStatus(value['status'] ?? value['uploadStatus']),
            fileName: _str(
              value['fileName'] ?? value['file_name'] ?? value['name'],
            ),
            objectRef: _str(
              value['objectRef'] ?? value['object_ref'] ?? value['url'],
            ),
          );
        })
        .toList(growable: false);
  }

  EvidenceCompleteness _completeness(Object? raw, {required bool partial}) {
    if (partial) return EvidenceCompleteness.partial;
    return switch (_str(raw)?.toLowerCase()) {
      'complete' => EvidenceCompleteness.complete,
      'partial' => EvidenceCompleteness.partial,
      'none' => EvidenceCompleteness.none,
      _ => EvidenceCompleteness.unknown,
    };
  }

  EvidenceAttachmentStatus _attachmentStatus(Object? raw) {
    return switch (_str(raw)?.toLowerCase()) {
      'uploaded' || 'complete' || 'ready' => EvidenceAttachmentStatus.uploaded,
      'failed' || 'error' => EvidenceAttachmentStatus.failed,
      'pending' || 'uploading' => EvidenceAttachmentStatus.pending,
      _ => EvidenceAttachmentStatus.unknown,
    };
  }

  List<String> _strings(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw.map(_str).whereType<String>().toList(growable: false);
  }

  int _countOf(Object? v) => v is List ? v.length : 0;

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

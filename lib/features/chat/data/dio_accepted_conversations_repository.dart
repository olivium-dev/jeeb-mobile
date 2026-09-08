import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../domain/accepted_conversation.dart';

class DioAcceptedConversationsRepository
    implements AcceptedConversationsRepository {
  const DioAcceptedConversationsRepository(this._dio, {this.role = 'client'});

  final Dio _dio;

  final String role;

  static const _requestsPath = '/requests';

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async {
    try {
      final response = await _dio.get<dynamic>(
        _requestsPath,
        queryParameters: {'role': role, 'page': 1, 'pageSize': 50},
      );
      final rawItems = _items(response.data);
      final accepted = <AcceptedConversation>[];
      final seen = <String>{};
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final json = raw.cast<String, dynamic>();
        if (!isAcceptedStatus(json['status'] ?? json['phase'])) continue;
        final conversation = _parse(json);
        if (conversation == null) continue;
        if (seen.add(conversation.routeId)) accepted.add(conversation);
      }
      return accepted;
    } catch (error) {
      throw AcceptedConversationsException(AppFailure.of(error));
    }
  }

  AcceptedConversation? _parse(Map<String, dynamic> json) {
    final requestId = _string(json, const ['id', 'requestId', 'request_id']);
    final conversationId =
        _string(json, const ['conversationId', 'conversation_id']);
    if (requestId.isEmpty && conversationId.isEmpty) return null;
    final dropoff = json['dropoff'];
    final destination = dropoff is Map
        ? (dropoff['address'] as String? ?? '')
        : (json['dropoffAddress'] as String? ?? '');
    return AcceptedConversation(
      conversationId: conversationId,
      requestId: requestId,
      title: _stringOrNull(json, const ['title', 'description', 'subject']),
      displayId: _stringOrNull(json, const ['displayId', 'display_id']),
      counterpartName: _stringOrNull(
        json,
        const ['jeeberName', 'clientName', 'counterpartName'],
      ),
      destinationLabel: destination.isEmpty ? null : destination,
    );
  }

  static bool isAcceptedStatus(Object? status) {
    final s = (status is String ? status : '').toLowerCase();
    return s == 'accepted' || s == 'in_progress' || s == 'inprogress';
  }

  static List<dynamic> _items(Object? data) {
    if (data is List) return data;
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final raw = map['items'] ?? map['requests'] ?? map['data'];
      if (raw is List) return raw;
    }
    return const <dynamic>[];
  }

  static String _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return '';
  }

  static String? _stringOrNull(Map<String, dynamic> json, List<String> keys) {
    final value = _string(json, keys);
    return value.isEmpty ? null : value;
  }
}

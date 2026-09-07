import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../order_history/domain/order_summary.dart' show OrderRequestStatus;
import '../domain/chat_conversation_summary.dart';

/// Reads the active requests that back the chat inbox. Every failure is
/// classified into an [AppFailure] and THROWN, so an empty page can only ever
/// mean the gateway answered with no rows.
class DioChatConversationsRepository implements ChatConversationsRepository {
  const DioChatConversationsRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/requests';

  @override
  Future<ChatConversationsPage> fetchConversations() async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: <String, Object?>{
          'status': 'active',
          'page': 1,
          'pageSize': 20,
        },
      );
      return _parsePage(response.data);
    } on DioException catch (error) {
      throw AppFailure.of(error);
    } on TypeError catch (error) {
      throw UnknownFailure(parse: true, cause: error);
    } on FormatException catch (error) {
      throw UnknownFailure(parse: true, cause: error);
    } catch (error) {
      throw AppFailure.of(error);
    }
  }

  ChatConversationsPage _parsePage(Map<String, dynamic>? data) {
    final Object? rawItems = data?['items'];
    // A 200 with no decodable `items` is contract drift, not an empty inbox.
    if (data == null || rawItems is! List) {
      throw UnknownFailure(
        parse: true,
        cause: StateError('chat conversations payload has no items list'),
      );
    }
    final List<dynamic> items = rawItems;
    final List<ChatConversationSummary> rows = <ChatConversationSummary>[];
    int skipped = 0;
    for (final dynamic raw in items) {
      if (raw is! Map) {
        skipped++;
        continue;
      }
      final Map<String, dynamic> json = raw.cast<String, dynamic>();
      final String requestId = _string(json['id']);
      // SHELL-02: the live row omits `conversationId`, so a row is routable on
      // EITHER id. Only a row carrying neither is unreachable.
      final String conversationId = _string(json['conversationId']);
      if (requestId.isEmpty && conversationId.isEmpty) {
        skipped++;
        continue;
      }
      final String? title = _stringOrNull(json['title']);
      rows.add(ChatConversationSummary(
        requestId: requestId,
        conversationId: conversationId,
        title: title,
        status: OrderRequestStatus.parse(_stringOrNull(json['status'])),
        tier: _string(json['tier']),
      ));
    }
    return ChatConversationsPage(
      conversations: List<ChatConversationSummary>.unmodifiable(rows),
      skippedRows: skipped,
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static String? _stringOrNull(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}

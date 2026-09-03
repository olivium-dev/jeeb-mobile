import 'package:dio/dio.dart';

import '../../../core/diagnostics/chat_diagnostics.dart';
import '../../../core/diagnostics/diag.dart';
import '../domain/chat_firebase_identity.dart';

const String kChatFirebaseTokenPath = '/v1/chat/firebase-token';

class GatewayChatFirebaseTokenMinter implements ChatFirebaseTokenMinter {
  GatewayChatFirebaseTokenMinter({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<String?> mintCustomToken() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        kChatFirebaseTokenPath,
      );
      final token = response.data?['token'];
      if (token is! String || token.isEmpty) {
        Diag.event('chat_firebase_mint', <String, Object?>{
          'result': 'no_token',
          'status': response.statusCode,
        });
        ChatDiagnostics.degraded(
          stage: ChatDiagStage.mint,
          reason: 'no_token',
          status: response.statusCode,
        );
        return null;
      }
      Diag.event('chat_firebase_mint', <String, Object?>{
        'result': 'minted',
        'status': response.statusCode,
      });
      return token;
    } on DioException catch (error) {
      Diag.event('chat_firebase_mint', <String, Object?>{
        'result': 'http_error',
        'status': error.response?.statusCode,
        'type': error.type.name,
      });
      ChatDiagnostics.degraded(
        stage: ChatDiagStage.mint,
        reason: 'http_${error.type.name}',
        status: error.response?.statusCode,
      );
      return null;
    } catch (error) {
      Diag.event('chat_firebase_mint', <String, Object?>{
        'result': 'failed',
        'error': error.runtimeType.toString(),
      });
      ChatDiagnostics.degraded(
        stage: ChatDiagStage.mint,
        reason: 'threw_${error.runtimeType}',
      );
      return null;
    }
  }
}

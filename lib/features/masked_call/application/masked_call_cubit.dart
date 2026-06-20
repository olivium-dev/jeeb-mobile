import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MaskedCallState {
  const MaskedCallState({
    this.isLoading = false,
    this.sessionId,
    this.proxyNumber,
    this.expiresAt,
    this.error,
  });

  final bool isLoading;
  final String? sessionId;
  final String? proxyNumber;
  final DateTime? expiresAt;
  final String? error;

  MaskedCallState copyWith({
    bool? isLoading,
    String? sessionId,
    String? proxyNumber,
    DateTime? expiresAt,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return MaskedCallState(
      isLoading: isLoading ?? this.isLoading,
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      proxyNumber: clearSession ? null : (proxyNumber ?? this.proxyNumber),
      expiresAt: clearSession ? null : (expiresAt ?? this.expiresAt),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MaskedCallCubit extends Cubit<MaskedCallState> {
  MaskedCallCubit({Dio? dio}) : _dio = dio, super(const MaskedCallState());

  final Dio? _dio;

  static const String _path = '/api/calls/session';

  Future<void> initiateCall(String deliveryId, {String? calleeUserId}) async {
    final cleanDeliveryId = deliveryId.trim();
    if (cleanDeliveryId.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Delivery reference is missing.',
          clearSession: true,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true, clearSession: true));
    try {
      final dio = _dio;
      if (dio == null) {
        emit(MaskedCallState(sessionId: 'session-$cleanDeliveryId'));
        return;
      }
      final response = await dio.post<Map<String, dynamic>>(
        _path,
        data: <String, dynamic>{
          'deliveryId': cleanDeliveryId,
          if (calleeUserId?.trim().isNotEmpty ?? false)
            'calleeUserId': calleeUserId!.trim(),
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      final sessionId = _string(data['sessionId']);
      if (sessionId == null) {
        throw const FormatException('missing masked-call session id');
      }
      emit(
        MaskedCallState(
          isLoading: false,
          sessionId: sessionId,
          proxyNumber: _string(data['proxyNumber']),
          expiresAt: _dateTime(data['expiresAt']),
        ),
      );
    } on DioException {
      emit(
        const MaskedCallState(
          isLoading: false,
          error: 'Could not start the masked call. Please try again.',
        ),
      );
    } on FormatException {
      emit(
        const MaskedCallState(
          isLoading: false,
          error: 'The call service returned an invalid response.',
        ),
      );
    } catch (_) {
      emit(
        const MaskedCallState(
          isLoading: false,
          error: 'Could not start the masked call. Please try again.',
        ),
      );
    }
  }

  String? _string(Object? value) {
    final text = value as String?;
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _dateTime(Object? value) {
    final text = _string(value);
    return text == null ? null : DateTime.tryParse(text);
  }
}

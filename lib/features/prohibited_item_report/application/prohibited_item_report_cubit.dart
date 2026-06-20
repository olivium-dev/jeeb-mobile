import 'package:flutter_bloc/flutter_bloc.dart';

import '../../jeeber_request_detail/domain/services/prohibited_item_report_service.dart';

/// Submission phase for the prohibited-item report form
/// (orders-prohibited-item-report).
enum ProhibitedReportPhase { editing, submitting, submitted, error }

class ProhibitedItemReportState {
  const ProhibitedItemReportState({
    this.phase = ProhibitedReportPhase.editing,
    this.description = '',
    this.photoUrl,
    this.errorKey,
  });

  final ProhibitedReportPhase phase;
  final String description;

  /// Attached photo reference (CDN URL or local path placeholder). Optional.
  final String? photoUrl;

  /// Localization key for the error banner (`jeeberRequestDetailReportError*`),
  /// or null.
  final String? errorKey;

  bool get canSubmit =>
      description.trim().isNotEmpty && phase != ProhibitedReportPhase.submitting;

  ProhibitedItemReportState copyWith({
    ProhibitedReportPhase? phase,
    String? description,
    String? photoUrl,
    String? errorKey,
    bool clearError = false,
  }) {
    return ProhibitedItemReportState(
      phase: phase ?? this.phase,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Cubit driving the prohibited-item report form. Submits the typed reason (and
/// optional attached photo) to the gateway via [ProhibitedItemReportService].
class ProhibitedItemReportCubit extends Cubit<ProhibitedItemReportState> {
  ProhibitedItemReportCubit({
    required ProhibitedItemReportService service,
    required this.requestId,
  })  : _service = service,
        super(const ProhibitedItemReportState());

  final ProhibitedItemReportService _service;
  final String requestId;

  void setDescription(String value) =>
      emit(state.copyWith(description: value, clearError: true));

  void attachPhoto(String photoUrl) =>
      emit(state.copyWith(photoUrl: photoUrl));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(phase: ProhibitedReportPhase.submitting, clearError: true));
    try {
      await _service.report(
        requestId: requestId,
        reason: state.description.trim(),
        photoUrl: state.photoUrl,
      );
      emit(state.copyWith(phase: ProhibitedReportPhase.submitted));
    } on ProhibitedReportException catch (e) {
      emit(state.copyWith(
        phase: ProhibitedReportPhase.error,
        errorKey: e.failure == ProhibitedReportFailure.network
            ? 'jeeberRequestDetailReportErrorNetwork'
            : 'jeeberRequestDetailReportErrorGeneric',
      ));
    } catch (_) {
      emit(state.copyWith(
        phase: ProhibitedReportPhase.error,
        errorKey: 'jeeberRequestDetailReportErrorGeneric',
      ));
    }
  }
}

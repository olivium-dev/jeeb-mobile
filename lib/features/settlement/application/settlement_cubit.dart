import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/settlement_repository.dart';
import '../domain/settlement_statement.dart';

/// View-mode for the settlement list screen.
enum SettlementListMode { loading, ready, error }

/// View-mode for PDF export.
enum SettlementExportMode { idle, exporting, done, error }

/// State emitted by [SettlementCubit].
class SettlementState extends Equatable {
  const SettlementState({
    this.mode = SettlementListMode.loading,
    this.statements = const [],
    this.errorMessage,
    this.exportMode = SettlementExportMode.idle,
    this.exportedFilePath,
    this.exportError,
  });

  final SettlementListMode mode;
  final List<SettlementStatement> statements;
  final String? errorMessage;
  final SettlementExportMode exportMode;
  final String? exportedFilePath;
  final String? exportError;

  bool get isExporting => exportMode == SettlementExportMode.exporting;

  SettlementState copyWith({
    SettlementListMode? mode,
    List<SettlementStatement>? statements,
    String? errorMessage,
    bool clearError = false,
    SettlementExportMode? exportMode,
    String? exportedFilePath,
    String? exportError,
    bool clearExportError = false,
  }) {
    return SettlementState(
      mode: mode ?? this.mode,
      statements: statements ?? this.statements,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      exportMode: exportMode ?? this.exportMode,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      exportError:
          clearExportError ? null : (exportError ?? this.exportError),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        statements,
        errorMessage,
        exportMode,
        exportedFilePath,
        exportError,
      ];
}

/// Cubit for the settlement statement screen (T-MOB-032).
///
/// Loads weekly statements from [SettlementRepository] and exposes PDF
/// download. Each download logs `settlement.pdf_exported` (AC5).
class SettlementCubit extends Cubit<SettlementState> {
  SettlementCubit({required SettlementRepository repository})
      : _repository = repository,
        super(const SettlementState());

  final SettlementRepository _repository;

  Future<void> loadStatements() async {
    emit(state.copyWith(mode: SettlementListMode.loading, clearError: true));
    try {
      final statements = await _repository.fetchStatements();
      emit(state.copyWith(
        mode: SettlementListMode.ready,
        statements: statements,
      ));
    } on SettlementException catch (e) {
      emit(state.copyWith(
        mode: SettlementListMode.error,
        errorMessage: _mapError(e),
      ));
    }
  }

  Future<void> downloadPdf(String statementId) async {
    if (state.isExporting) return;
    emit(state.copyWith(
      exportMode: SettlementExportMode.exporting,
      clearExportError: true,
    ));
    try {
      final path = await _repository.downloadPdf(statementId);
      _logPdfExported(statementId);
      emit(state.copyWith(
        exportMode: SettlementExportMode.done,
        exportedFilePath: path,
      ));
    } on SettlementException catch (e) {
      emit(state.copyWith(
        exportMode: SettlementExportMode.error,
        exportError: _mapError(e),
      ));
    }
  }

  void acknowledgeExport() {
    emit(state.copyWith(
      exportMode: SettlementExportMode.idle,
      clearExportError: true,
    ));
  }

  String _mapError(SettlementException e) {
    switch (e.failure) {
      case SettlementFailure.network:
        return 'No internet connection';
      case SettlementFailure.notFound:
        return 'Statement not found';
      case SettlementFailure.fileWrite:
        return 'Unable to save PDF file';
      case SettlementFailure.server:
        return 'Server error. Please try again.';
    }
  }

  // AC5: settlement.pdf_exported log (no PII)
  // ignore: avoid_print
  void _logPdfExported(String statementId) {
    // ignore: avoid_print
    print('[settlement.pdf_exported] statementId=$statementId');
  }
}

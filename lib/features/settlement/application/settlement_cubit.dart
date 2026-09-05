import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../domain/settlement_repository.dart';
import '../domain/settlement_statement.dart';

enum SettlementListMode { loading, ready, error }

enum SettlementExportMode { idle, exporting, done, error }

class SettlementState extends Equatable {
  const SettlementState({
    this.mode = SettlementListMode.loading,
    this.statements = const [],
    this.failure,
    this.exportMode = SettlementExportMode.idle,
    this.exportedFilePath,
    this.exportFailure,
    this.cause,
  });

  final SettlementListMode mode;
  final List<SettlementStatement> statements;

  /// The machine reason for the cold-load failure — never a sentence (SET-02).
  final SettlementFailure? failure;

  final SettlementExportMode exportMode;
  final String? exportedFilePath;

  /// The machine reason for a failed PDF export.
  final SettlementFailure? exportFailure;

  /// The classified transport failure behind either, for the copy family.
  final AppFailure? cause;

  bool get isExporting => exportMode == SettlementExportMode.exporting;

  SettlementState copyWith({
    SettlementListMode? mode,
    List<SettlementStatement>? statements,
    SettlementFailure? failure,
    bool clearError = false,
    SettlementExportMode? exportMode,
    String? exportedFilePath,
    SettlementFailure? exportFailure,
    bool clearExportError = false,
    AppFailure? cause,
  }) {
    return SettlementState(
      mode: mode ?? this.mode,
      statements: statements ?? this.statements,
      failure: clearError ? null : (failure ?? this.failure),
      exportMode: exportMode ?? this.exportMode,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      exportFailure: clearExportError
          ? null
          : (exportFailure ?? this.exportFailure),
      cause: (clearError || clearExportError) ? cause : (cause ?? this.cause),
    );
  }

  @override
  List<Object?> get props => [
    mode,
    statements,
    failure,
    exportMode,
    exportedFilePath,
    exportFailure,
    cause,
  ];
}

class SettlementCubit extends Cubit<SettlementState> {
  SettlementCubit({required SettlementRepository repository})
    : _repository = repository,
      super(const SettlementState());

  final SettlementRepository _repository;

  bool _loading = false;

  Future<void> loadStatements() async {
    if (_loading) return;
    _loading = true;
    emit(state.copyWith(mode: SettlementListMode.loading, clearError: true));
    try {
      final statements = await _repository.fetchStatements();
      emit(
        state.copyWith(
          mode: SettlementListMode.ready,
          statements: statements,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          mode: SettlementListMode.error,
          failure: _reason(e),
          cause: _cause(e),
        ),
      );
    } finally {
      _loading = false;
    }
  }

  Future<void> downloadPdf(String statementId) async {
    if (state.isExporting) return;
    emit(
      state.copyWith(
        exportMode: SettlementExportMode.exporting,
        clearExportError: true,
      ),
    );
    try {
      final path = await _repository.downloadPdf(statementId);
      _logPdfExported(statementId);
      emit(
        state.copyWith(
          exportMode: SettlementExportMode.done,
          exportedFilePath: path,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          exportMode: SettlementExportMode.error,
          exportFailure: _reason(e),
          cause: _cause(e),
        ),
      );
    }
  }

  void acknowledgeExport() {
    emit(
      state.copyWith(
        exportMode: SettlementExportMode.idle,
        clearExportError: true,
      ),
    );
  }

  SettlementFailure _reason(Object e) =>
      e is SettlementException ? e.failure : SettlementFailure.server;

  AppFailure _cause(Object e) {
    if (e is! SettlementException) return AppFailure.of(e);
    return e.cause ??
        switch (e.failure) {
          SettlementFailure.network => const NetworkFailure(),
          SettlementFailure.notFound => const NotFoundFailure(),
          SettlementFailure.server => const ServerFailure(status: 500),
          SettlementFailure.fileWrite ||
          SettlementFailure.parse => const UnknownFailure(parse: true),
        };
  }

  void _logPdfExported(String statementId) {
    Diag.event('settlement.pdf_exported', <String, Object?>{
      'statementId': statementId,
    });
  }
}

// Tests for SettlementCubit (T-MOB-032).
//
// Verifies:
//   - AC1: loadStatements emits loading → ready with 4 rows.
//   - AC3: downloadPdf transitions exporting → done with file path.
//   - AC5: acknowledgeExport resets export mode.
//   - Network error on load emits error mode.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settlement/application/settlement_cubit.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_repository.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';

List<SettlementStatement> _sampleStatements() => List.generate(
      4,
      (i) => SettlementStatement(
        id: 'stmt-$i',
        weekLabel: 'Week $i',
        totalPayout: 100.0 * (i + 1),
        currency: 'USD',
        status: i.isEven ? SettlementStatus.paid : SettlementStatus.pending,
        deliveries: const [],
      ),
    );

class _FakeSettlementRepo implements SettlementRepository {
  _FakeSettlementRepo({
    this.statements,
    this.listThrows,
    this.pdfPath,
  });

  final List<SettlementStatement>? statements;
  final SettlementException? listThrows;
  final String? pdfPath;

  @override
  Future<List<SettlementStatement>> fetchStatements() async {
    if (listThrows != null) throw listThrows!;
    return statements ?? _sampleStatements();
  }

  @override
  Future<String> downloadPdf(String statementId) async {
    return pdfPath ?? '/tmp/settlement_$statementId.pdf';
  }
}

void main() {
  group('SettlementCubit — loadStatements', () {
    blocTest<SettlementCubit, SettlementState>(
      'emits loading → ready with 4 rows (AC1)',
      build: () => SettlementCubit(
        repository: _FakeSettlementRepo(statements: _sampleStatements()),
      ),
      act: (c) => c.loadStatements(),
      expect: () => [
        predicate<SettlementState>(
          (s) => s.mode == SettlementListMode.loading,
          'loading',
        ),
        predicate<SettlementState>(
          (s) =>
              s.mode == SettlementListMode.ready &&
              s.statements.length == 4,
          'ready with 4 statements',
        ),
      ],
    );

    blocTest<SettlementCubit, SettlementState>(
      'network failure emits error',
      build: () => SettlementCubit(
        repository: _FakeSettlementRepo(
          listThrows: const SettlementException(SettlementFailure.network),
        ),
      ),
      act: (c) => c.loadStatements(),
      expect: () => [
        predicate<SettlementState>((s) => s.mode == SettlementListMode.loading),
        predicate<SettlementState>(
          (s) =>
              s.mode == SettlementListMode.error &&
              s.errorMessage != null,
          'error with message',
        ),
      ],
    );
  });

  group('SettlementCubit — downloadPdf', () {
    blocTest<SettlementCubit, SettlementState>(
      'downloadPdf emits exporting → done with path (AC3)',
      build: () => SettlementCubit(
        repository: _FakeSettlementRepo(pdfPath: '/tmp/stmt-0.pdf'),
      ),
      seed: () => SettlementState(
        mode: SettlementListMode.ready,
        statements: _sampleStatements(),
      ),
      act: (c) => c.downloadPdf('stmt-0'),
      expect: () => [
        predicate<SettlementState>((s) => s.isExporting, 'exporting'),
        predicate<SettlementState>(
          (s) =>
              s.exportMode == SettlementExportMode.done &&
              s.exportedFilePath == '/tmp/stmt-0.pdf',
          'done with path',
        ),
      ],
    );

    blocTest<SettlementCubit, SettlementState>(
      'acknowledgeExport resets exportMode (AC5)',
      build: () => SettlementCubit(
        repository: _FakeSettlementRepo(pdfPath: '/tmp/x.pdf'),
      ),
      seed: () => const SettlementState(
        exportMode: SettlementExportMode.done,
        exportedFilePath: '/tmp/x.pdf',
      ),
      act: (c) => c.acknowledgeExport(),
      expect: () => [
        predicate<SettlementState>(
          (s) => s.exportMode == SettlementExportMode.idle,
          'idle after acknowledge',
        ),
      ],
    );
  });
}

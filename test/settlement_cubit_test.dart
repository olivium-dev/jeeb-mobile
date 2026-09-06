// Tests for SettlementCubit (T-MOB-032).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
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

/// Throws the untyped error a `fromJson` cast raises.
class _RawThrowSettlementRepo implements SettlementRepository {
  const _RawThrowSettlementRepo();

  @override
  Future<List<SettlementStatement>> fetchStatements() async => throw TypeError();

  @override
  Future<String> downloadPdf(String statementId) async => throw TypeError();
}

/// Never answers — the in-flight guard's fixture.
class _StallingSettlementRepo implements SettlementRepository {
  const _StallingSettlementRepo();

  @override
  Future<List<SettlementStatement>> fetchStatements() =>
      Completer<List<SettlementStatement>>().future;

  @override
  Future<String> downloadPdf(String statementId) =>
      Completer<String>().future;
}

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
              s.failure == SettlementFailure.network &&
              s.cause is NetworkFailure,
          'error carrying the machine reason, never an English sentence',
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

  group('SettlementCubit — SET-01/SET-02 hardening', () {
    blocTest<SettlementCubit, SettlementState>(
      'a RAW TypeError from fetchStatements lands the error rung, never a '
      'hung loading',
      build: () => SettlementCubit(
        repository: const _RawThrowSettlementRepo(),
      ),
      act: (c) => c.loadStatements(),
      expect: () => [
        predicate<SettlementState>((s) => s.mode == SettlementListMode.loading),
        predicate<SettlementState>(
          (s) =>
              s.mode == SettlementListMode.error &&
              s.failure == SettlementFailure.server &&
              s.cause != null,
          'classified error rung',
        ),
      ],
    );

    blocTest<SettlementCubit, SettlementState>(
      'a second loadStatements while one is in flight is a no-op',
      build: () => SettlementCubit(
        repository: const _StallingSettlementRepo(),
      ),
      act: (c) async {
        unawaited(c.loadStatements());
        await c.loadStatements();
      },
      expect: () => [
        predicate<SettlementState>((s) => s.mode == SettlementListMode.loading),
      ],
    );

    blocTest<SettlementCubit, SettlementState>(
      'a raw TypeError from downloadPdf lands the export error, never a hung '
      'exporting',
      build: () => SettlementCubit(
        repository: const _RawThrowSettlementRepo(),
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
              s.exportMode == SettlementExportMode.error &&
              s.exportFailure != null,
          'export error carrying the machine reason',
        ),
      ],
    );

    test('SET-02: the state exposes NO String error field', () {
      const state = SettlementState();
      expect(state.failure, isNull);
      expect(state.exportFailure, isNull);
      // A compile-time guarantee, restated: the two reasons are enums.
      expect(state.props.whereType<String>(), isEmpty);
    });
  });
}
